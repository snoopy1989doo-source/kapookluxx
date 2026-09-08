import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../models/user_profile.dart';

// ─── Firebase Providers ─────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<fb.FirebaseAuth?>((ref) {
  try {
    return Firebase.apps.isNotEmpty ? fb.FirebaseAuth.instance : null;
  } catch (_) {
    return null;
  }
});

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
  } catch (_) {
    return null;
  }
});

// ─── Repository Providers ────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirebaseAuthRepository(firebaseAuth, prefs);
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return UserProfileRepository(firestore);
});

// ─── Auth State ───────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<String?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

// ─── User Profile ─────────────────────────────────────────────────────────────

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  if (userId == null) return Stream.value(null);

  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.watchUserProfile(userId);
});

// ─── Auth Notifier ────────────────────────────────────────────────────────────

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(userProfileRepositoryProvider);
  return AuthNotifier(repository, profileRepo);
});

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  AuthState({required this.status, this.userId, this.errorMessage});

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(String uid) =>
      AuthState(status: AuthStatus.authenticated, userId: uid);
  factory AuthState.unauthenticated() =>
      AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String msg) =>
      AuthState(status: AuthStatus.error, errorMessage: msg);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final UserProfileRepository _profileRepo;

  AuthNotifier(this._repository, this._profileRepo) : super(AuthState.initial()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen((userId) {
      if (userId != null) {
        state = AuthState.authenticated(userId);
      } else {
        state = AuthState.unauthenticated();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      final uid = await _repository.signInWithEmailAndPassword(email, password);
      if (uid != null) {
        // Ensure user profile document exists with email and nickname
        final existing = await _profileRepo.getUserProfile(uid);
        if (existing == null) {
          final profile = UserProfile(
            id: uid,
            email: email,
            nickname: email.split('@').first,
            photoBase64: null,
            coupleRoomId: null,
            createdAt: DateTime.now(),
          );
          await _profileRepo.saveProfile(profile);
        } else if (existing.email.isEmpty) {
          await _profileRepo.saveProfile(existing.copyWith(email: email));
        }
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถเข้าสู่ระบบได้');
      }
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Sign up + create user profile with nickname and optional photo
  Future<void> signUp(
    String email,
    String password, {
    required String nickname,
    String? photoBase64,
  }) async {
    state = AuthState.loading();
    try {
      final uid = await _repository.signUpWithEmailAndPassword(email, password);
      if (uid != null) {
        // Create user profile in Firestore
        final profile = UserProfile(
          id: uid,
          email: email,
          nickname: nickname,
          photoBase64: photoBase64,
          coupleRoomId: null,
          createdAt: DateTime.now(),
        );
        await _profileRepo.saveProfile(profile);
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถสมัครสมาชิกได้');
      }
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Google Sign-In — creates profile if first time and enriches missing fields
  Future<void> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final uid = await _repository.signInWithGoogle();
      if (uid != null) {
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        final existing = await _profileRepo.getUserProfile(uid);
        if (existing == null) {
          final profile = UserProfile(
            id: uid,
            email: fbUser?.email ?? '',
            nickname: fbUser?.displayName ?? fbUser?.email?.split('@').first ?? 'ผู้ใช้',
            photoBase64: fbUser?.photoURL, // Google photo URL
            coupleRoomId: null,
            createdAt: DateTime.now(),
          );
          await _profileRepo.saveProfile(profile);
        } else {
          // If profile exists, ensure email, photo, or name are kept up to date
          bool needsUpdate = false;
          String email = existing.email;
          String? photo = existing.photoBase64;
          String nickname = existing.nickname;

          if (email.isEmpty && fbUser?.email != null) {
            email = fbUser!.email!;
            needsUpdate = true;
          }
          if ((photo == null || photo.isEmpty) && fbUser?.photoURL != null) {
            photo = fbUser!.photoURL;
            needsUpdate = true;
          }
          if (nickname.isEmpty && fbUser?.displayName != null) {
            nickname = fbUser!.displayName!;
            needsUpdate = true;
          }
          if (needsUpdate) {
            await _profileRepo.saveProfile(existing.copyWith(
              email: email,
              photoBase64: photo,
              nickname: nickname,
            ));
          }
        }
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถเข้าสู่ระบบด้วย Google ได้');
      }
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();
    await _repository.signOut();
    state = AuthState.unauthenticated();
  }
}
