import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'mock_data.dart';

abstract class AuthService {
  Future<AppUser?> currentUser();
  Future<AppUser> login(String email, String password, {UserRole? role});
  Future<AppUser> register(
      {required String name,
      required String email,
      required String password,
      required UserRole role});
  Future<void> resetPassword(String email);
  Future<void> logout();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<AppUser?> currentUser() async {
    final user = await _auth.authStateChanges().first;
    return user == null ? null : _loadProfile(user);
  }

  @override
  Future<AppUser> login(String email, String password, {UserRole? role}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase sign-in completed without a user.');
      }

      final profile = await _loadProfile(user);
      if (role != null && profile.role != role) {
        await _auth.signOut();
        throw StateError('This account does not have the selected role.');
      }
      return profile;
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (role != UserRole.patient) {
      throw StateError(
        'Doctor accounts must be created or approved by an administrator.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase account creation completed without a user.');
      }

      final normalizedName = name.trim();
      await user.updateDisplayName(normalizedName);
      await _users.doc(user.uid).set({
        'name': normalizedName,
        'email': user.email,
        'role': role.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AppUser(
        id: user.uid,
        name: normalizedName,
        email: user.email ?? email.trim(),
        role: role,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  Future<AppUser> _loadProfile(User user) async {
    final snapshot = await _users.doc(user.uid).get();
    final profile = snapshot.data();
    if (profile == null) {
      throw StateError(
        'No user profile was found for this account. Contact support.',
      );
    }

    final roleName = profile['role'];
    final role = switch (roleName) {
      'patient' => UserRole.patient,
      'doctor' => UserRole.doctor,
      _ => throw StateError('The account has an invalid user role.'),
    };
    final profileName = profile['name'];

    return AppUser(
      id: user.uid,
      name: profileName is String && profileName.isNotEmpty
          ? profileName
          : user.displayName ?? '',
      email: user.email ?? '',
      role: role,
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Choose a stronger password.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'The email or password is incorrect.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => error.message ?? 'Authentication failed (${error.code}).',
    };
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw Exception(_authErrorMessage(error));
    }
  }

  @override
  Future<void> logout() => _auth.signOut();
}

/// Mock: any valid email/password signs in. Emails starting with "dr" (or the
/// chosen role) become doctors; everyone else is the demo patient.
class MockAuthService implements AuthService {
  final Map<String, AppUser> _registered = {};
  int _counter = 1100;
  AppUser? _currentUser;

  @override
  Future<AppUser?> currentUser() async => _currentUser;

  @override
  Future<AppUser> login(String email, String password, {UserRole? role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final key = email.trim().toLowerCase();
    if (_registered.containsKey(key)) {
      return _currentUser = _registered[key]!;
    }
    final asDoctor =
        role == UserRole.doctor || (role == null && key.startsWith('dr'));
    if (asDoctor) {
      final d = MockData.doctors.first;
      return _currentUser =
          AppUser(id: d.id, name: d.name, email: key, role: UserRole.doctor);
    }
    final p = MockData.patients().first;
    return _currentUser =
        AppUser(id: p.id, name: p.name, email: key, role: UserRole.patient);
  }

  @override
  Future<AppUser> register(
      {required String name,
      required String email,
      required String password,
      required UserRole role}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final key = email.trim().toLowerCase();
    if (_registered.containsKey(key)) {
      throw Exception('An account with this email already exists');
    }
    final prefix = role == UserRole.patient ? 'P' : 'D';
    final user = AppUser(
        id: '$prefix-${_counter++}', name: name, email: key, role: role);
    _registered[key] = user;
    return _currentUser = user;
  }

  @override
  Future<void> resetPassword(String email) =>
      Future<void>.delayed(const Duration(milliseconds: 600));

  @override
  Future<void> logout() async {
    _currentUser = null;
  }
}
