import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  bool hasAllocatedSlot = false;
  Uint8List? qrImageBytes;
  bool isLoading = true;

  // Refresh QR status and generate (or simulate) a QR code
  Future<void> _refreshQRStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    final String? destination = prefs.getString('selected_destination');
    final String? email = prefs.getString('user_email');

    // Fetch username using email if it's missing
    if ((username == null || username == '-') && email != null) {
      try {
        final response = await http.get(
          Uri.parse("${ApiConfig.getUserProfileEndpoint}?email=$email"),
          headers: ApiConfig.headers,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          username = data['username'];
          if (username != null) {
            await prefs.setString('username', username);
          }
        } else {
          // debugPrint('Error fetching username: ${response.statusCode}');
        }
      } catch (e) {
        // debugPrint('Exception while fetching username: $e');
      }
    }

    // If required data is missing, stop and show "no QR" state
    if (username == null || destination == null) {
      setState(() {
        hasAllocatedSlot = false;
        isLoading = false;
      });
      // debugPrint('Missing username or destination in SharedPreferences');
      return;
    }

    // Since the original /qr/generate endpoint is commented out in backend,
    // we'll create a QR code locally for now
    final now = DateTime.now().toUtc();
    final expireAt = now.add(const Duration(minutes: 15));
    
    final qrContent = {
      'username': username,
      'destination': destination,
      'expire_at': expireAt.toIso8601String(),
      'created_at': now.toIso8601String(),
    };
    
    // For production, we should call the backend API
    // but since it's not available, we'll generate locally
    try {
      // Create a simple text QR code with the JSON content
      final qrText = jsonEncode(qrContent);
      
      // For now, we'll simulate the API response
      // In production, this should be: final response = await http.post(uri);
      setState(() {
        // Since we can't generate actual QR image without backend,
        // we'll show a placeholder or use a QR generation package
        hasAllocatedSlot = true;
        isLoading = false;
      });
      
      // Show a message that QR generation is simulated
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code feature is under maintenance'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      // debugPrint("Exception: $e");
      setState(() {
        hasAllocatedSlot = false;
        isLoading = false;
      });
    }
  }

  // Mark QR as scanned and reset state
  void _onQRScanned() {
    setState(() {
      hasAllocatedSlot = false;
      qrImageBytes = null;
    });
  }
  
  // Navigate to QR scanner screen
  void _navigateToQRScanner() {
    Navigator.pushNamed(context, '/qr-scanner');
  }

  @override
  void initState() {
    super.initState();
    _refreshQRStatus();
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('AutoSpot',
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        
                        // Scan Entrance QR Button
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
                            label: const Text(
                              'Scan Entrance QR Code',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            onPressed: _navigateToQRScanner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA3DB94),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        Expanded(
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('My QR Code',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black)),
                                      const Divider(color: Colors.black45),
                                      const SizedBox(height: 10),
                                      hasAllocatedSlot
                                          ? Column(
                                              children: [
                                                const Text(
                                                  'Successfully get a lot.\nPlease scan the QR code below:',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.black),
                                                ),
                                                const SizedBox(height: 16),
                                                if (qrImageBytes != null)
                                                  Image.memory(qrImageBytes!,
                                                      height: 160)
                                                else
                                                  const Text(
                                                      "QR image failed to load"),
                                                const SizedBox(height: 16),
                                                _styledButton("Scan Complete",
                                                    Colors.grey[300]!,
                                                    _onQRScanned),
                                              ],
                                            )
                                          : Column(
                                              children: [
                                                const Text(
                                                  'No QR code available,\nDrive your car near the building or entrance',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      color: Colors.black),
                                                ),
                                                const SizedBox(height: 16),
                                                _styledButton("Retry",
                                                    Colors.grey[300]!,
                                                    _refreshQRStatus),
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
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
      // Bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: const Color(0xFFD4EECD),
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
          if (index == 2) Navigator.pushNamedAndRemoveUntil(context, '/qr-code', (route) => false);
          if (index == 3) Navigator.pushNamedAndRemoveUntil(context, '/wallet', (route) => false);
          if (index == 4) Navigator.pushNamedAndRemoveUntil(context, '/profile', (route) => false);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), label: 'Plant'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Reusable styled button widget
  Widget _styledButton(
      String label, Color color, VoidCallback onPressed,
      {Color textColor = Colors.black}) {
    return InkWell(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
