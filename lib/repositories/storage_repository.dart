import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as s;
import 'package:path_provider/path_provider.dart';

abstract class StorageRepository {
  Future<String> uploadReceiptImage(String userId, String transactionId, File file);
}

class FirebaseStorageRepository implements StorageRepository {
  final s.FirebaseStorage? _storage;
  bool _useLocalMock = false;

  FirebaseStorageRepository(this._storage) {
    if (_storage == null) {
      _useLocalMock = true;
    } else {
      try {
        _storage.app;
      } catch (_) {
        _useLocalMock = true;
      }
    }
  }

  @override
  Future<String> uploadReceiptImage(String userId, String transactionId, File file) async {
    if (_useLocalMock) {
      return _saveLocalMockImage(transactionId, file);
    }
    try {
      final ref = _storage!.ref().child('users/$userId/receipts/$transactionId.jpg');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      // If Firebase upload fails, save to local app document directory and return file path scheme
      return _saveLocalMockImage(transactionId, file);
    }
  }

  Future<String> _saveLocalMockImage(String transactionId, File file) async {
    try {
      // Copy file to App Documents directory for persistence
      final appDocDir = await getApplicationDocumentsDirectory();
      final destinationPath = '${appDocDir.path}/receipt_$transactionId.jpg';
      final persistentFile = await file.copy(destinationPath);
      
      // Return file path format so Image.file() can display it directly
      return persistentFile.path;
    } catch (_) {
      // Fallback: Convert to Data URI base64 if directory copy fails
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    }
  }
}
