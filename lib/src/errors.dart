part of 'bachs.dart';

/// Stable error codes the API returns in [BachsApiException.errorCode].
/// Branch on these rather than on the HTTP status.
abstract final class ErrorCode {
  static const validation = 'VALIDATION_ERROR';
  static const unauthorized = 'UNAUTHORIZED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const conflict = 'CONFLICT';
  static const idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const tooManyRequests = 'TOO_MANY_REQUESTS';
  static const internalServerError = 'INTERNAL_SERVER_ERROR';
  static const badGateway = 'BAD_GATEWAY';
  static const serviceUnavailable = 'SERVICE_UNAVAILABLE';
}

/// Every error the SDK throws.
sealed class BachsException implements Exception {
  const BachsException();

  /// True for a write that may have taken effect even though an error came
  /// back. Look the resource up before retrying, and if you retry, reuse the
  /// same idempotency key and the same request, never a new key.
  bool get outcomeUnknown => false;

  /// Whether this is a 404 from the API.
  bool get isNotFound => false;

  /// Whether this is an API error with the given [ErrorCode].
  bool hasErrorCode(String code) => false;
}

/// The API answered with an error status.
///
/// [detail] and [body] can contain personal data, so don't log them in full.
final class BachsApiException extends BachsException {
  /// Creates an API error. The SDK creates these; tests may too.
  const BachsApiException({
    required this.statusCode,
    this.errorCode,
    required this.detail,
    this.fieldErrors = const [],
    this.docUrl,
    this.requestId,
    this.retryAfter,
    this.outcomeUnknown = false,
    this.body = '',
  });

  /// The HTTP status.
  final int statusCode;

  /// The stable, machine-readable code, such as `NOT_FOUND`. It is null when
  /// the body was not a Bachs error object, as with a gateway error page.
  final String? errorCode;

  /// The human-readable message.
  final String detail;

  /// Field-level problems on some validation errors.
  final List<FieldError> fieldErrors;

  /// Documentation for this error, when the API sends it.
  final String? docUrl;

  /// The `x-request-id` header. Include it when contacting Bachs support.
  final String? requestId;

  /// The parsed `Retry-After` header.
  final Duration? retryAfter;

  @override
  final bool outcomeUnknown;

  /// The raw response body.
  final String body;

  @override
  bool get isNotFound => statusCode == 404 || errorCode == ErrorCode.notFound;

  @override
  bool hasErrorCode(String code) => errorCode == code;

  @override
  String toString() {
    final b = StringBuffer('BachsApiException: API error $statusCode');
    if (errorCode != null) b.write(' $errorCode');
    if (detail.isNotEmpty) b.write(': $detail');
    if (requestId != null) b.write(' (request_id=$requestId)');
    return b.toString();
  }
}

/// One field-level validation failure.
class FieldError {
  /// Creates a field error.
  const FieldError(
      {required this.field, required this.message, this.type, this.code});

  /// Decodes a field error from the API.
  factory FieldError.fromJson(Map<String, dynamic> json) => FieldError(
        field: _str(json['field']),
        message: _str(json['message']),
        type: _strOrNull(json['type']),
        code: _strOrNull(json['code']),
      );

  final String field;
  final String message;
  final String? type;
  final String? code;

  @override
  String toString() => '$field: $message';
}

/// A request failed in transit: a connection error, a timeout, or a
/// cancellation.
final class BachsNetworkException extends BachsException {
  const BachsNetworkException._(
    this.cause, {
    required this.outcomeUnknown,
    this.responseStatusCode,
    this.isTimeout = false,
    this.isCanceled = false,
  });

  /// The underlying error.
  final Object cause;

  /// True for a write, because the SDK cannot tell whether the request
  /// reached Bachs before it failed. Look the resource up before retrying,
  /// and if you retry, reuse the same idempotency key.
  @override
  final bool outcomeUnknown;

  /// Set when a response status arrived but its body could not be read.
  final int? responseStatusCode;

  /// The operation ran past its timeout, including time spent on retries.
  final bool isTimeout;

  /// [RequestOptions.abortTrigger] completed. Cancelling stops waiting, but
  /// cannot undo a write that already reached Bachs.
  final bool isCanceled;

  @override
  String toString() {
    if (isTimeout) return 'BachsNetworkException: request timed out: $cause';
    if (isCanceled) return 'BachsNetworkException: request cancelled';
    return 'BachsNetworkException: network error: $cause';
  }
}

/// The API answered with a success status but the body could not be decoded.
/// For a write, the operation succeeded on the Bachs side.
final class BachsResponseException extends BachsException {
  const BachsResponseException(this.statusCode, this.requestId, this.cause);

  final int statusCode;
  final String? requestId;
  final Object cause;

  @override
  String toString() {
    final id = requestId == null ? '' : ' (request_id=$requestId)';
    return 'BachsResponseException: unexpected response body '
        '(status $statusCode): $cause$id';
  }
}

/// Invalid setup or arguments. Nothing was sent.
final class BachsConfigException extends BachsException {
  const BachsConfigException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'BachsConfigException: $message'
      : 'BachsConfigException: $message: $cause';
}

/// A webhook delivery failed its signature, timestamp or format checks.
/// Respond to Bachs with 400.
final class BachsWebhookException extends BachsException {
  const BachsWebhookException(this.reason, [this.cause]);

  final String reason;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'BachsWebhookException: webhook rejected: $reason'
      : 'BachsWebhookException: webhook rejected: $reason: $cause';
}
