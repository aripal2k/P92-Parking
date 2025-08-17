import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'package:autospot/main_container.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _homeAddressController = TextEditingController();

  String email = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // Fetch the current user's profile data from the server and populate fields
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    email = prefs.getString('user_email') ?? '';

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getUserProfileEndpoint}?email=$email'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _fullNameController.text = data['fullname'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _licensePlateController.text = data['license_plate'] ?? '';
          _phoneNumberController.text = data['phone_number'] ?? '';
          _homeAddressController.text = data['address'] ?? '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load profile.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Server error while loading profile.");
    }
  }

  // Save updated profile data to the server
  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final licensePlate = _licensePlateController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();
    final homeAddress = _homeAddressController.text.trim();

    if (fullName.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'Full Name and Username are required.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.editProfileEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'fullname': fullName,
          'username': username,
          'license_plate': licensePlate,
          'phone_number': phoneNumber,
          'address': homeAddress,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainContainer(initialIndex: 5),
          ),
          (route) => false,
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error.');
    }
  }

  // Consistent style for all form fields
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
              automaticallyImplyLeading: false,
              title: const Text(
                'Edit Profile',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
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
                      _buildTextField('Full Name', controller: _fullNameController),
                      const SizedBox(height: 20),
                      _buildTextField('Username', controller: _usernameController),
                      const SizedBox(height: 20),
                      _buildTextField('License Plate', controller: _licensePlateController),
                      const SizedBox(height: 20),
                      _buildTextField('Phone Number', controller: _phoneNumberController),
                      const SizedBox(height: 20),
                      _buildTextField('Home Address', controller: _homeAddressController),
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
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveProfile,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable text field builder
  Widget _buildTextField(String label, {required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black, fontSize: 18),
      decoration: _inputDecoration(label),
    );
  }
}
