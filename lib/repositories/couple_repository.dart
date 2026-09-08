import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/couple_room.dart';

class CoupleRepository {
  final FirebaseFirestore? _firestore;

  CoupleRepository(this._firestore);

  bool get _isAvailable => _firestore != null;

  /// Generate a random 6-character uppercase invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No ambiguous chars
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Create a new couple room and return it
  Future<CoupleRoom> createCoupleRoom(
    String createdBy, {
    String? nickname,
    String? email,
    String? photoBase64,
  }) async {
    if (!_isAvailable) throw Exception('Firebase ไม่พร้อมใช้งาน');

    final code = _generateInviteCode();
    final roomRef = _firestore!.collection('couple_rooms').doc();

    final Map<String, Map<String, dynamic>> initialMembers = {};
    if (nickname != null || email != null) {
      initialMembers[createdBy] = {
        'nickname': nickname ?? '',
        'email': email ?? '',
        if (photoBase64 != null) 'photoBase64': photoBase64,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
    }

    final room = CoupleRoom(
      id: roomRef.id,
      inviteCode: code,
      memberIds: [createdBy],
      createdBy: createdBy,
      createdAt: DateTime.now(),
      membersInfo: initialMembers,
    );

    final batch = _firestore.batch();

    // Create room document
    batch.set(roomRef, room.toMap());

    // Store invite code → roomId mapping for fast lookup
    batch.set(
      _firestore.collection('invite_codes').doc(code),
      {
        'roomId': room.id,
        'createdBy': createdBy,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    try {
      await batch.commit();
      return room;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'สิทธิ์การใช้งานถูกปฏิเสธ: กรุณาตั้งค่า Firestore Rules ใน Firebase Console ตามขั้นตอนที่แจ้งไว้ครับ');
      }
      throw Exception('ไม่สามารถสร้างห้องได้ (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('ไม่สามารถสร้างห้องได้: ${e.toString()}');
    }
  }

  /// Join an existing couple room via invite code
  Future<CoupleRoom> joinCoupleRoom(
    String inviteCode,
    String userId, {
    String? nickname,
    String? email,
    String? photoBase64,
  }) async {
    if (!_isAvailable) throw Exception('Firebase ไม่พร้อมใช้งาน');

    try {
      final db = _firestore!;
      // Look up invite code
      final codeDoc = await db
          .collection('invite_codes')
          .doc(inviteCode.toUpperCase())
          .get();

      if (!codeDoc.exists) throw Exception('ไม่พบโค้ดนี้ในระบบ กรุณาตรวจสอบอีกครั้ง');

      final roomId = codeDoc.data()!['roomId'] as String;

      // Get the room
      final roomDoc = await db.collection('couple_rooms').doc(roomId).get();
      if (!roomDoc.exists) throw Exception('ไม่พบห้องคู่รัก กรุณาติดต่อผู้สร้างห้อง');

      final room = CoupleRoom.fromMap(roomDoc.data()!, roomDoc.id);

      if (room.isFull && !room.memberIds.contains(userId)) {
        throw Exception('ห้องนี้มีสมาชิกครบแล้ว (2 คน)');
      }

      final Map<String, dynamic> updateData = {};
      if (!room.memberIds.contains(userId)) {
        updateData['memberIds'] = FieldValue.arrayUnion([userId]);
      }
      if (nickname != null || email != null) {
        updateData['membersInfo.$userId'] = {
          'nickname': nickname ?? '',
          'email': email ?? '',
          if (photoBase64 != null) 'photoBase64': photoBase64,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
      }

      if (updateData.isNotEmpty) {
        await db.collection('couple_rooms').doc(roomId).update(updateData);
      }

      // Delete invite code after joining (one-time use)
      await db.collection('invite_codes').doc(inviteCode.toUpperCase()).delete();

      // Return updated room
      final updatedDoc = await db.collection('couple_rooms').doc(roomId).get();
      return CoupleRoom.fromMap(updatedDoc.data()!, updatedDoc.id);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'สิทธิ์การใช้งานถูกปฏิเสธ: กรุณาตั้งค่า Firestore Rules ใน Firebase Console ตามขั้นตอนที่แจ้งไว้ครับ');
      }
      throw Exception('ไม่สามารถเข้าร่วมห้องได้ (${e.code}): ${e.message}');
    }
  }

  /// Sync member profile (nickname, email, photo) directly into couple_rooms document
  Future<void> syncMemberInfo(
    String roomId,
    String userId, {
    required String nickname,
    required String email,
    String? photoBase64,
  }) async {
    if (!_isAvailable) return;
    try {
      final Map<String, dynamic> data = {
        'nickname': nickname,
        'email': email,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        data['photoBase64'] = photoBase64;
      }

      await _firestore!.collection('couple_rooms').doc(roomId).set({
        'membersInfo': {
          userId: data,
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Stream of couple room (real-time updates)
  Stream<CoupleRoom?> watchCoupleRoom(String roomId) {
    if (!_isAvailable) return Stream.value(null);
    return _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CoupleRoom.fromMap(snap.data()!, snap.id);
    });
  }

  /// Add custom food item to room
  Future<void> addCustomFoodToRoom(String roomId, Map<String, String> foodItem) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customFoodMenu': FieldValue.arrayUnion([foodItem]),
    }, SetOptions(merge: true));
  }

  /// Remove custom food item from room
  Future<void> removeCustomFoodFromRoom(String roomId, Map<String, String> foodItem) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customFoodMenu': FieldValue.arrayRemove([foodItem]),
    }, SetOptions(merge: true));
  }

  /// Update custom food menu array in room
  Future<void> updateCustomFoodMenu(String roomId, List<Map<String, String>> foodMenu) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customFoodMenu': foodMenu,
    }, SetOptions(merge: true));
  }

  /// Add custom quest item to room
  Future<void> addCustomQuestToRoom(String roomId, Map<String, String> questItem) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customQuests': FieldValue.arrayUnion([questItem]),
    }, SetOptions(merge: true));
  }

  /// Remove custom quest item from room
  Future<void> removeCustomQuestFromRoom(String roomId, Map<String, String> questItem) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customQuests': FieldValue.arrayRemove([questItem]),
    }, SetOptions(merge: true));
  }

  /// Update custom quests array in room
  Future<void> updateCustomQuests(String roomId, List<Map<String, String>> quests) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'customQuests': quests,
    }, SetOptions(merge: true));
  }

  /// Set or update budget and optional recurring due day for a specific subcategory
  Future<void> setSubcategoryBudget(String roomId, String subCatId, double amount, {int? dueDay}) async {
    if (!_isAvailable) return;
    final Map<String, dynamic> updateData = {
      'subcategoryBudgets.$subCatId': amount,
    };
    if (dueDay != null && dueDay >= 1 && dueDay <= 31) {
      updateData['recurringBillDueDays.$subCatId'] = dueDay;
    }
    await _firestore!.collection('couple_rooms').doc(roomId).set(updateData, SetOptions(merge: true));
  }

  /// Remove budget tracking and recurring due day for a specific subcategory
  Future<void> removeSubcategoryBudget(String roomId, String subCatId) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).update({
      'subcategoryBudgets.$subCatId': FieldValue.delete(),
      'recurringBillDueDays.$subCatId': FieldValue.delete(),
    });
  }

  /// Add a default food to deleted blacklist
  Future<void> addDeletedDefaultFood(String roomId, String foodName) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'deletedDefaultFood': FieldValue.arrayUnion([foodName]),
    }, SetOptions(merge: true));
  }

  /// Add a default quest to deleted blacklist
  Future<void> addDeletedDefaultQuest(String roomId, String questTitle) async {
    if (!_isAvailable) return;
    await _firestore!.collection('couple_rooms').doc(roomId).set({
      'deletedDefaultQuests': FieldValue.arrayUnion([questTitle]),
    }, SetOptions(merge: true));
  }

}
