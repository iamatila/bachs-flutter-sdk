part of 'bachs.dart';

/// The unit of a billing cycle or trial.
extension type const Interval(String value) implements String {
  static const day = Interval('day');
  static const week = Interval('week');
  static const month = Interval('month');
  static const year = Interval('year');
}

/// A repeating duration, such as "every 3 months" (interval month,
/// frequency 3). It describes billing cycles and trial periods.
class Cadence {
  /// Creates a cadence.
  const Cadence({required this.interval, required this.frequency});

  /// Decodes a cadence from the API.
  factory Cadence.fromJson(Map<String, dynamic> json) => Cadence(
        interval: Interval(_str(json['interval'])),
        frequency: _int(json['frequency']),
      );

  final Interval interval;
  final int frequency;

  /// Encodes the cadence for a request.
  Map<String, dynamic> toJson() =>
      {'interval': interval.value, 'frequency': frequency};
}

/// How something is priced.
extension type const PriceType(String value) implements String {
  /// A set amount.
  static const fixed = PriceType('fixed');

  /// No charge.
  static const free = PriceType('free');

  /// The customer chooses the amount, within optional bounds.
  static const custom = PriceType('custom');
}

/// Where a page sits in the full result set.
class Pagination {
  /// Decodes pagination from the API.
  Pagination.fromJson(Map<String, dynamic> json)
      : nextCursor = _str(json['next_cursor']),
        prevCursor = _str(json['prev_cursor']),
        hasMore = _bool(json['has_more']),
        limit = _int(json['limit']),
        offset = _int(json['offset']),
        returned = _int(json['returned']),
        total = _int(json['total']),
        _present = json.containsKey('has_more') ||
            _int(json['total']) > 0 ||
            _int(json['returned']) > 0;

  final String nextCursor;
  final String prevCursor;
  final bool hasMore;
  final int limit;
  final int offset;
  final int returned;
  final int total;
  final bool _present;
}

/// A processing fee in the currency it was charged in.
class Fee {
  /// Decodes a fee. It accepts the documented object form and also a bare
  /// decimal string, which older responses used.
  factory Fee.fromJson(Object? json) => json is Map
      ? Fee._(_str(json['amount']), _str(json['currency']))
      : Fee._(_str(json), '');

  const Fee._(this.amount, this.currency);

  final String amount;
  final String currency;
}

/// A postal address.
class Address {
  /// Creates an address.
  const Address({
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  /// Decodes an address from the API.
  factory Address.fromJson(Map<String, dynamic> json) => Address(
        line1: _strOrNull(json['line1']),
        line2: _strOrNull(json['line2']),
        city: _strOrNull(json['city']),
        state: _strOrNull(json['state']),
        postalCode: _strOrNull(json['postal_code']),
        country: _strOrNull(json['country']),
      );

  final String? line1;
  final String? line2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  /// Encodes the address for a request.
  Map<String, dynamic> toJson() => _compact({
        'line1': line1,
        'line2': line2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      });
}

/// Pages through an offset-paged list, fetching pages only as the stream is
/// consumed, so cancelling the subscription stops the requests.
Stream<T> _paginateOffset<P, T>({
  required Map<String, List<String>>? query,
  required int? offset,
  required Future<P> Function(Map<String, List<String>> query) fetch,
  required List<T> Function(P page) items,
  required bool Function(P page, int nextOffset, int got) hasMore,
}) async* {
  final q = {...?query};
  var next = offset ?? 0;
  while (true) {
    final page = await fetch(Map.of(q));
    final got = items(page);
    for (final item in got) {
      yield item;
    }
    next += got.length;
    if (got.isEmpty || !hasMore(page, next, got.length)) return;
    q['offset'] = ['$next'];
  }
}

/// Pages through a cursor-paged list.
Stream<T> _paginateCursor<P, T>({
  required Map<String, List<String>>? query,
  required Future<P> Function(Map<String, List<String>> query) fetch,
  required List<T> Function(P page) items,
  required Pagination Function(P page) pagination,
}) async* {
  final q = {...?query};
  while (true) {
    final page = await fetch(Map.of(q));
    final got = items(page);
    for (final item in got) {
      yield item;
    }
    final p = pagination(page);
    if (got.isEmpty || !p.hasMore || p.nextCursor.isEmpty) return;
    q['cursor'] = [p.nextCursor];
  }
}

/// Decides whether an offset-paged list continues. It prefers the API's own
/// has_more, then the total, then a short page.
bool _offsetHasMore(
    Pagination? p, int nextOffset, int total, int got, int? limit) {
  if (p != null && p._present) return p.hasMore;
  if (total > 0) return nextOffset < total;
  return limit != null && limit > 0 && got >= limit;
}

/// Builds query parameters, dropping unset values.
Map<String, List<String>> _queryOf(Map<String, Object?> values) {
  final q = <String, List<String>>{};
  values.forEach((key, value) {
    if (value == null) return;
    if (value is List) {
      if (value.isNotEmpty) q[key] = [for (final v in value) '$v'];
    } else if (value is String) {
      if (value.isNotEmpty) q[key] = [value];
    } else {
      q[key] = ['$value'];
    }
  });
  return q;
}
