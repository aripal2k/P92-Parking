import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  String? _email;
  String _errorMessage = '';
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getString('user_email');
    });
  }

  // Load the stored user email from SharedPreferences
  Future<void> _deleteAccount() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty || _email == null) {
      setState(() => _errorMessage = "Please enter your password.");
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = '';
    });

    final response = await http.delete(
      Uri.parse(ApiConfig.deleteAccountEndpoint),
      headers: ApiConfig.headers,
      body: jsonEncode({"email": _email, "password": password}),
    );

    setState(() => _isDeleting = false);

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all local data comprehensively
      // debugPrint('DeleteAccount: Starting comprehensive data cleanup...');
      
      // Clear payment and transaction related data explicitly
      await prefs.remove('payment_history');
      await prefs.remove('pending_payments');
      await prefs.remove('wallet_balance');
      // debugPrint('DeleteAccount: Cleared payment data');
      
      // Clear session and parking data
      await prefs.remove('parking_start_time');
      await prefs.remove('session_id');
      await prefs.remove('allocated_spot_id');
      await prefs.remove('building_id');
      await prefs.remove('selected_destination');
      await prefs.remove('entrance_id');
      await prefs.setBool('has_valid_navigation', false);
      // debugPrint('DeleteAccount: Cleared session data');
      
      // Clear temporary data
      await prefs.remove('temp_parking_start_time');
      await prefs.remove('temp_parking_end_time');
      await prefs.remove('temp_parking_duration_seconds');
      await prefs.remove('temp_allocated_spot_id');
      await prefs.remove('temp_building_id');
      await prefs.remove('temp_selected_destination');
      // debugPrint('DeleteAccount: Cleared temporary data');
      
      // Clear navigation and map data
      await prefs.remove('from_dashboard_selection');
      await prefs.remove('target_point_id');
      await prefs.remove('navigation_path');
      await prefs.remove('destination_path');
      await prefs.remove('slot_x');
      await prefs.remove('slot_y');
      await prefs.remove('slot_level');
      // debugPrint('DeleteAccount: Cleared navigation data');
      
      // Clear reservation data
      await prefs.remove('selected_date');
      await prefs.remove('selected_time');
      await prefs.remove('selected_hours');
      await prefs.remove('selected_minutes');
      await prefs.remove('selected_duration_in_hours');
      // debugPrint('DeleteAccount: Cleared reservation data');
      
      // Clear all remaining data with final clear()
      await prefs.clear();
      // debugPrint('DeleteAccount: All local data cleared successfully');
      
      // Important note: Transaction history and pending payments from backend 
      // should be deleted by the backend API when account is deleted
      // debugPrint('Note: Backend should have cleared all user transaction data');
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else {
      final detail = jsonDecode(response.body)['detail'];
      setState(() => _errorMessage = detail ?? "Deletion failed.");
    }
  }

  // Helper method for consistent input decoration styling
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 16),
      filled: true,
      fillColor: Colors.transparent,
      floatingLabelStyle: const TextStyle(
        color: Colors.green,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4EECD),
        elevation: 0,
        title: const Text(
          "Delete Account",
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                const Icon(Icons.delete_forever, size: 80, color: Colors.black87),
                const SizedBox(height: 16),

                const Text(
                  "Please input your password to confirm\nyour account deletion.",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 18),
                  decoration: _inputDecoration("Password"),
                ),
                const SizedBox(height: 12),

                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      color: _errorMessage.contains("success") ? Colors.green : Colors.red,
                    ),
                    textAlign: TextAlign.center,
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
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isDeleting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
