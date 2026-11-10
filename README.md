# bachs-flutter-sdk

A Dart and Flutter client for the [Bachs](https://bachs.io) payments API. It
is a port of [bachs-sdk-go](https://github.com/iamatila/bachs-sdk-go) and
covers every operation in the public API reference (`/v1`): checkout,
payments, products, customers, subscriptions, refunds, disputes, balances,
conversions, payouts, virtual accounts, uploads, webhook endpoints and
events, Connect, reference data and webhook signature verification.

This is not an official Bachs SDK.

**Status:** actively maintained. Versions before 1.0 may change the API in
a minor release; changes are noted in the [changelog](CHANGELOG.md).

```yaml
dependencies:
  bachs_sdk: ^0.1.0
```

```dart
import 'package:bachs_sdk/bachs_sdk.dart';
```

It is pure Dart, so it runs in Flutter on Android, iOS, desktop and web, and
on Dart servers. It needs Dart 3.4 (Flutter 3.22) or later and depends only
on `http`, `http_parser` and `crypto`.

## Your API key in a Flutter app

Bachs keys are secret keys (`sk_sandbox_…`, `sk_live_…`). Bachs has no
publishable key, so every call this SDK makes uses a key that can move money:
payouts, refunds, transfers.

Anything compiled into an app can be extracted from it, whether the key is a
constant, a `--dart-define` or an obfuscated string. When a live key ships
inside an app, treat it as public. The safer setup is to run this SDK on
your backend and have the app ask your backend for a `checkoutUrl` to open:

```
Flutter app ──► your backend (holds the key, uses this SDK) ──► Bachs
     ▲                     │
     └──── checkoutUrl ◄───┘   the app opens it in a browser or web view
```

Using the SDK directly in the app is fine with a sandbox key while you build
and test.

## Create a client

```dart
final client = BachsClient(apiKey);
```

Create one client and reuse it. Creating it sends no request, so an invalid
key shows up on the first call. Call `client.close()` when you are done.

Keys starting `sk_sandbox_` use `https://sandbox-api.bachs.io` and keys
starting `sk_live_` use `https://api.bachs.io`. Any other prefix needs
`environment:`, and an environment that contradicts the key is an error.

| Argument | Default | Purpose |
|---|---|---|
| `environment` | from the key prefix | `BachsEnvironment.sandbox` or `.production` |
| `baseUrl` | from the environment | A proxy or a test server |
| `timeout` | 30s | Total time for one operation, including retries |
| `maxRetries` | 2 | Extra attempts for reads |
| `httpClient` | a new `http.Client` | Your own client, such as one from `cupertino_http` |
| `logger` | `printBachsLog` | `null` turns logging off |
| `logLevel` | `BACHS_LOG`, else warn | `BachsLogLevel.off` silences the SDK |

## Resources

| Field | Methods |
|---|---|
| `products` | `create`, `get`, `list`, `listAll`, `update`, `archive`, `unarchive` |
| `productGroups` | `create`, `get`, `list`, `listAll`, `update`, `delete` |
| `checkoutSessions` | `create`, `get` |
| `payments` | `get`, `list`, `listAll`, `createCharge`, `getChargeStatus` |
| `customers` | `create`, `get`, `list`, `listAll`, `update` |
| `customerPortal` | `createSession` |
| `subscriptions` | `get`, `list`, `listAll`, `update`, `cancel` |
| `refunds` | `create`, `get`, `getByCharge`, `list`, `listAll` |
| `disputes` | `get`, `list`, `listAll`, `uploadDocument`, `updateEvidence`, `submit` |
| `balances` | `get`, `getPayoutSchedule`, `updatePayoutSchedule` |
| `conversions` | `createQuote`, `create`, `get`, `list`, `listAll` |
| `payoutDestinations` | `create`, `get`, `list`, `listAll`, `update`, `delete` |
| `payoutQuotes` | `create` |
| `payouts` | `create`, `get`, `list`, `listAll` |
| `virtualAccounts` | `create`, `get` |
| `uploads` | `create`, `get`, `delete` |
| `webhookEndpoints` | `create`, `get`, `list`, `listAll`, `update`, `delete`, `getSecret`, `rotateSecret`, `getMetrics`, `listEvents`, `listAllEvents`, `getEvent`, `resendEvent` |
| `webhookEvents` | `get`, `list`, `listAll`, `replay` |
| `banks` | `list`, `resolveAccount` |
| `reference` | `paymentMethods`, `paymentRails`, `supportedCurrencies`, `payoutCurrencies`, `mobileMoneyProviders`, `businessStructures`, `productCategories` |
| `accounts` (Connect) | `getMe`, `create`, `get`, `list`, `listAll`, `update`, `createLink`, `listCapabilities`, `attachDocument`, `getCheckoutSettings`, `updateCheckoutSettings` |
| `persons` (Connect) | `create`, `get`, `list`, `listAll`, `update`, `delete`, `attachDocument` |
| `transfers` (Connect) | `create`, `get`, `list`, `listAll` |
| `platformFees` (Connect) | `get`, `list`, `listAll` |
| `BachsWebhook` | `constructEvent`, `verifySignature`, `signPayload` |

Each method's doc comment names the HTTP call it makes, such as
`POST /v1/refunds`, so it maps directly onto the
[API reference](https://docs.bachs.io/api-reference/overview). The resources
beyond the official SDKs' set are generated from Bachs's published OpenAPI
spec; see [tool/gen](tool/gen/README.md) to regenerate them.
`businessStructures` and `productCategories` return decoded JSON (`Object?`),
because the spec gives them no schema.

Path IDs are positional, a required request body is positional, and
everything else is named:

```dart
await client.persons.get(accountId, personId);
await client.refunds.create(CreateRefundParams(chargeId: id, reference: ref));
await client.refunds.list(params: ListRefundsParams(limit: 20));
```

Field names follow the API in camelCase (`checkout_url` is `checkoutUrl`).
Money is a decimal string such as `"29.00"`, never minor units. Request
fields left `null` are not sent.

Upload files with `uploads.create` or `disputes.uploadDocument`, passing a
`BachsFile(name, bytes)`. Then attach the returned upload ID where it is
needed, for example `accounts.attachDocument`.

## Accept a payment

```dart
final session = await client.checkoutSessions.create(
  CreateCheckoutSessionParams(
    pricing: CheckoutPricing(currency: 'USD', amount: '29.00'),
    customer: CheckoutCustomerParams(email: 'ada@example.com'),
    successUrl: 'https://example.com/thanks',
    reference: orderId,
  ),
  options: RequestOptions(idempotencyKey: 'checkout-$orderId'),
);
// Open session.checkoutUrl for the customer.
```

Set exactly one of `productCart` and `pricing`. A cart holding a recurring
product creates a subscription when it is paid; there is no direct
create-subscription call. Fulfil orders from the `collection.succeeded`
webhook, never from the redirect.

## Pagination

`list` returns one page in the API's shape. `listAll` returns a `Stream` that
fetches pages only as you consume it, so breaking out of the loop or
cancelling the subscription stops the requests.

```dart
await for (final payout in client.payouts.listAll(
    params: ListPayoutsParams(status: PayoutStatus.failed))) {
  print('${payout.id} ${payout.failureReason}');
}
```

Products page by cursor; the other resources page by offset. Payout
destinations come back in `destinations` rather than `items`.

## Per-call options

Pass `options: RequestOptions(...)` to any method.

| Field | Purpose |
|---|---|
| `idempotencyKey` | Writes only. Sent as `Idempotency-Key` |
| `timeout` | Overrides the client timeout |
| `maxRetries` | Reads only. Overrides the retry count |
| `account` | Sends `X-Account-Id` to act for a connected account |
| `abortTrigger` | A `Future` that cancels the call when it completes |

Cancelling stops waiting, but cannot undo a write that already reached Bachs.

## Retries and uncertain writes

Reads retry on network failures and on 429, 500, 502, 503 and 504, after
about 0.5s and then 1s, honouring `Retry-After`. They stop early if the next
wait would pass the timeout.

Writes are never retried, even with an idempotency key. When a write's
result is uncertain, `e.outcomeUnknown` is true: the resource may exist. Look
it up first (for a payout, `payouts.list` with its `reference`), and if it
does not exist, retry with the same idempotency key and the same request,
never a new key.

Unlike the Go SDK, this SDK cannot see whether a failed request left the
device, so every network failure on a write counts as outcome-unknown.

## Errors

Every error is a `BachsException`, a sealed class:

| Type | When |
|---|---|
| `BachsApiException` | The API returned an error status |
| `BachsNetworkException` | Transit failure, timeout (`isTimeout`) or cancellation (`isCanceled`) |
| `BachsResponseException` | A success status with a body that could not be decoded |
| `BachsConfigException` | Invalid setup or arguments; nothing was sent |
| `BachsWebhookException` | A webhook failed its signature, timestamp or format check |

Branch on `errorCode` (for example `ErrorCode.notFound`) rather than on the
status. `isNotFound`, `hasErrorCode` and `outcomeUnknown` are available on
every `BachsException`. `requestId` holds the `x-request-id` header; include
it when contacting Bachs support. Error details and portal URLs can contain
personal data, so don't log them in full.

```dart
try {
  await client.refunds.create(params);
} on BachsApiException catch (e) {
  if (e.hasErrorCode(ErrorCode.validation)) {
    for (final f in e.fieldErrors) print('${f.field}: ${f.message}');
  }
}
```

## Webhooks

Webhooks are received by a server, so this part runs on your backend.

```dart
final event = BachsWebhook.constructEvent(
  rawBodyBytes, // before any JSON parsing
  requestHeaders,
  Platform.environment['BACHS_WEBHOOK_SECRET']!,
);
if (event.type == EventType.collectionSucceeded) {
  final payment = event.dataAs(Payment.fromJson);
}
```

`constructEvent` verifies the `X-Bachs-Signature-V2` header (whatever its
case), accepts any matching signature while a signing secret is being
rotated, and rejects deliveries more than 5 minutes from your clock
(`tolerance:` changes that). The signing secret is the endpoint's, not your
API key.

It does not deduplicate. Bachs delivers at least once and in no set order,
so store processed event IDs, compare `createdAt` before overwriting state,
respond 2xx within 10 seconds once the event is stored, and respond 5xx when
your processing fails so Bachs retries. A 400 tells Bachs not to retry.

`BachsWebhook.signPayload` builds a valid header for your own tests. See
[example/webhook_server.dart](example/webhook_server.dart) for a full
handler.

## Logging

Logs go to the `logger` callback, which prints by default. At warn the SDK
reports unrecognised key prefixes and reads that ran out of retries; at info,
the environment once per client; at debug, the method, path, status,
duration, attempt and request ID of each request. Keys, request and response
bodies, portal URLs and webhook secrets are never logged.

Set the level with `logLevel:`, the `BACHS_LOG` environment variable, or in
Flutter with `--dart-define=BACHS_LOG=debug`.

## Unknown fields

Fields the API adds before this SDK types them don't break decoding: a
missing or mistyped value becomes the field's empty value. Every response
object keeps the full JSON in `raw`.

## Development

```sh
dart pub get
dart analyze
dart test
```

See [tool/gen](tool/gen/README.md) for regenerating from the OpenAPI spec.

## License

MIT. See [LICENSE](LICENSE).
