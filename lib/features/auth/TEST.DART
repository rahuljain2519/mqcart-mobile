import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/auth_repository.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone; // REQUIRED for resend

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  bool _loading = false;
  bool _resendEnabled = false;

  late String _verificationId;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  /* --------------------------------------------------
     RESEND TIMER
     -------------------------------------------------- */
  void _startResendTimer() {
    _resendEnabled = false;
    _resendSeconds = 30;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds == 0) {
        setState(() => _resendEnabled = true);
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  /* --------------------------------------------------
     RESEND OTP
     -------------------------------------------------- */
  Future<void> _resendOtp() async {
    _startResendTimer();

    try {
      await _authRepository.sendOtp(
        phone: widget.phone,
        onCodeSent: (verificationId) {
          _verificationId = verificationId;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully')),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        },
      );
    } catch (e) {
      debugPrint('RESEND OTP ERROR: $e');
    }
  }

  /* --------------------------------------------------
     VERIFY OTP
     -------------------------------------------------- */
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _authRepository.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
      );

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'phone': user.phoneNumber,
          'role': 'buyer',
          'profileCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('OTP ERROR: $e');

      String message = 'OTP verification failed';

      final error = e.toString();
      if (error.contains('invalid-verification-code')) {
        message = 'Invalid OTP entered';
      } else if (error.contains('session-expired')) {
        message = 'OTP expired. Please resend OTP';
      } else if (error.contains('too-many-requests')) {
        message = 'Too many attempts. Try again later';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
              const Text('Enter the 6-digit code sent to your phone'),

              const SizedBox(height: 40),

              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              /// 🔁 RESEND OTP
              Center(
                child: TextButton(
                  onPressed: _resendEnabled ? _resendOtp : null,
                  child: Text(
                    _resendEnabled
                        ? 'Resend OTP'
                        : 'Resend OTP in $_resendSeconds s',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      (_loading || _otpController.text.length != 6)
                          ? null
                          : _verifyOtp,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Verify & Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
