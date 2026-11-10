// Compiled with `dart compile js` in CI to prove the package builds for the
// web (Flutter web), where dart:io is unavailable. It is not a test suite.
import 'package:bachs_sdk/bachs_sdk.dart';

void main() {
  final client = BachsClient('sk_sandbox_x', logger: null);
  client.products.listAll().listen(print, onError: print);
  BachsWebhook.signPayload([1, 2, 3], 'whsec', DateTime.now());
}
