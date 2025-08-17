import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class OperatorProfileScreen extends StatefulWidget {
  const OperatorProfileScreen({super.key});

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen> {
  String username = "-";
  String email = "-";
  String keyID = "-";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Loads stored user data from SharedPreferences and refreshes from backend
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('email');
    final storedUsername = prefs.getString('username');
    final storedKeyID = prefs.getString('keyID');

    if (storedEmail == null || storedUsername == null || storedKeyID == null) return;

    setState(() {
      email = storedEmail;
      username = storedUsername;
      keyID = storedKeyID;
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.getUserProfileEndpoint}?email=$storedEmail"),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final user = json.decode(response.body);
        setState(() {
          username = user['username'] ?? username;
        });
      } else {
        // debugPrint("Error fetching profile: ${response.statusCode}");
      }
    } catch (e) {
      // debugPrint("Error calling profile endpoint: $e");
    }
  }

  // Logs out the operator by clearing local storage and returning to login
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
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
                children: [
                  const Text(
                    'AutoSpot',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Center(
                              child: Text(
                                'Profile',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: Colors.black45),
                            _profileItem("Email", email),
                            _profileItem("Username", username),
                            _profileItem("Key ID", keyID),
                            const Divider(color: Colors.black45),
                            const SizedBox(height: 16),
                            _animatedButton("Edit Profile", Colors.grey[300]!, () async {
                              final result = await Navigator.pushNamed(context, '/operator_profile/edit');
                              if (result == true) {
                                _loadUserData();
                              }
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Change Password", Colors.amber, () {
                              Navigator.pushNamed(context, '/operator_profile/change-password');
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Edit Parking Fee Rate", Colors.orange, () {
                              Navigator.pushNamed(context, '/operator_profile/edit_parking_fee');
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Upload Map", Colors.lightBlue, () {
                               Navigator.pushNamed(context, '/operator_profile/upload_map');
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Logout", Colors.redAccent.shade100, _logout),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: const Color(0xFFD4EECD),
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamedAndRemoveUntil(context, '/operator_dashboard', (route) => false);
          } else if (index == 3) {
            Navigator.pushNamedAndRemoveUntil(context, '/operator_profile', (route) => false);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Widget for displaying a profile field (label + value)
  Widget _profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // Widget for an animated action button
  Widget _animatedButton(String label, Color color, VoidCallback onPressed,
      {Color textColor = Colors.black}) {
    return InkWell(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
