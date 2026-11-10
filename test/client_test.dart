import 'dart:async';
import 'dart:convert';

import 'package:bachs/bachs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const sandboxKey = 'sk_sandbox_test_123';

/// A fake Bachs API that records requests and answers from [handler].
class FakeApi {
  FakeApi(this.handler);

  final FutureOr<http.Response> Function(http.Request request, int call)
      handler;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    return handler(request, requests.length);
  });

  BachsClient bachs({
    Duration timeout = const Duration(seconds: 5),
    int maxRetries = 2,
    BachsLogger? logger,
    BachsLogLevel? logLevel,
  }) =>
      BachsClient(sandboxKey,
          baseUrl: 'https://api.test',
          httpClient: client,
          timeout: timeout,
          maxRetries: maxRetries,
          logger: logger,
          logLevel: logLevel);
}

http.Response json(Object? body,
        [int status = 200, Map<String, String>? headers]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json', ...?headers});

/// Matches a thrown [T] that passes [check].
Matcher throwsWhere<T extends Object>([bool Function(T e)? check]) => throwsA(
    check == null ? isA<T>() : predicate<Object>((e) => e is T && check(e)));

void main() {
  setUpAll(() => BachsClient.retryBaseDelay = const Duration(milliseconds: 1));

  group('BachsClient', () {
    test('infers the environment from the key prefix', () {
      expect(BachsClient(sandboxKey, logger: null).environment,
          BachsEnvironment.sandbox);
      expect(BachsClient('sk_live_abc', logger: null).environment,
          BachsEnvironment.production);
    });

    test('rejects an environment that contradicts the key', () {
      expect(
          () => BachsClient('sk_live_abc',
              environment: BachsEnvironment.sandbox, logger: null),
          throwsWhere<BachsConfigException>());
    });

    test('needs an environment for an unknown prefix, and warns', () {
      expect(() => BachsClient('other_key', logger: null),
          throwsWhere<BachsConfigException>());
      final logs = <BachsLogRecord>[];
      final c = BachsClient('other_key',
          environment: BachsEnvironment.production, logger: logs.add);
      expect(c.environment, BachsEnvironment.production);
      expect(logs.single.level, BachsLogLevel.warn);
    });

    test('rejects bad settings', () {
      expect(() => BachsClient('  ', logger: null),
          throwsWhere<BachsConfigException>());
      expect(
          () => BachsClient(sandboxKey, timeout: Duration.zero, logger: null),
          throwsWhere<BachsConfigException>());
      expect(() => BachsClient(sandboxKey, maxRetries: -1, logger: null),
          throwsWhere<BachsConfigException>());
      expect(() => BachsClient(sandboxKey, baseUrl: 'not a url', logger: null),
          throwsWhere<BachsConfigException>());
    });
  });

  test('checkout create sends the request and decodes the session', () async {
    final api = FakeApi((r, _) => json({
          'checkout_id': 'chk_1',
          'checkout_url': 'https://pay.test/chk_1',
          'status': 'open',
          'created_at': '2026-01-02T03:04:05Z',
          'brand_new_field': 42,
        }));
    final session = await api.bachs().checkoutSessions.create(
          const CreateCheckoutSessionParams(
            pricing: CheckoutPricing(currency: 'USD', amount: '29.00'),
            customer: CheckoutCustomerParams(email: 'ada@example.com'),
            successUrl: 'https://example.com/thanks',
            reference: 'order-1',
          ),
          options: const RequestOptions(idempotencyKey: 'checkout-order-1'),
        );

    final r = api.requests.single;
    expect(r.method, 'POST');
    expect(r.url.toString(), 'https://api.test/v1/checkout-sessions');
    expect(r.headers['Authorization'], 'Bearer $sandboxKey');
    expect(r.headers['Idempotency-Key'], 'checkout-order-1');
    expect(r.headers['Content-Type'], 'application/json');
    expect(r.headers['User-Agent'], startsWith('bachs-flutter-sdk/'));
    expect(jsonDecode(r.body), {
      'pricing': {'currency': 'USD', 'amount': '29.00'},
      'customer': {'email': 'ada@example.com'},
      'success_url': 'https://example.com/thanks',
      'reference': 'order-1',
    });

    expect(session.checkoutId, 'chk_1');
    expect(session.checkoutUrl, 'https://pay.test/chk_1');
    expect(session.status, CheckoutSessionStatus.open);
    expect(session.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(session.raw['brand_new_field'], 42);
  });

  test('checkout create needs exactly one of cart or pricing', () async {
    final api = FakeApi((r, _) => json({}));
    final c = api.bachs();
    await expectLater(
        c.checkoutSessions.create(const CreateCheckoutSessionParams()),
        throwsWhere<BachsConfigException>());
    await expectLater(
        c.checkoutSessions.create(const CreateCheckoutSessionParams(
          productCart: [CartItem(productId: 'prod_1')],
          pricing: CheckoutPricing(currency: 'USD', amount: '1.00'),
        )),
        throwsWhere<BachsConfigException>());
    expect(api.requests, isEmpty);
  });

  group('retries', () {
    test('reads retry on a retryable status', () async {
      final api = FakeApi((r, call) =>
          call == 1 ? json({'detail': 'down'}, 503) : json({'id': 'po_1'}));
      final payout = await api.bachs().payouts.get('po_1');
      expect(payout.id, 'po_1');
      expect(api.requests, hasLength(2));
    });

    test('reads stop after max retries', () async {
      final api = FakeApi((r, _) => json({'detail': 'down'}, 502));
      await expectLater(api.bachs(maxRetries: 2).payouts.get('po_1'),
          throwsWhere<BachsApiException>((e) => e.statusCode == 502));
      expect(api.requests, hasLength(3));
    });

    test('reads retry network failures', () async {
      final api = FakeApi((r, call) => call == 1
          ? throw http.ClientException('connection reset')
          : json({'id': 'po_1'}));
      expect((await api.bachs().payouts.get('po_1')).id, 'po_1');
      expect(api.requests, hasLength(2));
    });

    test('reads do not retry client errors', () async {
      final api = FakeApi(
          (r, _) => json({'detail': 'nope', 'error_code': 'NOT_FOUND'}, 404));
      await expectLater(api.bachs().payouts.get('po_1'),
          throwsWhere<BachsApiException>((e) => e.isNotFound));
      expect(api.requests, hasLength(1));
    });

    test('writes are never retried, and a 5xx write is outcome-unknown',
        () async {
      final api = FakeApi((r, _) => json({'detail': 'down'}, 503));
      await expectLater(
          api.bachs().payouts.create(
              const CreatePayoutParams(destination: 'pd_1', amount: '10.00'),
              options: const RequestOptions(idempotencyKey: 'payout-1')),
          throwsWhere<BachsApiException>((e) => e.outcomeUnknown));
      expect(api.requests, hasLength(1));
    });

    test('a network failure on a write is outcome-unknown', () async {
      final api =
          FakeApi((r, _) => throw http.ClientException('connection reset'));
      await expectLater(
          api.bachs().payouts.create(
              const CreatePayoutParams(destination: 'pd_1', amount: '10.00')),
          throwsWhere<BachsNetworkException>((e) => e.outcomeUnknown));
      expect(api.requests, hasLength(1));
    });

    test('a rate-limited write is not outcome-unknown', () async {
      final api = FakeApi((r, _) => json({'detail': 'slow down'}, 429));
      await expectLater(
          api.bachs().payouts.create(
              const CreatePayoutParams(destination: 'pd_1', amount: '10.00')),
          throwsWhere<BachsApiException>((e) => !e.outcomeUnknown));
    });
  });

  group('errors', () {
    test('API error fields are decoded', () async {
      final api = FakeApi((r, _) => json(
          {
            'detail': 'Invalid request',
            'error_code': 'VALIDATION_ERROR',
            'errors': [
              {'field': 'amount', 'message': 'must be positive'}
            ],
            'doc_url': 'https://docs.test/errors',
          },
          422,
          {
            'x-request-id': 'req_123',
            'retry-after': '7',
          }));
      try {
        await api.bachs().refunds.create(
            const CreateRefundParams(chargeId: 'ch_1', reference: 'r1'));
        fail('expected an error');
      } on BachsApiException catch (e) {
        expect(e.statusCode, 422);
        expect(e.errorCode, ErrorCode.validation);
        expect(e.hasErrorCode(ErrorCode.validation), isTrue);
        expect(e.detail, 'Invalid request');
        expect(e.fieldErrors.single.field, 'amount');
        expect(e.docUrl, 'https://docs.test/errors');
        expect(e.requestId, 'req_123');
        expect(e.retryAfter, const Duration(seconds: 7));
        expect(e.toString(), contains('req_123'));
      }
    });

    test('a non-JSON error body still gives a detail', () async {
      final api = FakeApi((r, _) => http.Response(
          '<html>bad gateway</html>', 400,
          reasonPhrase: 'Bad Request'));
      await expectLater(
          api.bachs().payouts.get('po_1'),
          throwsWhere<BachsApiException>((e) =>
              e.errorCode == null &&
              e.detail == 'Bad Request' &&
              e.body.contains('bad gateway')));
    });

    test('an undecodable success body is a response error', () async {
      final api = FakeApi((r, _) =>
          http.Response('{not json', 200, headers: {'x-request-id': 'req_9'}));
      await expectLater(api.bachs().payouts.get('po_1'),
          throwsWhere<BachsResponseException>((e) => e.requestId == 'req_9'));
    });

    test('an operation past its timeout stops', () async {
      final api = FakeApi((r, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return json({});
      });
      final sw = Stopwatch()..start();
      await expectLater(
          api
              .bachs(timeout: const Duration(milliseconds: 50))
              .payouts
              .get('po_1'),
          throwsWhere<BachsNetworkException>(
              (e) => e.isTimeout && !e.isCanceled));
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 400)));
    });

    test('the abort trigger cancels a call', () async {
      final api = FakeApi((r, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return json({});
      });
      final cancel = Completer<void>();
      final call = api
          .bachs()
          .payouts
          .get('po_1', options: RequestOptions(abortTrigger: cancel.future));
      cancel.complete();
      await expectLater(
          call, throwsWhere<BachsNetworkException>((e) => e.isCanceled));
    });

    test('an idempotency key on a read is rejected', () async {
      final api = FakeApi((r, _) => json({}));
      await expectLater(
          api
              .bachs()
              .payouts
              .get('po_1', options: const RequestOptions(idempotencyKey: 'k')),
          throwsWhere<BachsConfigException>());
      expect(api.requests, isEmpty);
    });

    test('an empty ID is rejected before sending', () async {
      final api = FakeApi((r, _) => json({}));
      await expectLater(
          api.bachs().payouts.get(' '), throwsWhere<BachsConfigException>());
      expect(api.requests, isEmpty);
    });
  });

  test('IDs are path-escaped', () async {
    final api = FakeApi((r, _) => json({}));
    await api.bachs().payouts.get('a/b c');
    expect(api.requests.single.url.toString(),
        'https://api.test/v1/payouts/a%2Fb%20c');
  });

  test('the account option sends X-Account-Id', () async {
    final api = FakeApi((r, _) => json({}));
    await api
        .bachs()
        .balances
        .get(options: const RequestOptions(account: 'acct_9'));
    expect(api.requests.single.headers['X-Account-Id'], 'acct_9');
  });

  group('subscriptions', () {
    test('cancel defaults to the end of the period', () async {
      final api = FakeApi((r, _) => json({'id': 'sub_1'}));
      await api.bachs().subscriptions.cancel('sub_1');
      final r = api.requests.single;
      expect(r.method, 'DELETE');
      expect(jsonDecode(r.body), {'cancel_at_period_end': true});
    });

    test('cancel can end immediately', () async {
      final api = FakeApi((r, _) => json({'id': 'sub_1'}));
      await api.bachs().subscriptions.cancel('sub_1',
          params: const CancelSubscriptionParams(
              cancelAtPeriodEnd: false, reason: 'moved'));
      expect(jsonDecode(api.requests.single.body),
          {'cancel_at_period_end': false, 'reason': 'moved'});
    });
  });

  group('listAll', () {
    test('products follow the cursor', () async {
      final api = FakeApi((r, call) => json({
            'items': [
              {'id': 'prod_$call'}
            ],
            'pagination': {
              'has_more': call < 3,
              'next_cursor': call < 3 ? 'c$call' : '',
            },
          }));
      final ids =
          await api.bachs().products.listAll().map((p) => p.id).toList();
      expect(ids, ['prod_1', 'prod_2', 'prod_3']);
      expect(api.requests[0].url.queryParameters['cursor'], isNull);
      expect(api.requests[1].url.queryParameters['cursor'], 'c1');
      expect(api.requests[2].url.queryParameters['cursor'], 'c2');
    });

    test('payouts follow the offset and stop early', () async {
      final api = FakeApi((r, call) {
        final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
        return json({
          'items': [
            for (var i = 0; i < 2; i++) {'id': 'po_${offset + i}'}
          ],
          'total': 100,
        });
      });
      final ids = await api
          .bachs()
          .payouts
          .listAll(
              params: const ListPayoutsParams(
                  limit: 2, status: PayoutStatus.failed))
          .map((p) => p.id)
          .take(3)
          .toList();
      expect(ids, ['po_0', 'po_1', 'po_2']);
      expect(api.requests, hasLength(2));
      expect(api.requests[1].url.queryParameters,
          {'limit': '2', 'offset': '2', 'status_filter': 'failed'});
    });

    test('payments use has_more', () async {
      final api = FakeApi((r, call) => json({
            'items': [
              {'id': 'pay_$call'}
            ],
            'pagination': {'has_more': call == 1},
          }));
      final ids =
          await api.bachs().payments.listAll().map((p) => p.id).toList();
      expect(ids, ['pay_1', 'pay_2']);
    });

    test('errors reach the stream', () async {
      final api = FakeApi((r, _) => json({'detail': 'no'}, 403));
      await expectLater(api.bachs().refunds.listAll().toList(),
          throwsWhere<BachsApiException>((e) => e.statusCode == 403));
    });

    test('generated lists with path IDs validate them', () async {
      final api = FakeApi((r, _) => json({}));
      await expectLater(api.bachs().persons.listAll('').toList(),
          throwsWhere<BachsConfigException>());
      expect(api.requests, isEmpty);
    });
  });

  test('logging never includes secrets or bodies', () async {
    final logs = <BachsLogRecord>[];
    final api = FakeApi((r, call) => call == 1
        ? json({'detail': 'down'}, 503)
        : json({'url': 'https://portal.test/secret-session'}));
    final c = api.bachs(logger: logs.add, logLevel: BachsLogLevel.debug);
    // The read is retried after the 503, so the debug log sees both
    // attempts.
    await c.payouts.get('po_1');
    await c.customerPortal.createSession('cust_1');
    expect(logs.where((l) => l.message == 'bachs: request'), hasLength(3));
    final all = logs.join('\n');
    expect(all, isNot(contains(sandboxKey)));
    expect(all, isNot(contains('secret-session')));
    expect(all, contains('/v1/payouts/po_1'));
  });

  group('generated resources', () {
    test('two path IDs, and a delete with no body', () async {
      final api = FakeApi((r, _) => http.Response('', 204));
      await api.bachs().persons.delete('acct_1', 'per_2');
      final r = api.requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, '/v1/accounts/acct_1/persons/per_2');
      expect(r.body, isEmpty);
    });

    test('raw JSON responses are passed through', () async {
      final api = FakeApi((r, _) => json([
            {'code': 'llc'}
          ]));
      final out = await api.bachs().reference.businessStructures(
          params: const ReferenceCountryParams(country: 'NG'));
      expect(out, [
        {'code': 'llc'}
      ]);
      expect(api.requests.single.url.queryParameters, {'country': 'NG'});
    });

    test('refund create sends only the fields set', () async {
      final api = FakeApi((r, _) => json({'refund_id': 'rf_1'}));
      final refund = await api.bachs().refunds.create(const CreateRefundParams(
          chargeId: 'ch_1', reference: 'r1', amount: '5.00'));
      expect(refund.refundId, 'rf_1');
      expect(jsonDecode(api.requests.single.body),
          {'charge_id': 'ch_1', 'reference': 'r1', 'amount': '5.00'});
    });
  });

  group('uploads', () {
    test('send a multipart form', () async {
      final api = FakeApi((r, _) => json({'upload_id': 'upl_1'}));
      final upload = await api.bachs().uploads.create(CreateUploadParams(
          file: BachsFile('logo.png', utf8.encode('PNGDATA')),
          scope: 'product-media'));
      expect(upload.uploadId, 'upl_1');
      final r = api.requests.single;
      expect(r.url.path, '/v1/utilities/uploads');
      expect(r.headers['Content-Type'],
          startsWith('multipart/form-data; boundary='));
      expect(r.body, contains('name="scope"\r\n\r\nproduct-media'));
      expect(r.body, contains('filename="logo.png"'));
      expect(r.body, contains('PNGDATA'));
    });

    test('reject bad input before sending', () async {
      final api = FakeApi((r, _) => json({}));
      final c = api.bachs();
      await expectLater(
          c.uploads.create(CreateUploadParams(
              file: BachsFile('a.png', [1]), scope: 'Bad Scope')),
          throwsWhere<BachsConfigException>());
      await expectLater(
          c.uploads.create(CreateUploadParams(file: BachsFile('', [1]))),
          throwsWhere<BachsConfigException>());
      await expectLater(
          c.disputes.uploadDocument(
              BachsFile('big.pdf', List.filled((10 << 20) + 1, 0))),
          throwsWhere<BachsConfigException>());
      expect(api.requests, isEmpty);
    });
  });
}
