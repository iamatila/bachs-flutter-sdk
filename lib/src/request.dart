part of 'bachs.dart';

/// Adjusts a single call.
class RequestOptions {
  /// Creates per-call options.
  const RequestOptions({
    this.idempotencyKey,
    this.timeout,
    this.maxRetries,
    this.account,
    this.abortTrigger,
  });

  /// Sent as `Idempotency-Key` on a write. Bachs returns the stored response
  /// when the same key is retried with the same body, and 409
  /// `IDEMPOTENCY_CONFLICT` when the body differs. Derive keys from your own
  /// IDs, such as an order ID. Reads reject it.
  final String? idempotencyKey;

  /// Overrides the client timeout for this call, including retries.
  final Duration? timeout;

  /// Overrides the client retry count for this read.
  final int? maxRetries;

  /// Sent as `X-Account-Id`, so the call acts for a connected account you
  /// own, on endpoints that accept it.
  final String? account;

  /// Cancels the call when it completes. Cancelling stops waiting, but
  /// cannot undo a write that already reached Bachs.
  final Future<void>? abortTrigger;
}

/// A request body that is already encoded, such as a multipart form.
class _EncodedBody {
  const _EncodedBody(this.bytes, this.contentType);
  final List<int> bytes;
  final String contentType;
}

const _retryableStatus = {429, 500, 502, 503, 504};

Object? _identity(Object? json) => json;
void _ignore(Object? json) {}

extension on BachsClient {
  /// Sends a request and decodes the JSON response with [decode].
  ///
  /// Reads (GET) are retried on network failures and retryable statuses.
  /// Writes are never retried.
  Future<T> _request<T>(
    String method,
    String path,
    T Function(Object? json) decode, {
    Map<String, List<String>>? query,
    Object? body,
    RequestOptions? options,
  }) async {
    final o = options ?? const RequestOptions();
    final isRead = method == 'GET';
    final key = o.idempotencyKey;
    if (key != null && key.isNotEmpty && isRead) {
      throw const BachsConfigException('idempotency keys apply to writes only');
    }
    final timeout = (o.timeout != null && o.timeout! > Duration.zero)
        ? o.timeout!
        : _timeout;
    final maxRetries = isRead ? math.max(o.maxRetries ?? _maxRetries, 0) : 0;

    List<int>? payload;
    var contentType = 'application/json';
    if (body is _EncodedBody) {
      payload = body.bytes;
      contentType = body.contentType;
    } else if (body != null) {
      try {
        payload = utf8.encode(jsonEncode(body));
      } on Object catch (e) {
        throw BachsConfigException('could not encode the request body', e);
      }
    }

    if (!_environmentLogged) {
      _environmentLogged = true;
      _log(BachsLogLevel.info, 'bachs: client ready',
          {'environment': environment.name});
    }

    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final op = _Operation(timeout, o.abortTrigger);
    // Assigned in the loop and returned after the try, so that no value is
    // returned from inside it.
    late final T result;
    try {
      for (var attempt = 1;; attempt++) {
        if (op.aborted) {
          // Nothing was sent on this attempt, but an earlier one may have
          // been.
          throw op.networkError(op.abortCause,
              outcomeUnknown: !isRead && attempt > 1);
        }
        final stopwatch = Stopwatch()..start();
        http.StreamedResponse response;
        try {
          response = await op
              .race(_send(method, uri, payload, contentType, o, op.abort));
        } on Object catch (e) {
          // The SDK cannot tell whether a failed write reached Bachs, so a
          // write's outcome is always treated as unknown.
          final error = op.networkError(e, outcomeUnknown: !isRead);
          _log(BachsLogLevel.debug, 'bachs: request failed', {
            'method': method,
            'path': path,
            'attempt': attempt,
            'duration': stopwatch.elapsed,
            'error': error.cause.toString(),
          });
          if (attempt <= maxRetries &&
              !error.isCanceled &&
              !error.isTimeout &&
              await op.wait(_backoff(attempt, null))) {
            continue;
          }
          if (isRead && attempt > 1) {
            _log(BachsLogLevel.warn, 'bachs: read failed after retries',
                {'method': method, 'path': path, 'attempts': attempt});
          }
          throw error;
        }

        final requestId = response.headers['x-request-id'];
        Uint8List raw;
        try {
          raw = await op.race(response.stream.toBytes());
        } on Object catch (e) {
          throw op.networkError(e,
              outcomeUnknown: !isRead, responseStatusCode: response.statusCode);
        }
        _log(BachsLogLevel.debug, 'bachs: request', {
          'method': method,
          'path': path,
          'status': response.statusCode,
          'attempt': attempt,
          'duration': stopwatch.elapsed,
          'request_id': requestId,
        });

        if (response.statusCode >= 200 && response.statusCode < 300) {
          result = _decodeResponse(raw, response.statusCode, requestId, decode);
          break;
        }

        final error = _apiError(response, raw, requestId, isRead);
        if (isRead &&
            _retryableStatus.contains(response.statusCode) &&
            attempt <= maxRetries &&
            await op.wait(_backoff(attempt, error.retryAfter))) {
          continue;
        }
        if (isRead && attempt > 1) {
          _log(BachsLogLevel.warn, 'bachs: read failed after retries', {
            'method': method,
            'path': path,
            'attempts': attempt,
            'status': response.statusCode,
            'request_id': requestId,
          });
        }
        throw error;
      }
    } finally {
      op.dispose();
    }
    return result;
  }

  Future<http.StreamedResponse> _send(
      String method,
      Uri uri,
      List<int>? payload,
      String contentType,
      RequestOptions o,
      Future<void> abort) {
    final request = http.AbortableRequest(method, uri, abortTrigger: abort);
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.headers['Accept'] = 'application/json';
    // Browsers refuse to let scripts set User-Agent.
    if (!platform.isWeb) request.headers['User-Agent'] = _userAgent;
    if (payload != null) {
      request.headers['Content-Type'] = contentType;
      request.bodyBytes = payload;
    }
    final key = o.idempotencyKey;
    if (key != null && key.isNotEmpty) {
      request.headers['Idempotency-Key'] = key;
    }
    final account = o.account;
    if (account != null && account.isNotEmpty) {
      request.headers['X-Account-Id'] = account;
    }
    return _http.send(request);
  }
}

T _decodeResponse<T>(Uint8List raw, int status, String? requestId,
    T Function(Object? json) decode) {
  Object? json;
  if (raw.any((b) => b != 0x20 && b != 0x0a && b != 0x0d && b != 0x09)) {
    try {
      json = jsonDecode(utf8.decode(raw));
    } on FormatException catch (e) {
      throw BachsResponseException(status, requestId, e);
    }
  }
  try {
    return decode(json);
  } on BachsException {
    rethrow;
  } on Object catch (e) {
    throw BachsResponseException(status, requestId, e);
  }
}

BachsApiException _apiError(http.StreamedResponse response, Uint8List raw,
    String? requestId, bool isRead) {
  final status = response.statusCode;
  final body = utf8.decode(raw, allowMalformed: true);
  String? errorCode;
  String? detail;
  String? docUrl;
  var fieldErrors = const <FieldError>[];
  try {
    final envelope = jsonDecode(body);
    if (envelope is Map) {
      final code = envelope['error_code'];
      if (code is String && code.isNotEmpty) errorCode = code;
      final d = envelope['detail'];
      if (d is String) {
        detail = d;
      } else if (d != null) {
        detail = jsonEncode(d);
      }
      final url = envelope['doc_url'];
      if (url is String && url.isNotEmpty) docUrl = url;
      final errors = envelope['errors'];
      if (errors is List) {
        fieldErrors = [
          for (final e in errors)
            if (e is Map) FieldError.fromJson(e.cast<String, dynamic>()),
        ];
      }
    }
  } on FormatException {
    // Not a Bachs error object, such as a gateway error page.
  }
  if (detail == null || detail.isEmpty) {
    detail = response.reasonPhrase ?? 'HTTP $status';
  }
  return BachsApiException(
    statusCode: status,
    errorCode: errorCode,
    detail: detail,
    fieldErrors: fieldErrors,
    docUrl: docUrl,
    requestId: requestId,
    retryAfter: _parseRetryAfter(response.headers['retry-after']),
    // A write that got a 5xx or 408 may still have been applied.
    outcomeUnknown: !isRead && (status >= 500 || status == 408),
    body: body,
  );
}

Duration? _parseRetryAfter(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final seconds = int.tryParse(v);
  if (seconds != null) return seconds >= 0 ? Duration(seconds: seconds) : null;
  try {
    final wait = parseHttpDate(v).difference(DateTime.now());
    return wait > Duration.zero ? wait : null;
  } on FormatException {
    return null;
  }
}

final _random = math.Random();

/// About 0.5s, then 1s, then 2s, with 20% jitter, unless the server sent
/// Retry-After.
Duration _backoff(int attempt, Duration? retryAfter) {
  if (retryAfter != null && retryAfter > Duration.zero) return retryAfter;
  final base = BachsClient.retryBaseDelay * (1 << (attempt - 1));
  final jitter = 0.8 + 0.4 * _random.nextDouble();
  return base * jitter;
}

/// Tracks one operation's deadline and cancellation across its attempts.
class _Operation {
  _Operation(this.timeout, Future<void>? abortTrigger) {
    _stopwatch.start();
    _timer = Timer(timeout, () => _fire(timedOut: true));
    abortTrigger?.then((_) => _fire(timedOut: false),
        onError: (Object _) => _fire(timedOut: false));
  }

  final Duration timeout;
  final _stopwatch = Stopwatch();
  final _abort = Completer<void>();
  late final Timer _timer;
  bool _disposed = false;
  bool timedOut = false;
  bool canceled = false;

  Future<void> get abort => _abort.future;
  bool get aborted => _abort.isCompleted;
  Object get abortCause => timedOut ? 'timed out' : 'cancelled';

  void _fire({required bool timedOut}) {
    if (_disposed || _abort.isCompleted) return;
    if (timedOut) {
      this.timedOut = true;
    } else {
      canceled = true;
    }
    _abort.complete();
  }

  /// Completes with [future], or fails as soon as the operation is aborted,
  /// even if the HTTP client ignores the abort trigger.
  Future<T> race<T>(Future<T> future) {
    final completer = Completer<T>();
    future.then((value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      } else if (value is http.StreamedResponse) {
        value.stream.listen(null, onError: (Object _) {}).cancel();
      }
    }, onError: (Object e, StackTrace st) {
      if (!completer.isCompleted) completer.completeError(e, st);
    });
    abort.then((_) {
      if (!completer.isCompleted) completer.completeError(abortCause);
    });
    return completer.future;
  }

  /// Waits [delay] unless the deadline would pass first or the operation is
  /// aborted, in which case it returns false so the caller stops retrying.
  Future<bool> wait(Duration delay) {
    if (aborted || timeout - _stopwatch.elapsed <= delay) {
      return Future.value(false);
    }
    final completer = Completer<bool>();
    final timer = Timer(delay, () {
      if (!completer.isCompleted) completer.complete(true);
    });
    abort.then((_) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future;
  }

  BachsNetworkException networkError(Object cause,
      {required bool outcomeUnknown, int? responseStatusCode}) {
    if (canceled) {
      return BachsNetworkException._('the request was cancelled',
          outcomeUnknown: outcomeUnknown,
          responseStatusCode: responseStatusCode,
          isCanceled: true);
    }
    if (timedOut) {
      return BachsNetworkException._(
          TimeoutException('operation exceeded $timeout', timeout),
          outcomeUnknown: outcomeUnknown,
          responseStatusCode: responseStatusCode,
          isTimeout: true);
    }
    return BachsNetworkException._(cause,
        outcomeUnknown: outcomeUnknown, responseStatusCode: responseStatusCode);
  }

  void dispose() {
    _disposed = true;
    _timer.cancel();
  }
}

/// Escapes an ID for use in a URL path, rejecting empty IDs before anything
/// is sent.
String _pathId(String name, String id) {
  if (id.trim().isEmpty) throw BachsConfigException('$name is required');
  return Uri.encodeComponent(id);
}
