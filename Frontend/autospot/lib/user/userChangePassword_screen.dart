import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

// Screen for changing the user's password
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  String email = '';
  // Controllers for the password text fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  // Variables for password validation
  String _password = '';
  String _errorMessage = '';
  bool _isLongEnough = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  // Booleans to toggle password visibility for each field
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Check password complexity and update validation flags
  void _checkPassword(String value) {
    setState(() {
      _password = value;
      _isLongEnough = value.length >= 8;
      _hasUpper = value.contains(RegExp(r'[A-Z]'));
      _hasLower = value.contains(RegExp(r'[a-z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSpecial = value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  // Load user email from SharedPreferences
  void _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('user_email') ?? '-';
    });
  }

  // Attempt to change the password by sending request to backend API
  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNewPassword = _confirmNewPasswordController.text.trim();

    setState(() => _errorMessage = '');

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (newPassword != confirmNewPassword) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }

    if (!(_isLongEnough && _hasUpper && _hasLower && _hasNumber && _hasSpecial)) {
      setState(() => _errorMessage = "Password does not meet all requirements.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.changePasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "email": email,
          "current_password": currentPassword,
          "new_password": newPassword,
          "confirm_new_password": confirmNewPassword,
        }),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = "Error: ${jsonDecode(response.body)['detail'] ?? 'Failed'}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    }
  }

  // Standardized input decoration for text fields
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        enabled: false,
                        controller: TextEditingController(text: email),
                        decoration: _inputDecoration('Email'),
                        style: const TextStyle(color: Colors.black, fontSize: 18),
                      ),
                      const SizedBox(height: 20),

                      _buildPasswordField('Current Password', _currentPasswordController, _showCurrentPassword, () {
                        setState(() => _showCurrentPassword = !_showCurrentPassword);
                      }),
                      const SizedBox(height: 20),

                      _buildPasswordField('New Password', _newPasswordController, _showNewPassword, () {
                        setState(() => _showNewPassword = !_showNewPassword);
                      }, onChanged: _checkPassword),
                      const SizedBox(height: 10),

                      _buildRequirementText("At least 8 characters", _isLongEnough),
                      _buildRequirementText("Contains uppercase", _hasUpper),
                      _buildRequirementText("Contains lowercase", _hasLower),
                      _buildRequirementText("Contains number", _hasNumber),
                      _buildRequirementText("Contains special character", _hasSpecial),
                      const SizedBox(height: 20),

                      _buildPasswordField('Confirm New Password', _confirmNewPasswordController, _showConfirmPassword, () {
                        setState(() => _showConfirmPassword = !_showConfirmPassword);
                      }),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          // Cancel button
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
                          // Save button
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
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a password field with visibility toggle
  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool isObscured,
    VoidCallback toggleVisibility, {
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isObscured,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black, fontSize: 18),
      decoration: _inputDecoration(label).copyWith(
        suffixIcon: IconButton(
          icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off, color: Colors.black),
          onPressed: toggleVisibility,
        ),
      ),
    );
  }

  // Helper to display a password requirement with an icon
  Widget _buildRequirementText(String text, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: passed ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: passed ? Colors.green : Colors.red, fontSize: 14),
        ),
      ],
    );
  }
}
