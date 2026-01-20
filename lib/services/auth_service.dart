import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Listen to auth state (login / logout)
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// Currently logged-in user
  User? get currentUser => _auth.currentUser;

  /// Temporary anonymous sign-in (we’ll replace later with proper login)
  Future<User?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    return result.user;
  }

  /// Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
