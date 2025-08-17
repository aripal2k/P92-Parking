import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class VerifyOtpScreen extends StatefulWidget {
  final Map<String, String> userData;
  const VerifyOtpScreen({super.key, required this.userData});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  late final TextEditingController _emailController;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  String _errorMessage = '';
  String _infoMessage = '';
  bool _isCooldown = false;
  int _secondsRemaining = 0;
  bool _isSending = false;
  bool _emailModified = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _emailController.addListener(() {
      setState(() {
        _emailModified = true;
      });
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final username = widget.userData['username']?.trim() ?? '';
    final fullname = widget.userData['fullname']?.trim() ?? '';
    final password = widget.userData['password'] ?? '';
    final confirmPassword = widget.userData['confirm_password'] ?? '';

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email.';
        _infoMessage = '';
      });
      return;
    }

    if (username.isEmpty || fullname.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required.';
        _infoMessage = '';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _infoMessage = '';
      });
      return;
    }

    if (_isSending) return;

    setState(() {
      _isSending = true;
      _errorMessage = '';
      _infoMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerRequestEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "email": email,
          "username": username,
          "fullname": fullname,
          "password": password,
          "confirm_password": confirmPassword,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _infoMessage = 'OTP sent to your email.';
          _errorMessage = '';
          _isCooldown = true;
          _secondsRemaining = 60;
          _emailModified = false;
        });
        _startCooldownTimer();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['detail'] ?? 'Failed to send OTP.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error sending OTP.';
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _isCooldown = false;
        }
      });
      return _secondsRemaining > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || otp.isEmpty) {
      setState(() {
        _errorMessage = 'Email and OTP are required.';
        _infoMessage = '';
      });
      return;
    }

    try {
      final verifyResponse = await http.post(
        Uri.parse(ApiConfig.verifyRegistrationEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({"email": email, "otp": otp}),
      );

      if (verifyResponse.statusCode == 200) {
        Navigator.pushReplacementNamed(context, '/');
      } else {
        final data = jsonDecode(verifyResponse.body);
        setState(() => _errorMessage = data['detail'] ?? 'Verification failed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not connect to server');
    }
  }

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.transparent,
      labelStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
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
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: const Text(
                'Account Registration',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.lock_outline, size: 80, color: Colors.black),
                            SizedBox(height: 12),
                            Text(
                              'Please verify your email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _emailController,
                        readOnly: true,
                        decoration: _inputStyle('Email'),
                        style: const TextStyle(color: Colors.black, fontSize: 20),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                        ),
                      if (_infoMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_infoMessage, style: const TextStyle(color: Colors.green)),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: const Text('Back', style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA3DB94),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Verify', style: TextStyle(color: Colors.black, fontSize: 16)),
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
