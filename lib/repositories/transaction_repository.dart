import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions(String roomId);
  Stream<List<TransactionItem>> watchTransactions(String roomId);
  Future<void> saveTransaction(String roomId, TransactionItem transaction);
  Future<void> deleteTransaction(String roomId, String transactionId);
  Future<void> updateCreatorNameForUser(String roomId, String userId, String newName);
}

class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;
  StreamController<List<TransactionItem>>? _localTransactionsController;

  FirestoreTransactionRepository(this._firestore, this._prefs) {
    if (_firestore == null) {
      _useLocalMock = true;
    } else {
      try {
        _firestore.app;
      } catch (_) {
        _useLocalMock = true;
      }
    }
  }

  @override
  Future<List<TransactionItem>> getTransactions(String roomId) async {
    if (_useLocalMock) {
      return _getLocalTransactions(roomId);
    }
    try {
      final snapshot = await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionItem.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalTransactions(roomId);
    }
  }

  @override
  Stream<List<TransactionItem>> watchTransactions(String roomId) {
    if (_useLocalMock) {
      _localTransactionsController ??= StreamController<List<TransactionItem>>.broadcast(
        onListen: () async {
          final initial = await _getLocalTransactions(roomId);
          if (_localTransactionsController != null && !_localTransactionsController!.isClosed) {
            _localTransactionsController!.add(initial);
          }
        },
      );
      return _localTransactionsController!.stream;
    }
    return _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionItem.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> saveTransaction(String roomId, TransactionItem transaction) async {
    if (_useLocalMock) {
      await _saveLocalTransaction(roomId, transaction);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalTransaction(roomId, transaction);
    }
  }

  @override
  Future<void> deleteTransaction(String roomId, String transactionId) async {
    if (_useLocalMock) {
      await _deleteLocalTransaction(roomId, transactionId);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      await _deleteLocalTransaction(roomId, transactionId);
    }
  }

  @override
  Future<void> updateCreatorNameForUser(String roomId, String userId, String newName) async {
    if (_useLocalMock) {
      final list = await _getLocalTransactions(roomId);
      bool changed = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].createdByUserId == userId) {
          list[i] = list[i].copyWith(createdByName: newName);
          changed = true;
        }
      }
      if (changed) {
        final key = 'local_transactions_';
        final encoded = jsonEncode(list.map((t) => t.toLocalMap()).toList());
        await _prefs.setString(key, encoded);
      }
      return;
    }
    try {
      final snap = await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .where('createdByUserId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'createdByName': newName});
      }
      await batch.commit();
    } catch (e) {
      // Fallback
    }
  }

  // --- Local Storage Helpers ---

  Future<List<TransactionItem>> _getLocalTransactions(String roomId) async {
    final key = 'local_transactions_';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => TransactionItem.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveLocalTransaction(String roomId, TransactionItem transaction) async {
    final key = 'local_transactions_';
    final list = await _getLocalTransactions(roomId);
    final index = list.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      list[index] = transaction;
    } else {
      list.add(transaction);
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    final encoded = jsonEncode(list.map((t) => t.toLocalMap()).toList());
    await _prefs.setString(key, encoded);
    if (_localTransactionsController != null && !_localTransactionsController!.isClosed) {
      _localTransactionsController!.add(list);
    }
  }

  Future<void> _deleteLocalTransaction(String roomId, String transactionId) async {
    final key = 'local_transactions_';
    final list = await _getLocalTransactions(roomId);
    list.removeWhere((t) => t.id == transactionId);
    final encoded = jsonEncode(list.map((t) => t.toLocalMap()).toList());
    await _prefs.setString(key, encoded);
    if (_localTransactionsController != null && !_localTransactionsController!.isClosed) {
      _localTransactionsController!.add(list);
    }
  }
}
