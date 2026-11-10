part of 'bachs.dart';

/// Names a webhook event.
extension type const EventType(String value) implements String {
  static const checkoutCompleted = EventType('checkout.completed');
  static const checkoutExpired = EventType('checkout.expired');
  static const collectionSucceeded = EventType('collection.succeeded');
  static const collectionFailed = EventType('collection.failed');
  static const collectionUnderpaid = EventType('collection.underpaid');
  static const customerSubscriptionCreated =
      EventType('customer.subscription.created');
  static const customerSubscriptionUpdated =
      EventType('customer.subscription.updated');
  static const customerSubscriptionDeleted =
      EventType('customer.subscription.deleted');
  static const invoiceCreated = EventType('invoice.created');
  static const invoicePaid = EventType('invoice.paid');
  static const invoicePaymentFailed = EventType('invoice.payment_failed');
  static const payoutCreated = EventType('payout.created');
  static const payoutPaid = EventType('payout.paid');
  static const payoutFailed = EventType('payout.failed');
  static const refundCreated = EventType('refund.created');
  static const refundPaid = EventType('refund.paid');
  static const refundFailed = EventType('refund.failed');
  static const disputeCreated = EventType('dispute.created');
  static const disputeUpdated = EventType('dispute.updated');
  static const conversionCompleted = EventType('conversion.completed');
  static const conversionFailed = EventType('conversion.failed');
  static const customerCreated = EventType('customer.created');
  static const customerUpdated = EventType('customer.updated');
  static const accountUpdated = EventType('account.updated');
  static const capabilityUpdated = EventType('capability.updated');
  static const transferCreated = EventType('transfer.created');
}

/// A verified webhook delivery.
///
/// Bachs delivers at least once and in no guaranteed order. Store processed
/// event IDs to skip duplicates, and compare [createdAt] before overwriting
/// newer state.
class BachsEvent {
  /// Decodes an event.
  BachsEvent.fromJson(Map<String, dynamic> json)
      : raw = json,
        id = _str(json['id']),
        type = EventType(_str(json['type'])),
        createdAt = _time(json['created_at']),
        organizationId = _str(json['organization_id']),
        account = _strOrNull(json['account']),
        data = json['data'];

  /// The full JSON object.
  final Map<String, dynamic> raw;

  /// Starts with `evt_`.
  final String id;
  final EventType type;
  final DateTime? createdAt;

  /// The account the event belongs to. For events from a connected account
  /// it is that account.
  final String organizationId;

  /// Set only on events from connected accounts.
  final String? account;

  /// The event payload as decoded JSON. Read an object payload with
  /// [dataAs], for example `event.dataAs(Payment.fromJson)`.
  final Object? data;

  /// Decodes an object payload with [fromJson].
  T dataAs<T>(T Function(Map<String, dynamic> json) fromJson) {
    final d = data;
    if (d is! Map) {
      throw BachsWebhookException('event $id has no object data');
    }
    return fromJson(d.cast<String, dynamic>());
  }
}

/// Verifies webhook deliveries.
abstract final class BachsWebhook {
  /// The webhook signature header this SDK verifies. Its value is
  /// `t=<unix seconds>,v1=<hex HMAC-SHA256>`, with one v1 entry per active
  /// signing secret while a secret is being rotated.
  static const signatureHeader = 'X-Bachs-Signature-V2';

  /// How far a delivery's timestamp may be from the local clock before it is
  /// rejected.
  static const defaultTolerance = Duration(seconds: 300);

  /// Verifies a webhook delivery and returns the parsed event.
  ///
  /// Pass the raw request body exactly as received, before any JSON parsing:
  /// re-encoding a parsed body changes its bytes and breaks the signature.
  /// [headers] are the request headers; the signature header is found
  /// whatever its case. The [signingSecret] is the endpoint's secret, not
  /// your API key.
  ///
  /// On a [BachsWebhookException], respond 400. After a successful call,
  /// respond 2xx once the event is safely stored, and 5xx if your processing
  /// fails so Bachs retries. This does not deduplicate events.
  static BachsEvent constructEvent(
    List<int> payload,
    Map<String, String> headers,
    String signingSecret, {
    Duration tolerance = defaultTolerance,
    DateTime? now,
  }) {
    String? header;
    final wanted = signatureHeader.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == wanted) {
        header = entry.value;
        break;
      }
    }
    verifySignature(payload, header ?? '', signingSecret,
        tolerance: tolerance, now: now);

    Object? json;
    try {
      json = jsonDecode(utf8.decode(payload));
    } on FormatException catch (e) {
      throw BachsWebhookException('body is not a valid event', e);
    }
    if (json is! Map) {
      throw const BachsWebhookException('body is not a valid event');
    }
    final event = BachsEvent.fromJson(json.cast<String, dynamic>());
    if (event.id.isEmpty || event.type.isEmpty) {
      throw const BachsWebhookException('body is missing the event id or type');
    }
    return event;
  }

  /// Checks an `X-Bachs-Signature-V2` header value against the raw body. It
  /// accepts the delivery if any v1 signature matches, which keeps
  /// deliveries valid while a signing secret is being rotated.
  ///
  /// Throws a [BachsWebhookException] when the delivery is not valid.
  /// Non-positive [tolerance] values are ignored.
  static void verifySignature(
    List<int> payload,
    String header,
    String signingSecret, {
    Duration tolerance = defaultTolerance,
    DateTime? now,
  }) {
    if (tolerance <= Duration.zero) tolerance = defaultTolerance;
    if (signingSecret.isEmpty) {
      throw const BachsWebhookException('the signing secret is empty');
    }
    if (header.trim().isEmpty) {
      throw const BachsWebhookException(
          'the $signatureHeader header is missing');
    }

    final (timestamp, signatures) = _parseHeader(header);
    final sent = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final age = (now ?? DateTime.now()).difference(sent);
    if (age > tolerance || age < -tolerance) {
      throw BachsWebhookException(
          'timestamp is outside the ${tolerance.inSeconds}s tolerance');
    }

    final expected = _computeSignature(payload, signingSecret, timestamp);
    for (final signature in signatures) {
      final got = _hexDecode(signature);
      if (got != null && _constantTimeEquals(got, expected)) return;
    }
    throw const BachsWebhookException('no signature matches');
  }

  /// Returns an `X-Bachs-Signature-V2` header value for [payload]. Use it to
  /// build signed deliveries in your own tests.
  static String signPayload(
      List<int> payload, String signingSecret, DateTime time) {
    final ts = time.millisecondsSinceEpoch ~/ 1000;
    final sig = _computeSignature(payload, signingSecret, ts)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 't=$ts,v1=$sig';
  }

  static List<int> _computeSignature(
      List<int> payload, String secret, int timestamp) {
    final mac = Hmac(sha256, utf8.encode(secret));
    return mac.convert([...utf8.encode('$timestamp.'), ...payload]).bytes;
  }

  static (int, List<String>) _parseHeader(String header) {
    int? timestamp;
    final signatures = <String>[];
    for (final part in header.split(',')) {
      final p = part.trim();
      final eq = p.indexOf('=');
      if (eq < 0) continue;
      final key = p.substring(0, eq);
      final value = p.substring(eq + 1);
      switch (key) {
        case 't':
          final ts = int.tryParse(value);
          if (ts == null) {
            throw const BachsWebhookException('the timestamp is not a number');
          }
          timestamp = ts;
        case 'v1':
          signatures.add(value);
      }
      // Other schemes are ignored, so a future scheme alongside v1 does not
      // break verification.
    }
    if (timestamp == null) {
      throw const BachsWebhookException(
          'the signature header has no timestamp');
    }
    if (signatures.isEmpty) {
      throw const BachsWebhookException(
          'the signature header has no v1 signature');
    }
    return (timestamp, signatures);
  }

  static List<int>? _hexDecode(String hex) {
    if (hex.length.isOdd) return null;
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (b == null) return null;
      out.add(b);
    }
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
