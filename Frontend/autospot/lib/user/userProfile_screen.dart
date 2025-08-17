import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? email;
  String fullName = "-";
  String username = "-";
  String phoneNumber = "-";
  String licensePlate = "-";
  String subscriptionPlan = "-";
  String homeAddress = "-";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Loads the user data from SharedPreferences and fetches profile from API
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('user_email');
    if (storedEmail == null) return;

    setState(() {
      email = storedEmail;
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.getUserProfileEndpoint}?email=$storedEmail"),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        // debugPrint("fetching profile: ${response.body}");

        final user = json.decode(response.body);
        setState(() {
          fullName = user['fullname'] ?? "-";
          username = user['username'] ?? "-";
          email = user['email'] ?? "-";
          phoneNumber = user['phone_number'] ?? "-";
          licensePlate = user['license_plate'] ?? "-";
          homeAddress = user['address'] ?? "-";
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', user['username'] ?? "");
        await prefs.setString('vehicle_id', user['license_plate'] ?? "");
      } else {
        // debugPrint("Error fetching profile: ${response.statusCode}");
      }
    } catch (e) {
      // debugPrint("Error calling profile endpoint: $e");
    }
  }

  // Clear all cache and reset user state
  void _clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Show confirmation dialog
    bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cache & Reset State'),
          content: const Text(
            'This will clear all cached data including parking allocations, '
            'navigation paths, and session data. Are you sure?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Clear Cache'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      // Clear all user state except login credentials
      await _clearAllUserState(prefs);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully! Please refresh the parking map.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
    
    // debugPrint('All user state cleared - cache reset complete');
  }

  // Logs the user out by clearing all stored preferences and navigating to login
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
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
                            _profileItem("Full Name", fullName),
                            _profileItem("Username", username),
                            _profileItem("Email", email ?? "-"),
                            _profileItem("Phone Number", phoneNumber),
                            _profileItem("Address", homeAddress),
                            _profileItem("License Plate", licensePlate),
                            _profileItem("Subscription Plan", subscriptionPlan),
                            const Divider(color: Colors.black45),
                            const SizedBox(height: 10),
                            _navLink("Check Our Subscription Plan", () {
                              // debugPrint("Go to Subscription Plan");
                            }),
                            _navLink("Parking History", () {
                              // debugPrint("Go to Parking History");
                            }),
                            _navLink("Contact Support", () {
                              Navigator.pushNamed(context, '/contact_support');
                            }),
                            const Divider(color: Colors.black45),
                            const SizedBox(height: 16),
                            _animatedButton("Edit Profile", Colors.grey[300]!, () {
                              Navigator.pushNamed(context, '/profile/edit');
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Change Password", Colors.amber[400]!, () {
                              Navigator.pushNamed(context, '/profile/change-password');
                            }),
                            const SizedBox(height: 10),
                            _animatedButton("Clear Cache & Reset State", Colors.orange[300]!, _clearAllCache),
                            const SizedBox(height: 10),
                            _animatedButton("Logout", Colors.redAccent.shade100, _logout),
                            const SizedBox(height: 10),
                            _animatedButton("Delete Account", Colors.red, () {
                              Navigator.pushNamed(context, '/profile/delete');
                            }, textColor: Colors.white),
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
      // No bottom navigation bar - this is handled by the MainContainer
    );
  }

  Widget _profileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  // Widget for a tappable navigation link row
  Widget _navLink(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  // Widget for an animated button with custom label and color
  Widget _animatedButton(String label, Color color, VoidCallback onPressed, {Color textColor = Colors.black}) {
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
