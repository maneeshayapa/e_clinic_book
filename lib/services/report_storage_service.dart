import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ReportStorageService {
  Future<String> uploadReportFile({
    required String patientId,
    required String reportId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  });

  Future<Uint8List> downloadReportFile(String storagePath);

  Future<void> deleteReportFile(String storagePath);
}

class UnavailableReportStorageService implements ReportStorageService {
  UnavailableReportStorageService(this.message);

  final String message;

  StateError _configurationError() => StateError(message);

  @override
  Future<String> uploadReportFile({
    required String patientId,
    required String reportId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    throw _configurationError();
  }

  @override
  Future<Uint8List> downloadReportFile(String storagePath) async {
    throw _configurationError();
  }

  @override
  Future<void> deleteReportFile(String storagePath) async {
    throw _configurationError();
  }
}

class SupabaseReportStorageService implements ReportStorageService {
  SupabaseReportStorageService(this._client);

  static const bucketName = 'lab-reports';

  final SupabaseClient _client;

  static const _contentTypes = {
    'application/pdf',
    'image/jpeg',
    'image/png',
  };

  @override
  Future<String> uploadReportFile({
    required String patientId,
    required String reportId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    if (fileBytes.isEmpty) {
      throw ArgumentError.value(fileBytes, 'fileBytes', 'File is empty.');
    }
    if (!_contentTypes.contains(contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'Only PDF, JPG, JPEG, and PNG files are supported.',
      );
    }

    final safeFileName = fileName.replaceAll(RegExp(r'[/\\]'), '_');
    if (safeFileName.isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'File name is empty.');
    }

    final storagePath = '$patientId/$reportId/$safeFileName';
    await _client.storage.from(bucketName).uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return storagePath;
  }

  @override
  Future<Uint8List> downloadReportFile(String storagePath) =>
      _client.storage.from(bucketName).download(storagePath);

  @override
  Future<void> deleteReportFile(String storagePath) async {
    await _client.storage.from(bucketName).remove([storagePath]);
  }
}

class MockReportStorageService implements ReportStorageService {
  final Map<String, Uint8List> _files = {};

  @override
  Future<String> uploadReportFile({
    required String patientId,
    required String reportId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[/\\]'), '_');
    final path = '$patientId/$reportId/$safeFileName';
    _files[path] = Uint8List.fromList(fileBytes);
    return path;
  }

  @override
  Future<Uint8List> downloadReportFile(String storagePath) async {
    final bytes = _files[storagePath];
    if (bytes == null) throw StateError('Mock report file was not found.');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> deleteReportFile(String storagePath) async {
    _files.remove(storagePath);
  }
}
