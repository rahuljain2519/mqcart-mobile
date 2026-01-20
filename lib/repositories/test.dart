import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /* --------------------------------------------------
     AUTH STATE LISTENER
     -------------------------------------------------- */
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /* --------------------------------------------------
     SEND OTP (PHONE AUTH)
     -------------------------------------------------- */
  Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$phone',

      /// 🚫 DO NOT AUTO SIGN-IN
      /// This avoids double-login & random OTP failures
      verificationCompleted: (PhoneAuthCredential credential) {
        // Intentionally empty
      },

      verificationFailed: (FirebaseAuthException e) {
        final message = e.message ?? e.code;
        onError(message);
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      /// ⏱ Handle timeout properly
      codeAutoRetrievalTimeout: (String verificationId) {
        // Let UI request resend OTP
      },

      timeout: const Duration(seconds: 60),
    );
  }

  /* --------------------------------------------------
     VERIFY OTP
     -------------------------------------------------- */
  Future<User> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final result = await _auth.signInWithCredential(credential);

      if (result.user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Authentication failed. Please try again.',
        );
      }

      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw e; // IMPORTANT: rethrow for UI to handle
    }
  }

  /* --------------------------------------------------
     SIGN OUT
     -------------------------------------------------- */
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
