// Creates a one-time checkout session in the sandbox and prints the URL to
// send the customer to.
//
//   BACHS_API_KEY=sk_sandbox_... dart run example/main.dart
import 'dart:io';

import 'package:bachs_sdk/bachs_sdk.dart';

Future<void> main() async {
  final client = BachsClient(Platform.environment['BACHS_API_KEY'] ?? '');
  const orderId = 'order-1042';

  try {
    final session = await client.checkoutSessions.create(
      const CreateCheckoutSessionParams(
        pricing: CheckoutPricing(currency: 'USD', amount: '29.00'),
        customer: CheckoutCustomerParams(email: 'ada@example.com', name: 'Ada'),
        successUrl: 'https://example.com/thanks',
        cancelUrl: 'https://example.com/cart',
        reference: orderId,
        metadata: {'order_id': orderId},
      ),
      options: const RequestOptions(idempotencyKey: 'checkout-$orderId'),
    );
    print('Send the customer to: ${session.checkoutUrl}');
    print('Fulfil the order when the collection.succeeded webhook arrives, '
        'not on the redirect.');
  } on BachsException catch (e) {
    if (e is BachsApiException && e.hasErrorCode(ErrorCode.validation)) {
      for (final f in e.fieldErrors) {
        stderr.writeln('invalid ${f.field}: ${f.message}');
      }
    } else if (e.outcomeUnknown) {
      // The session may exist. Record the order for reconciliation rather
      // than creating it again with a new key.
      stderr.writeln('checkout outcome unknown for $orderId: $e');
    } else {
      stderr.writeln(e);
    }
    exitCode = 1;
  } finally {
    client.close();
  }
}
