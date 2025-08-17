import 'package:flutter/material.dart';
import 'package:autospot/user/userOTPVerification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _password = '';
  String _errorMessage = '';
  bool _isLongEnough = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;
  bool _isEmailValid = true;

  // Checks if the entered password meets all requirements
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

  // Handles form validation and navigation to OTP verification.
  void _register() {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _errorMessage = '';
      _isEmailValid = email.contains('@');
    });

    if (!_isEmailValid) return;

    if (password != confirmPassword) {
      setState(() => _errorMessage = "Passwords don't match.");
      return;
    }

    if (!(_isLongEnough && _hasUpper && _hasLower && _hasNumber && _hasSpecial)) {
      setState(() => _errorMessage = "Password does not meet all requirements.");
      return;
    }

    // Navigate to OTP verification screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerifyOtpScreen(
          userData: {
            'email': _emailController.text.trim(),
            'username': _usernameController.text.trim(),
            'fullname': _fullNameController.text.trim(),
            'password': _passwordController.text,
            'confirm_password': _confirmPasswordController.text,
          },
        ),
      ),
    );
  }

  // Returns a consistent input decoration style for all text fields
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
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  /// Builds a text field with optional obscured text and custom size
  Widget _buildTextField(
    String label, {
    bool obscure = false,
    double size = 20,
    TextEditingController? controller,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: _inputStyle(label),
      style: TextStyle(color: Colors.black, fontSize: size),
    );
  }

  // Displays the list of password requirements with validation status
  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirementText("At least 8 characters", _isLongEnough),
        _buildRequirementText("Contains uppercase", _hasUpper),
        _buildRequirementText("Contains lowercase", _hasLower),
        _buildRequirementText("Contains number", _hasNumber),
        _buildRequirementText("Contains special char", _hasSpecial),
      ],
    );
  }

  // Builds a single requirement row with icon (check or cross) and label
  Widget _buildRequirementText(String text, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: passed ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: passed ? Colors.green : Colors.red)),
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
              automaticallyImplyLeading: false,
              centerTitle: true,
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
                      Center(
                        child: Column(
                          children: const [
                            Icon(Icons.person_add_alt_1, size: 80, color: Colors.black),
                            SizedBox(height: 12),
                            Text(
                              'Please fill in your details to create an account.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField('Full Name', controller: _fullNameController),
                      const SizedBox(height: 12),
                      _buildTextField('Email', controller: _emailController),
                      if (!_isEmailValid)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Invalid email.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _buildTextField('Username', controller: _usernameController),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Password',
                        controller: _passwordController,
                        obscure: true,
                        onChanged: _checkPassword,
                      ),
                      const SizedBox(height: 8),
                      _buildPasswordRequirements(),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Re-write Password',
                        controller: _confirmPasswordController,
                        obscure: true,
                      ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: const Text('Back', style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA3DB94),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              child: const Text('Register', style: TextStyle(color: Colors.black, fontSize: 16)),
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
