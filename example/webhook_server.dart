// A webhook endpoint that verifies Bachs deliveries.
//
//   BACHS_WEBHOOK_SECRET=whsec_... dart run example/webhook_server.dart
//
// Then point a webhook endpoint at http://<host>:8080/webhooks/bachs.
import 'dart:io';

import 'package:bachs/bachs.dart';

/// Event IDs already handled. Use your database in production: Bachs
/// delivers at least once, so the same event can arrive twice.
final processed = <String>{};

Future<void> main() async {
  final secret = Platform.environment['BACHS_WEBHOOK_SECRET'] ?? '';
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Listening on :8080');

  await for (final request in server) {
    if (request.method != 'POST' || request.uri.path != '/webhooks/bachs') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    // The raw body, before any JSON parsing.
    final payload = await request
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));

    BachsEvent event;
    try {
      event = BachsWebhook.constructEvent(payload, headers, secret);
    } on BachsWebhookException catch (e) {
      // 400 tells Bachs not to retry.
      stderr.writeln('rejected webhook: ${e.reason}');
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      continue;
    }

    try {
      if (processed.add(event.id)) await handle(event);
      request.response.statusCode = HttpStatus.ok;
    } on Object catch (e) {
      // 5xx makes Bachs retry the delivery.
      processed.remove(event.id);
      stderr.writeln('failed to process ${event.id}: $e');
      request.response.statusCode = HttpStatus.internalServerError;
    }
    await request.response.close();
  }
}

Future<void> handle(BachsEvent event) async {
  switch (event.type) {
    case EventType.collectionSucceeded:
      final payment = event.dataAs(Payment.fromJson);
      print('paid: ${payment.paymentId} ${payment.amountPaid} '
          '${payment.currency} (reference ${payment.reference})');
    case EventType.payoutFailed:
      final payout = event.dataAs(Payout.fromJson);
      print('payout failed: ${payout.id} ${payout.failureReason}');
    default:
      print('ignored ${event.type}');
  }
}
