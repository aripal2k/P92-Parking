import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ForgetPasswordResetScreen extends StatefulWidget {
  const ForgetPasswordResetScreen({super.key});

  @override
  State<ForgetPasswordResetScreen> createState() =>
      _ForgetPasswordResetScreenState();
}

class _ForgetPasswordResetScreenState extends State<ForgetPasswordResetScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _errorMessage = '';

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isLongEnough = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  void _checkPassword(String value) {
    setState(() {
      _isLongEnough = value.length >= 8;
      _hasUpper = value.contains(RegExp(r'[A-Z]'));
      _hasLower = value.contains(RegExp(r'[a-z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSpecial = value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields.");
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = "Passwords don't match.");
      return;
    }

    if (!(_isLongEnough && _hasUpper && _hasLower && _hasNumber && _hasSpecial)) {
      setState(() => _errorMessage = "Password does not meet all requirements.");
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final email = args?['email'] ?? '';

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'new_password': password,
          'confirm_new_password': confirmPassword,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamed(context, '/');
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Reset failed.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Reset failed due to network error.');
    }
  }

  InputDecoration _inputDecoration(String label, bool isObscured) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.transparent,
      labelStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2.0),
      ),
      suffixIcon: IconButton(
        icon: Icon(
          isObscured ? Icons.visibility_off : Icons.visibility,
          color: Colors.black54,
        ),
        onPressed: () {
          setState(() {
            if (label == 'New Password') {
              _obscurePassword = !_obscurePassword;
            } else {
              _obscureConfirm = !_obscureConfirm;
            }
          });
        },
      ),
    );
  }

  Widget _buildRequirement(bool condition, String text) {
    return Row(
      children: [
        Icon(
          condition ? Icons.check_circle : Icons.cancel,
          color: condition ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: condition ? Colors.green : Colors.red)),
      ],
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
              centerTitle: true,
              title: const Text(
                'Change Password',
                style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.lock, size: 80, color: Colors.black),
                      const SizedBox(height: 10),
                      const Text(
                        'Please type your new password.',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        obscureText: _obscurePassword,
                        controller: _passwordController,
                        onChanged: _checkPassword,
                        decoration: _inputDecoration('New Password', _obscurePassword),
                        style: const TextStyle(color: Colors.black, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRequirement(_isLongEnough, 'At least 8 characters'),
                          _buildRequirement(_hasUpper, 'Contains uppercase'),
                          _buildRequirement(_hasLower, 'Contains lowercase'),
                          _buildRequirement(_hasNumber, 'Contains number'),
                          _buildRequirement(_hasSpecial, 'Contains special character'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        obscureText: _obscureConfirm,
                        controller: _confirmPasswordController,
                        decoration: _inputDecoration('Confirm New Password', _obscureConfirm),
                        style: const TextStyle(color: Colors.black, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      if (_errorMessage.isNotEmpty)
                        Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _errorMessage,
                            textAlign: TextAlign.left,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 20),
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
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Colors.black, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA3DB94),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text(
                                'Save Password',
                                style: TextStyle(fontSize: 16),
                              ),
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
