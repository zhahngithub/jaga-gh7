import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_session.dart';

class AuthRepository {
  const AuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Stream<AuthSession?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_toSession);
  }

  Future<AuthSession> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireSession(credential.user);
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireSession(credential.user);
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    await user.updateDisplayName(displayName);
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> deleteCurrentUser() async {
    await _firebaseAuth.currentUser?.delete();
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  AuthSession _requireSession(User? user) {
    final session = _toSession(user);
    if (session == null) {
      throw StateError('Firebase did not return an authenticated user.');
    }
    return session;
  }

  AuthSession? _toSession(User? user) {
    if (user == null) {
      return null;
    }
    return AuthSession(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }
}
