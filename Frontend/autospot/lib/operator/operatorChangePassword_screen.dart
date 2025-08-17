import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class OperatorChangePasswordScreen extends StatefulWidget {
  const OperatorChangePasswordScreen({super.key});

  @override
  State<OperatorChangePasswordScreen> createState() => _OperatorChangePasswordScreenState();
}

class _OperatorChangePasswordScreenState extends State<OperatorChangePasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String email = '';
  String username = '';
  String keyID = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
    _newPasswordController.addListener(() => setState(() {}));
  }

  // Loads stored operator credentials (email, username, keyID) from SharedPreferences
  void _loadStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '';
      username = prefs.getString('username') ?? '';
      keyID = prefs.getString('keyID') ?? '';
    });
  }

  // Handles password change request by validating inputs and sending a PUT request to the API
  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() => _errorMessage = '');

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all fields.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }

    if (!_hasMinLength(newPassword) ||
        !_hasUppercase(newPassword) ||
        !_hasLowercase(newPassword) ||
        !_hasNumber(newPassword) ||
        !_hasSpecialChar(newPassword)) {
      setState(() => _errorMessage = 'Password does not meet all requirements.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.updateChangePasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "keyID": keyID,
          "current_username": username,
          "current_password": oldPassword,
          "new_password": newPassword,
          "confirm_new_password": confirmPassword,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully.')),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() => _errorMessage = body['detail'] ?? 'Failed to change password.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    }
  }

  bool _hasMinLength(String value) => value.length >= 8;
  bool _hasUppercase(String value) => value.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String value) => value.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String value) => value.contains(RegExp(r'[0-9]'));
  bool _hasSpecialChar(String value) => value.contains(RegExp(r'[!@#\$&*~%^]'));

  // Builds a password requirement indicator row (with check or cancel icon)
  Widget _passwordCriteria(String text, bool isValid) {
    return Row(
      children: [
        Icon(isValid ? Icons.check_circle : Icons.cancel, color: isValid ? Colors.green : Colors.red, size: 20),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: isValid ? Colors.green : Colors.red)),
      ],
    );
  }

  // Returns an input decoration for consistent form styling
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.transparent,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2.0),
      ),
    );
  }

   // Builds a password text field with visibility toggle
  Widget _buildPasswordField(String label, TextEditingController controller, bool obscureText, VoidCallback toggleVisibility) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 18, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
          onPressed: toggleVisibility,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = _newPasswordController.text;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'Change Password',
                      style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    enabled: false,
                    controller: TextEditingController(text: keyID),
                    decoration: _inputDecoration('Key ID'),
                    style: const TextStyle(color: Colors.black, fontSize: 18),
                  ),
                  const SizedBox(height: 20),

                  _buildPasswordField('Current Password', _oldPasswordController, _obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
                  const SizedBox(height: 20),

                  _buildPasswordField('New Password', _newPasswordController, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                  const SizedBox(height: 12),

                  _passwordCriteria('At least 8 characters', _hasMinLength(newPassword)),
                  _passwordCriteria('Contains uppercase', _hasUppercase(newPassword)),
                  _passwordCriteria('Contains lowercase', _hasLowercase(newPassword)),
                  _passwordCriteria('Contains number', _hasNumber(newPassword)),
                  _passwordCriteria('Contains special character', _hasSpecialChar(newPassword)),

                  const SizedBox(height: 20),
                  _buildPasswordField('Confirm New Password', _confirmPasswordController, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),

                  const SizedBox(height: 10),
                  if (_errorMessage.isNotEmpty)
                    Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14)),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black, fontSize: 16)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
