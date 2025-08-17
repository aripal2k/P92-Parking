import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? errorMessage;

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => errorMessage = null);

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        
        // Fetch user profile to get username immediately after login
        try {
          final profileResponse = await http.get(
            Uri.parse("${ApiConfig.getUserProfileEndpoint}?email=$email"),
            headers: ApiConfig.headers,
          );
          
          if (profileResponse.statusCode == 200) {
            final userData = jsonDecode(profileResponse.body);
            final username = userData['username'] ?? '';
            if (username.isNotEmpty) {
              await prefs.setString('username', username);
              // debugPrint("Username set after login: $username");
            }
          }
        } catch (e) {
          // debugPrint("Failed to fetch username after login: $e");
        }
        
        // Clear any existing navigation state to ensure fresh start
        await _clearAllUserState(prefs);

        // Navigate to main container after login
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
      } else {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String serverMessage = responseBody['detail'] ?? 'An unknown error occurred.';

        setState(() => errorMessage = serverMessage);
      }
    } catch (e) {
      // debugPrint('$e');
      setState(() => errorMessage = 'Could not connect to server');
    }
  }

  // Comprehensive method to clear all user state and cache
  Future<void> _clearAllUserState(SharedPreferences prefs) async {
    // Navigation and spot allocation related
    await prefs.remove('entrance_id');
    await prefs.remove('selected_destination');
    await prefs.remove('navigation_path');
    await prefs.remove('destination_path');
    await prefs.remove('allocated_spot_id');
    await prefs.remove('slot_x');
    await prefs.remove('slot_y');
    await prefs.remove('slot_level');
    
    // Session related
    await prefs.remove('session_id');
    await prefs.remove('parking_start_time');
    await prefs.remove('countdown_start_time');
    await prefs.remove('countdown_seconds');
    
    // Navigation flags
    await prefs.setBool('has_valid_navigation', false);
    await prefs.setBool('from_dashboard_selection', false);
    
    // debugPrint('All user state cleared for fresh start');
  }

  InputDecoration _inputStyle(String label) {
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
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'AutoSpot',
                            style:
                                TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Center(
                          child: Text(
                            'Account Login',
                            style:
                                TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: emailController,
                          decoration: _inputStyle('Email'),
                          style: const TextStyle(color: Colors.black, fontSize: 20),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 25),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: _inputStyle('Password'),
                          style: const TextStyle(color: Colors.black, fontSize: 20),
                        ),
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/forgot-password'),
                            child: const Text(
                              'Forget Password?',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA3DB94),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Login',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: const [
                            Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('OR'),
                            ),
                            Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/operator-login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Operator Login', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.black),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Create account',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
