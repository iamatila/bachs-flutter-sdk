import 'dart:convert';

import 'package:bachs/bachs.dart';
import 'package:test/test.dart';

const secret = 'whsec_test';
final now = DateTime.utc(2026, 11, 9, 12);
final body = utf8.encode(jsonEncode({
  'id': 'evt_1',
  'type': 'collection.succeeded',
  'created_at': '2026-11-09T12:00:00Z',
  'organization_id': 'org_1',
  'data': {'payment_id': 'pay_1', 'amount': '29.00', 'status': 'succeeded'},
}));

Map<String, String> headers(String value) =>
    {BachsWebhook.signatureHeader: value};

Matcher rejected(String reason) => throwsA(predicate<Object>(
    (e) => e is BachsWebhookException && e.reason.contains(reason)));

void main() {
  test('a valid delivery becomes an event', () {
    final event = BachsWebhook.constructEvent(
        body, headers(BachsWebhook.signPayload(body, secret, now)), secret,
        now: now);
    expect(event.id, 'evt_1');
    expect(event.type, EventType.collectionSucceeded);
    expect(event.organizationId, 'org_1');
    final payment = event.dataAs(Payment.fromJson);
    expect(payment.paymentId, 'pay_1');
    expect(payment.status, PaymentStatus.succeeded);
  });

  test('the header is found whatever its case', () {
    final sig = BachsWebhook.signPayload(body, secret, now);
    expect(
        BachsWebhook.constructEvent(body, {'x-bachs-signature-v2': sig}, secret,
                now: now)
            .id,
        'evt_1');
  });

  test('any matching signature passes during secret rotation', () {
    final good = BachsWebhook.signPayload(body, secret, now).split('v1=')[1];
    final ts = now.millisecondsSinceEpoch ~/ 1000;
    final header = 't=$ts,v1=${'0' * 64},v1=$good';
    expect(
        BachsWebhook.constructEvent(body, headers(header), secret, now: now).id,
        'evt_1');
  });

  test('bad deliveries are rejected', () {
    final sig = BachsWebhook.signPayload(body, secret, now);
    final ts = now.millisecondsSinceEpoch ~/ 1000;
    expect(
        () => BachsWebhook.constructEvent([...body, 32], headers(sig), secret,
            now: now),
        rejected('no signature matches'));
    expect(
        () =>
            BachsWebhook.constructEvent(body, headers(sig), 'other', now: now),
        rejected('no signature matches'));
    expect(
        () => BachsWebhook.constructEvent(body, headers(sig), secret,
            now: now.add(const Duration(minutes: 6))),
        rejected('tolerance'));
    expect(() => BachsWebhook.constructEvent(body, {}, secret, now: now),
        rejected('missing'));
    expect(
        () => BachsWebhook.constructEvent(body, headers('t=$ts'), secret,
            now: now),
        rejected('no v1 signature'));
    expect(
        () => BachsWebhook.constructEvent(body, headers('v1=abcd'), secret,
            now: now),
        rejected('no timestamp'));
    expect(
        () => BachsWebhook.constructEvent(body, headers('t=soon,v1=ab'), secret,
            now: now),
        rejected('not a number'));
    expect(() => BachsWebhook.constructEvent(body, headers(sig), '', now: now),
        rejected('secret is empty'));
  });

  test('a wider tolerance accepts an older delivery', () {
    final sig = BachsWebhook.signPayload(body, secret, now);
    expect(
        BachsWebhook.constructEvent(body, headers(sig), secret,
                now: now.add(const Duration(minutes: 6)),
                tolerance: const Duration(minutes: 10))
            .id,
        'evt_1');
  });

  test('a signed body that is not an event is rejected', () {
    final notEvent = utf8.encode('{"hello":"world"}');
    expect(
        () => BachsWebhook.constructEvent(notEvent,
            headers(BachsWebhook.signPayload(notEvent, secret, now)), secret,
            now: now),
        rejected('missing the event id or type'));
  });

  test('unknown signature schemes are ignored', () {
    final sig = BachsWebhook.signPayload(body, secret, now);
    expect(
        BachsWebhook.constructEvent(body, headers('v2=zzz,$sig,x'), secret,
                now: now)
            .id,
        'evt_1');
  });

  test('signatures match the Go SDK', () {
    // The output of bachs-sdk-go's SignPayload([]byte(`{"a":1}`),
    // "whsec_test", time.Unix(1700000000, 0)).
    final sig = BachsWebhook.signPayload(utf8.encode('{"a":1}'), secret,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
    expect(sig,
        't=1700000000,v1=38877139021993b830af32feea6e18a8da83eb2f6e49ee50bd9e4cf4ca4d3789');
  });
}
