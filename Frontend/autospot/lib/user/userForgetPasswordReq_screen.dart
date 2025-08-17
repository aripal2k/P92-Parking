import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ForgetPasswordRequestScreen extends StatefulWidget {
  final Map<String, String>? userData;
  const ForgetPasswordRequestScreen({super.key, this.userData});

  @override
  State<ForgetPasswordRequestScreen> createState() => _ForgetPasswordRequestScreenState();
}

class _ForgetPasswordRequestScreenState extends State<ForgetPasswordRequestScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  String _errorMessage = '';
  bool _isCooldown = false;
  int _secondsRemaining = 0;
  Timer? _cooldownTimer;
  bool _isSending = false;
  bool _emailModified = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {
        _emailModified = true;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _isCooldown = true;
      _secondsRemaining = 60;
      _emailModified = false;
    });

    // Starts the cooldown timer for resending OTP
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _isCooldown = false;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  // Sends OTP to the entered email
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email');
      return;
    }

    if (_isSending) return;

    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        setState(() => _errorMessage = 'OTP sent to your email.');
        _startCooldown();
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error sending OTP.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  // Verifies OTP and continues to reset password screen
  void _continueToReset() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || otp.isEmpty) {
      setState(() {
        _errorMessage = 'Email and OTP are required.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyResetOtpEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamed(context, '/reset-password', arguments: {
          'email': email,
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Invalid OTP');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to verify OTP');
    }
  }

  // Consistent styling for input fields
  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.green, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: const Text(
                'Forget Password',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: const [
                            Icon(Icons.lock_outline, size: 80, color: Colors.black),
                            SizedBox(height: 12),
                            Text(
                              'Enter your email and we will send you an\nOTP Code for verification to reset your password.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        decoration: _inputStyle('Email'),
                        style: const TextStyle(color: Colors.black, fontSize: 20),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otpController,
                              focusNode: _otpFocus,
                              decoration: _inputStyle('OTP Code'),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.black, fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: (_isCooldown || !_emailModified || _isSending) ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_isCooldown || !_emailModified || _isSending)
                                  ? Colors.grey[300]
                                  : const Color(0xFFA3DB94),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _isCooldown
                                  ? 'Send Code ($_secondsRemaining)'
                                  : _isSending
                                      ? 'Sending...'
                                      : 'Send Code',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: _errorMessage.contains('OTP sent')
                                  ? Colors.green[800]
                                  : Colors.red,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: const Text('Back', style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _continueToReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA3DB94),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Continue', style: TextStyle(color: Colors.black, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
