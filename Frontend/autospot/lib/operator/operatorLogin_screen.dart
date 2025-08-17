import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class OperatorLoginScreen extends StatefulWidget {
  const OperatorLoginScreen({super.key});

  @override
  State<OperatorLoginScreen> createState() => _OperatorLoginScreenState();
}

class _OperatorLoginScreenState extends State<OperatorLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _keyIdController = TextEditingController();

  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final keyId = _keyIdController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _errorMessage = '');

    if (username.isEmpty || password.isEmpty || keyId.isEmpty || email.isEmpty) {
      setState(() => _errorMessage = 'All fields must be filled.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminLoginEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'keyID': keyId,
          'username': username,
          'password': password,
          'email': email,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('email', email);
        await prefs.setString('keyID', keyId);
        await prefs.setString('building', keyId);
        await prefs.setString('password', password);

        if (!mounted) return;
        Navigator.pushNamed(context, '/operator_dashboard');
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          if (data is Map && data['detail'] is List) {
            _errorMessage = data['detail'][0]['msg'] ?? 'Login failed.';
          } else {
            _errorMessage = data['detail'] ?? data['message'] ?? 'Login failed.';
          }
        });
      }
    } catch (e) {
      debugPrint("Login error: $e");
      setState(() => _errorMessage = 'Could not connect to server or timed out.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputStyle(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.black54),
      filled: true,
      fillColor: Colors.transparent,
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('AutoSpot', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Operator Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 36),

                  TextFormField(controller: _usernameController, decoration: _inputStyle('Username'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 20),

                  TextFormField(controller: _emailController, decoration: _inputStyle('Email'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 20),

                  TextFormField(controller: _passwordController, obscureText: true, decoration: _inputStyle('Password'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 20),

                  TextFormField(controller: _keyIdController, decoration: _inputStyle('Key-ID'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                  const SizedBox(height: 8),

                  if (_errorMessage.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/contact_support'),
                      child: const Text('Contact Support', style: TextStyle(color: Colors.blue)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Back', style: TextStyle(color: Colors.black, fontSize: 18)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Login', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
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
