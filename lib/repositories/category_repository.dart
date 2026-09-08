import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/main_category.dart';
import '../models/sub_category.dart';
import '../core/constants/default_categories.dart';

abstract class CategoryRepository {
  Future<List<MainCategory>> getMainCategories(String roomId);
  Future<void> saveMainCategory(String roomId, MainCategory category);
  Future<void> deleteMainCategory(String roomId, String categoryId);
  Future<List<SubCategory>> getSubCategories(String roomId);
  Future<void> saveSubCategory(String roomId, SubCategory category);
  Future<void> deleteSubCategory(String roomId, String subCategoryId);
  Future<void> seedDefaultCategories(String roomId);
}

class FirestoreCategoryRepository implements CategoryRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreCategoryRepository(this._firestore, this._prefs) {
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

  CollectionReference _roomColl(String roomId, String sub) =>
      _firestore!.collection('couple_rooms').doc(roomId).collection(sub);

  @override
  Future<List<MainCategory>> getMainCategories(String roomId) async {
    if (_useLocalMock) return _getLocalMainCategories(roomId);
    try {
      final snapshot = await _roomColl(roomId, 'mainCategories').orderBy('order').get();
      if (snapshot.docs.isEmpty) {
        await seedDefaultCategories(roomId);
        return getMainCategories(roomId);
      }
      return snapshot.docs
          .map((doc) => MainCategory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return _getLocalMainCategories(roomId);
    }
  }

  @override
  Future<void> saveMainCategory(String roomId, MainCategory category) async {
    if (_useLocalMock) {
      await _saveLocalMainCategory(roomId, category);
      return;
    }
    try {
      await _roomColl(roomId, 'mainCategories')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalMainCategory(roomId, category);
    }
  }

  @override
  Future<void> deleteMainCategory(String roomId, String categoryId) async {
    if (_useLocalMock) {
      await _deleteLocalMainCategory(roomId, categoryId);
      return;
    }
    try {
      await _roomColl(roomId, 'mainCategories').doc(categoryId).delete();
      final subCats = await getSubCategories(roomId);
      for (var sub in subCats) {
        if (sub.mainCategoryId == categoryId) {
          await deleteSubCategory(roomId, sub.id);
        }
      }
    } catch (e) {
      await _deleteLocalMainCategory(roomId, categoryId);
    }
  }

  @override
  Future<List<SubCategory>> getSubCategories(String roomId) async {
    if (_useLocalMock) return _getLocalSubCategories(roomId);
    try {
      final snapshot = await _roomColl(roomId, 'subCategories').orderBy('order').get();
      return snapshot.docs
          .map((doc) => SubCategory.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return _getLocalSubCategories(roomId);
    }
  }

  @override
  Future<void> saveSubCategory(String roomId, SubCategory category) async {
    if (_useLocalMock) {
      await _saveLocalSubCategory(roomId, category);
      return;
    }
    try {
      await _roomColl(roomId, 'subCategories')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalSubCategory(roomId, category);
    }
  }

  @override
  Future<void> deleteSubCategory(String roomId, String subCategoryId) async {
    if (_useLocalMock) {
      await _deleteLocalSubCategory(roomId, subCategoryId);
      return;
    }
    try {
      await _roomColl(roomId, 'subCategories').doc(subCategoryId).delete();
    } catch (e) {
      await _deleteLocalSubCategory(roomId, subCategoryId);
    }
  }

  @override
  Future<void> seedDefaultCategories(String roomId) async {
    for (var defaultCat in DefaultCategoriesData.defaultList) {
      final mainCat = MainCategory(
        id: defaultCat.id,
        name: defaultCat.name,
        color: defaultCat.colorHex,
        emoji: defaultCat.emoji,
        order: defaultCat.order,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveMainCategory(roomId, mainCat);
      for (var defaultSub in defaultCat.subCategories) {
        final subCat = SubCategory(
          id: defaultSub.id,
          mainCategoryId: defaultCat.id,
          name: defaultSub.name,
          emoji: defaultSub.emoji,
          color: defaultCat.colorHex,
          order: defaultSub.order,
        );
        await saveSubCategory(roomId, subCat);
      }
    }
  }

  // --- Local Storage Helpers ---

  Future<List<MainCategory>> _getLocalMainCategories(String roomId) async {
    final key = 'local_main_categories_';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      await seedDefaultCategories(roomId);
      return _getLocalMainCategories(roomId);
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => MainCategory.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _saveLocalMainCategory(String roomId, MainCategory category) async {
    final key = 'local_main_categories_';
    final list = await _getLocalMainCategories(roomId);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index >= 0) { list[index] = category; } else { list.add(category); }
    await _prefs.setString(key, jsonEncode(list.map((c) => c.toMap()).toList()));
  }

  Future<void> _deleteLocalMainCategory(String roomId, String categoryId) async {
    final key = 'local_main_categories_';
    final list = await _getLocalMainCategories(roomId);
    list.removeWhere((c) => c.id == categoryId);
    await _prefs.setString(key, jsonEncode(list.map((c) => c.toMap()).toList()));
    final subCats = await _getLocalSubCategories(roomId);
    final updatedSubs = subCats.where((sub) => sub.mainCategoryId != categoryId).toList();
    await _prefs.setString('local_sub_categories_', jsonEncode(updatedSubs.map((c) => c.toMap()).toList()));
  }

  Future<List<SubCategory>> _getLocalSubCategories(String roomId) async {
    final key = 'local_sub_categories_';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => SubCategory.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _saveLocalSubCategory(String roomId, SubCategory category) async {
    final key = 'local_sub_categories_';
    final list = await _getLocalSubCategories(roomId);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index >= 0) { list[index] = category; } else { list.add(category); }
    await _prefs.setString(key, jsonEncode(list.map((c) => c.toMap()).toList()));
  }

  Future<void> _deleteLocalSubCategory(String roomId, String subCategoryId) async {
    final key = 'local_sub_categories_';
    final list = await _getLocalSubCategories(roomId);
    list.removeWhere((c) => c.id == subCategoryId);
    await _prefs.setString(key, jsonEncode(list.map((c) => c.toMap()).toList()));
  }
}
