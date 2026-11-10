/// A Dart and Flutter client for the Bachs payments API.
///
/// It behaves like the official Node.js (`@bachs/sdk`) and Python (`bachs`)
/// SDKs, version 2.x, and covers every operation in the public API
/// reference: payments and checkout, products, customers, subscriptions,
/// refunds, disputes, balances, conversions, payouts, virtual accounts,
/// uploads, webhook endpoints and events, Connect (accounts, persons,
/// transfers, platform fees), reference data, and webhook signature
/// verification.
///
/// ```dart
/// final client = BachsClient(apiKey);
/// final session = await client.checkoutSessions.create(
///   CreateCheckoutSessionParams(
///     pricing: CheckoutPricing(currency: 'USD', amount: '29.00'),
///     customer: CheckoutCustomerParams(email: 'ada@example.com'),
///     successUrl: 'https://example.com/thanks',
///   ),
///   options: RequestOptions(idempotencyKey: 'order-1042'),
/// );
/// ```
///
/// Money is always a decimal string at the currency's precision (`"29.00"`),
/// paired with an ISO 4217 currency code. It is never in minor units.
library;

export 'src/bachs.dart';
