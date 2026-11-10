part of 'bachs.dart';

// Lenient JSON readers. A missing or mistyped value becomes the type's empty
// value (or null), so an API change never breaks decoding; the full body is
// always available in `raw`.

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

Map<String, dynamic>? _mapOrNull(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

Map<String, T>? _mapOf<T>(Object? v, T Function(Object? v) f) =>
    v is Map ? {for (final e in v.entries) '${e.key}': f(e.value)} : null;

String _str(Object? v) => v == null ? '' : (v is String ? v : '$v');

String? _strOrNull(Object? v) => v == null ? null : (v is String ? v : '$v');

int _int(Object? v) => _intOrNull(v) ?? 0;

int? _intOrNull(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

// Used by generated code when the spec has a number field.
// ignore: unused_element
double? _doubleOrNull(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

bool _bool(Object? v) => _boolOrNull(v) ?? false;

bool? _boolOrNull(Object? v) =>
    v is bool ? v : (v == 'true' ? true : (v == 'false' ? false : null));

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

T? _obj<T>(Object? v, T Function(Map<String, dynamic> json) f) =>
    v is Map ? f(v.cast<String, dynamic>()) : null;

List<T> _list<T>(Object? v, T Function(Object? v) f) =>
    v is List ? [for (final e in v) f(e)] : <T>[];

String? _timeToJson(DateTime? t) => t?.toUtc().toIso8601String();

/// Drops null values, so optional fields left unset are not sent.
Map<String, dynamic> _compact(Map<String, dynamic> m) =>
    m..removeWhere((_, v) => v == null);
