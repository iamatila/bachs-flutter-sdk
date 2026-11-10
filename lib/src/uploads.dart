part of 'bachs.dart';

/// A file to upload.
class BachsFile {
  /// Creates a file from its [name], such as `logo.png`, and its [bytes].
  const BachsFile(this.name, this.bytes);

  /// The file name sent to Bachs.
  final String name;

  /// The file's contents.
  final List<int> bytes;
}

/// Uploads a file.
class CreateUploadParams {
  /// Creates the upload.
  const CreateUploadParams({required this.file, this.scope});

  /// The maximum size is 20 MB.
  final BachsFile file;

  /// Groups the upload. Use `product-media` for product images. The API
  /// default is `general`.
  final String? scope;
}

const _maxUploadBytes = 20 << 20;
const _maxDisputeUploadBytes = 10 << 20;
final _scopePattern = RegExp(r'^[a-z0-9_-]{1,64}$');

/// Uploads files and manages uploads.
class UploadsService with _UploadsServiceGen {
  UploadsService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `POST /v1/utilities/uploads`. Uploads a file and returns an
  /// `upload_id` to attach to products, accounts or persons.
  Future<Upload> create(CreateUploadParams params,
      {RequestOptions? options}) async {
    final scope = params.scope;
    if (scope != null && scope.isNotEmpty && !_scopePattern.hasMatch(scope)) {
      throw BachsConfigException(
          'invalid scope "$scope": use 1 to 64 of a-z, 0-9, _ and -');
    }
    final body = _multipartBody(params.file, _maxUploadBytes,
        {if (scope != null && scope.isNotEmpty) 'scope': scope});
    return _c._request(
        'POST', '/v1/utilities/uploads', (j) => Upload.fromJson(_map(j)),
        body: body, options: options);
  }
}

/// Reads disputes and builds their evidence.
class DisputesService with _DisputesServiceGen {
  DisputesService._(this._c);

  @override
  final BachsClient _c;

  /// Calls `POST /v1/disputes/uploads`. Uploads evidence for a dispute (PDF,
  /// JPEG, PNG or GIF, up to 10 MB). Attach the returned document with
  /// `updateEvidence`.
  Future<DisputeDocument> uploadDocument(BachsFile file,
      {RequestOptions? options}) async {
    final body = _multipartBody(file, _maxDisputeUploadBytes, const {});
    return _c._request('POST', '/v1/disputes/uploads',
        (j) => DisputeDocument.fromJson(_map(j)),
        body: body, options: options);
  }
}

_EncodedBody _multipartBody(
    BachsFile file, int limit, Map<String, String> fields) {
  if (file.name.isEmpty) {
    throw const BachsConfigException('the file needs a name');
  }
  if (file.bytes.length > limit) {
    throw BachsConfigException('the file is larger than ${limit >> 20} MB');
  }

  final boundary = 'bachs-${_randomToken()}';
  final out = BytesBuilder(copy: false);
  void line(String s) => out.add(utf8.encode('$s\r\n'));
  String quote(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');

  fields.forEach((key, value) {
    line('--$boundary');
    line('Content-Disposition: form-data; name="${quote(key)}"');
    line('');
    line(value);
  });
  line('--$boundary');
  line('Content-Disposition: form-data; name="file"; '
      'filename="${quote(file.name)}"');
  line('Content-Type: application/octet-stream');
  line('');
  out.add(file.bytes);
  line('');
  line('--$boundary--');
  return _EncodedBody(
      out.takeBytes(), 'multipart/form-data; boundary=$boundary');
}

String _randomToken() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(List.generate(
      24, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
}
