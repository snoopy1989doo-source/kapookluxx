import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../core/constants/default_categories.dart';

abstract class WalletRepository {
  Future<List<Wallet>> getWallets(String roomId);
  Future<void> saveWallet(String roomId, Wallet wallet);
  Future<void> deleteWallet(String roomId, String walletId);
  Future<void> seedDefaultWallets(String roomId);
}

class FirestoreWalletRepository implements WalletRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreWalletRepository(this._firestore, this._prefs) {
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
  Future<List<Wallet>> getWallets(String roomId) async {
    if (_useLocalMock) {
      return _getLocalWallets(roomId);
    }
    try {
      final snapshot = await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('wallets')
          .orderBy('createdAt')
          .get();

      if (snapshot.docs.isEmpty) {
        await seedDefaultWallets(roomId);
        return getWallets(roomId);
      }

      return snapshot.docs
          .map((doc) => Wallet.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalWallets(roomId);
    }
  }

  @override
  Future<void> saveWallet(String roomId, Wallet wallet) async {
    if (_useLocalMock) {
      await _saveLocalWallet(roomId, wallet);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('wallets')
          .doc(wallet.id)
          .set(wallet.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalWallet(roomId, wallet);
    }
  }

  @override
  Future<void> deleteWallet(String roomId, String walletId) async {
    if (_useLocalMock) {
      await _deleteLocalWallet(roomId, walletId);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('wallets')
          .doc(walletId)
          .delete();
    } catch (e) {
      await _deleteLocalWallet(roomId, walletId);
    }
  }

  @override
  Future<void> seedDefaultWallets(String roomId) async {
    int currentOrder = 0;
    for (var wData in DefaultCategoriesData.defaultWallets) {
      final wallet = Wallet(
        id: wData['id'],
        name: wData['name'],
        color: wData['color'],
        icon: wData['icon'],
        startingBalance: wData['startingBalance'],
        currentBalance: wData['startingBalance'],
        order: currentOrder++,
        createdAt: DateTime.now(),
      );
      await saveWallet(roomId, wallet);
    }
  }

  // --- Local Storage Helpers ---

  Future<List<Wallet>> _getLocalWallets(String roomId) async {
    final key = 'local_wallets_';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      await seedDefaultWallets(roomId);
      return _getLocalWallets(roomId);
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => Wallet.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) {
        final cmp = a.order.compareTo(b.order);
        if (cmp != 0) return cmp;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  Future<void> _saveLocalWallet(String roomId, Wallet wallet) async {
    final key = 'local_wallets_';
    final list = await _getLocalWallets(roomId);
    final index = list.indexWhere((w) => w.id == wallet.id);
    if (index >= 0) {
      list[index] = wallet;
    } else {
      list.add(wallet);
    }
    final encoded = jsonEncode(list.map((w) => w.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalWallet(String roomId, String walletId) async {
    final key = 'local_wallets_';
    final list = await _getLocalWallets(roomId);
    list.removeWhere((w) => w.id == walletId);
    final encoded = jsonEncode(list.map((w) => w.toMap()).toList());
    await _prefs.setString(key, encoded);
  }
}
