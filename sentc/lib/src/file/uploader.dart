import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import 'package:sentc/sentc.dart';
import 'package:sentc/src/rust/api/file.dart' as api_file;

class UploadResult {
  final String fileId;
  final String? encryptedFileName;

  UploadResult({
    required this.fileId,
    required this.encryptedFileName,
  });
}

class FileCreateOutput {
  final String fileId;
  final String masterKeyId;
  final String? encryptedFileName;

  const FileCreateOutput(this.fileId, this.masterKeyId, this.encryptedFileName);
}

class FilePrepareCreateOutput {
  final String serverInput;
  final String masterKeyId;
  final String? encryptedFileName;
  final SymKey key;

  FilePrepareCreateOutput({
    required this.serverInput,
    required this.masterKeyId,
    required this.encryptedFileName,
    required this.key,
  });
}

class Uploader {
  static bool cancelUpload = false;

  final String _baseUrl;
  final String _appToken;

  final User _user;

  final String? _groupId;
  final String? _otherUserId;

  final void Function(double progress)? uploadCallback;

  final String? _groupAsMember;
  int _chunkSize = 1024 * 1024 * 4;

  String? _belongsToId;
  String _belongsTo = "\"None\"";

  Uploader(
    this._baseUrl,
    this._appToken,
    this._user, [
    this._groupId,
    this._otherUserId,
    this.uploadCallback,
    this._groupAsMember,
    int chunkSize = 1024 * 1024 * 4,
  ]) {
    if (_groupId != null && _groupId != "") {
      _belongsToId = _groupId;
      _belongsTo = "\"Group\""; //the double "" are important for rust serde json
    } else if (_otherUserId != null && _otherUserId != "") {
      _belongsToId = _otherUserId;
      _belongsTo = "\"User\"";
    }

    _chunkSize = chunkSize;
  }

  Future<api_file.FilePrepareRegister> prepareFileRegister(
    File file,
    String contentKey,
    String encryptedContentKey,
    String masterKeyId,
  ) {
    return api_file.filePrepareRegisterFile(
      masterKeyId: masterKeyId,
      contentKey: contentKey,
      encryptedContentKey: encryptedContentKey,
      belongsToId: _belongsToId,
      belongsToType: _belongsTo,
      fileName: p.basename(file.path),
    );
  }

  Future<api_file.FileDoneRegister> doneFileRegister(String serverOutput) {
    return api_file.fileDoneRegisterFile(serverOutput: serverOutput);
  }

  Future<void> checkFileUpload(File file, String contentKey, String sessionId, [bool sign = false]) async {
    final jwt = await _user.getJwt();

    String? signKey;

    if (sign) {
      signKey = _user.getNewestSignKey();
    }

    int start = 0;
    int end = _chunkSize;

    final fileSize = await file.length();
    final totalChunks = (fileSize / _chunkSize).ceil();
    int currentChunk = 0;

    //reset it just in case it was true
    Uploader.cancelUpload = false;

    final urlPrefix = Sentc.filePartUrl;

    String nextFileKey = contentKey;

    while (start < fileSize) {
      currentChunk++;

      final part = await _readByteStream(file.openRead(start, end));

      start = end;
      end = start + _chunkSize;
      final isEnd = start >= fileSize;

      if (currentChunk == 1) {
        nextFileKey = await api_file.fileUploadPartStart(
          baseUrl: _baseUrl,
          urlPrefix: urlPrefix,
          authToken: _appToken,
          jwt: jwt,
          sessionId: sessionId,
          end: isEnd,
          sequence: currentChunk,
          contentKey: contentKey,
          signKey: signKey,
          part_: part,
        );
      } else {
        nextFileKey = await api_file.fileUploadPart(
          baseUrl: _baseUrl,
          urlPrefix: urlPrefix,
          authToken: _appToken,
          jwt: jwt,
          sessionId: sessionId,
          end: isEnd,
          sequence: currentChunk,
          contentKey: nextFileKey,
          signKey: signKey,
          part_: part,
        );
      }

      if (uploadCallback != null) {
        uploadCallback!(currentChunk / totalChunks);
      }

      if (cancelUpload) {
        cancelUpload = false;
        break;
      }
    }
  }

  Future<UploadResult> uploadFileWithPath(
    String path,
    String contentKey,
    String encryptedContentKey,
    String masterKeyId, [
    bool sign = false,
  ]) {
    final file = File(path);

    return uploadFile(file, contentKey, encryptedContentKey, masterKeyId, sign);
  }

  Future<UploadResult> uploadFile(
    File file,
    String contentKey,
    String encryptedContentKey,
    String masterKeyId, [
    bool sign = false,
  ]) async {
    final jwt = await _user.getJwt();

    final out = await api_file.fileRegisterFile(
      baseUrl: _baseUrl,
      authToken: _appToken,
      jwt: jwt,
      masterKeyId: masterKeyId,
      contentKey: contentKey,
      encryptedContentKey: encryptedContentKey,
      belongsToId: _belongsToId,
      belongsToType: _belongsTo,
      fileName: p.basename(file.path),
      groupId: _groupId,
      groupAsMember: _groupAsMember,
    );

    await checkFileUpload(file, contentKey, out.sessionId, sign);

    return UploadResult(fileId: out.fileId, encryptedFileName: out.encryptedFileName);
  }

  /// Create an uint8list from the stream chunk
  /// source: https://github.com/google/dart-neats/blob/84f6baae9fcbd51e616540916c391aa563a44db7/chunked_stream/lib/src/read_chunked_stream.dart#L84
  Future<Uint8List> _readByteStream(Stream<List<int>> input) async {
    final result = BytesBuilder();

    await for (final chunk in input) {
      result.add(chunk);
    }

    return result.takeBytes();
  }
}
