import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthRepository {
  Stream<String?> get authStateChanges;
  String? get currentUserId;
  Future<String?> signInWithEmailAndPassword(String email, String password);
  Future<String?> signUpWithEmailAndPassword(String email, String password);
  Future<String?> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth? _firebaseAuth;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;
  late final StreamController<String?> _mockAuthStreamController;

  FirebaseAuthRepository(this._firebaseAuth, this._prefs) {
    if (_firebaseAuth == null) {
      _useLocalMock = true;
    } else {
      try {
        _firebaseAuth.app;
      } catch (_) {
        _useLocalMock = true;
      }
    }

    if (_useLocalMock) {
      _mockAuthStreamController = StreamController<String?>.broadcast();
      scheduleMicrotask(() {
        if (!_mockAuthStreamController.isClosed) {
          _mockAuthStreamController.add(_prefs.getString('mock_userId'));
        }
      });
    }
  }

  @override
  Stream<String?> get authStateChanges {
    if (_useLocalMock) return _mockAuthStreamController.stream;
    return _firebaseAuth!.authStateChanges().map((user) => user?.uid);
  }

  @override
  String? get currentUserId {
    if (_useLocalMock) return _prefs.getString('mock_userId');
    return _firebaseAuth!.currentUser?.uid;
  }

  @override
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    if (_useLocalMock) {
      if (email.contains('@') && password.length >= 6) {
        final mockId = 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        await _prefs.setString('mock_userId', mockId);
        _mockAuthStreamController.add(mockId);
        return mockId;
      }
      throw Exception('อีเมลหรือรหัสผ่านไม่ถูกต้อง (ขั้นต่ำ 6 ตัวอักษร)');
    }
    try {
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  @override
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    if (_useLocalMock) {
      if (email.contains('@') && password.length >= 6) {
        final mockId = 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        await _prefs.setString('mock_userId', mockId);
        _mockAuthStreamController.add(mockId);
        return mockId;
      }
      throw Exception('สมัครสมาชิกไม่สำเร็จ: อีเมลไม่ถูกต้องหรือรหัสผ่านสั้นเกินไป');
    }
    try {
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    if (_useLocalMock) {
      const mockId = 'mock_google_user';
      await _prefs.setString('mock_userId', mockId);
      _mockAuthStreamController.add(mockId);
      return mockId;
    }
    try {
      if (kIsWeb) {
        // Use Firebase Auth popup for web
        final provider = fb.GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        final result = await _firebaseAuth!.signInWithPopup(provider);
        return result.user?.uid;
      } else {
        // Mobile: use google_sign_in package (for future APK)
        throw Exception('Google Sign-In บนมือถือจะรองรับใน Phase 4 (APK)');
      }
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('popup-closed-by-user') || msg.contains('cancelled')) {
        throw Exception('ยกเลิกการเข้าสู่ระบบด้วย Google');
      }
      throw Exception('Google Sign-In ล้มเหลว: $msg');
    }
  }

  @override
  Future<void> signOut() async {
    if (_useLocalMock) {
      await _prefs.remove('mock_userId');
      _mockAuthStreamController.add(null);
      return;
    }
    await _firebaseAuth!.signOut();
  }

  String _translateFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'ไม่พบบัญชีผู้ใช้นี้ในระบบ';
      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง';
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้งานแล้วในระบบ';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'weak-password':
        return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
      case 'operation-not-allowed':
        return 'การเข้าสู่ระบบประเภทนี้ยังไม่เปิดใช้งาน';
      case 'unauthorized-domain':
        return 'โดเมนนี้ยังไม่ได้รับอนุญาตใน Firebase Console (กรุณาเพิ่ม Authorized Domain)';
      case 'account-exists-with-different-credential':
        return 'มีบัญชีนี้อยู่แล้วด้วยวิธีล็อกอินอื่น';
      default:
        return 'เกิดข้อผิดพลาดเกี่ยวกับระบบสมาชิก ($code)';
    }
  }
}
