import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class OperatorEditParkingFeeScreen extends StatefulWidget {
  const OperatorEditParkingFeeScreen({super.key});

  @override
  State<OperatorEditParkingFeeScreen> createState() => _OperatorEditParkingFeeScreenState();
}

class _OperatorEditParkingFeeScreenState extends State<OperatorEditParkingFeeScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _baseRateController = TextEditingController();
  final TextEditingController _peakRateController = TextEditingController();
  final TextEditingController _weekendRateController = TextEditingController();
  final TextEditingController _holidayRateController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? selectedDestination;
  String keyID = '';
  String username = '';
  String errorMessage = '';
  bool isLoading = false;
  final bool _destinationError = false;

  final collaboratingPlaces = [
    'Westfield Sydney (Example)',
    'Westfield Bondi Junction',
    'Westfield Parramatta',
    'Westfield Chatswood',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // Loads operator's keyID and username from SharedPreferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      keyID = prefs.getString('keyID') ?? '';
      username = prefs.getString('username') ?? '';
    });
  }

  // Builds a styled InputDecoration for labeled text fields
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

  // Builds a styled InputDecoration for hint-text fields
  InputDecoration _inputStyle(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black54),
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

  // Opens a modal bottom sheet to pick a destination from the collaborating places list
  void _showDestinationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView.builder(
          itemCount: collaboratingPlaces.length,
          itemBuilder: (context, index) {
            final place = collaboratingPlaces[index];
            return ListTile(
              title: Text(place),
              onTap: () {
                setState(() {
                  selectedDestination = place;
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  // Submits the new parking rates to the backend API
  Future<void> _submitRates() async {
    setState(() {
      errorMessage = '';
      isLoading = true;
    });

    final body = {
      "destination": selectedDestination ?? '',
      "rates": {
        "base_rate_per_hour": _baseRateController.text.trim(),
        "peak_hour_surcharge_rate": _peakRateController.text.trim(),
        "weekend_surcharge_rate": _weekendRateController.text.trim(),
        "public_holiday_surcharge_rate": _holidayRateController.text.trim(),
      },
      "keyID": keyID,
      "username": username,
      "password": _passwordController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.editParkingFeeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parking fee updated successfully.')),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['detail'] ?? 'Failed to update rates.';
        });
      }
    } catch (e) {
      setState(() => errorMessage = 'Connection error. Please try again.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Edit Parking Fee Rate',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  readOnly: true,
                  onTap: _showDestinationPicker,
                  controller: TextEditingController(text: selectedDestination ?? ''),
                  decoration: _inputStyle('Select Destination').copyWith(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _destinationError ? Colors.red : const Color(0xFFA3DB94),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _destinationError ? Colors.red : Colors.green,
                        width: 2,
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _baseRateController,
                  decoration: _inputDecoration('Base Rate per Hour'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _peakRateController,
                  decoration: _inputDecoration('Peak Hour Surcharge Rate'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weekendRateController,
                  decoration: _inputDecoration('Weekend Surcharge Rate'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _holidayRateController,
                  decoration: _inputDecoration('Public Holiday Surcharge Rate'),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('Confirm Password'),
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 12),
                if (errorMessage.isNotEmpty)
                  Text(errorMessage, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                Row(
                  children: [
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
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitRates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA3DB94),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
