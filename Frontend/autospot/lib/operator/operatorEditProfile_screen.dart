import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'operatorProfile_screen.dart';

class OperatorEditProfileScreen extends StatefulWidget {
  const OperatorEditProfileScreen({super.key});

  @override
  State<OperatorEditProfileScreen> createState() => _OperatorEditProfileScreenState();
}

class _OperatorEditProfileScreenState extends State<OperatorEditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordDialogController = TextEditingController();

  String email = '';
  String keyID = '';
  String currentUsername = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadOperatorData();
  }

  // Loads operator data (email, keyID, username) from shared preferences
  Future<void> _loadOperatorData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '';
      keyID = prefs.getString('keyID') ?? '';
      currentUsername = prefs.getString('username') ?? '';
      _usernameController.text = currentUsername;
    });
  }
  
  // Prompts the operator to confirm their password before saving profile changes
  void _promptPasswordAndSave() {
    final newUsername = _usernameController.text.trim();

    if (newUsername.isEmpty) {
      setState(() => _errorMessage = "Username cannot be empty.");
      return;
    }

    if (newUsername == currentUsername) {
      setState(() => _errorMessage = "New username is the same as current username.");
      return;
    }

    _passwordDialogController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFD4EECD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Confirm Password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: TextField(
          controller: _passwordDialogController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: Colors.black54),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.green),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA3DB94),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _saveProfileWithPassword(_passwordDialogController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  // Sends the updated profile request to backend after password confirmation
  Future<void> _saveProfileWithPassword(String password) async {
    final newUsername = _usernameController.text.trim();

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.updateOperatorProfileEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "keyID": keyID,
          "current_username": currentUsername,
          "current_password": password,
          "new_username": newUsername,
        }),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', newUsername);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully.")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OperatorProfileScreen()),
        );
      } else {
        final data = json.decode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error.');
    }
  }

  // Creates a styled input decoration for form fields
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 16),
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

  // Builds a text field with consistent styling
  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.black, fontSize: 18),
      decoration: _inputDecoration(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFD4EECD),
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
                  const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField('Email', TextEditingController(text: email), enabled: false),
                  const SizedBox(height: 20),
                  _buildTextField('Key ID', TextEditingController(text: keyID), enabled: false),
                  const SizedBox(height: 20),
                  _buildTextField('Username', _usernameController),
                  const SizedBox(height: 10),
                  if (_errorMessage.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black, fontSize: 16)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _promptPasswordAndSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
          )
        ],
      ),
    );
  }
}
