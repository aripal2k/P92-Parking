import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UserCarbonEmissionScreen extends StatefulWidget {
  const UserCarbonEmissionScreen({super.key});

  @override
  State<UserCarbonEmissionScreen> createState() => _UserCarbonEmissionScreenState();
}

class _UserCarbonEmissionScreenState extends State<UserCarbonEmissionScreen> {
  bool showHistory = false;
  List<dynamic> carbonHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessionHistoryAndEmission();
  }

  // Fetch session history ad emission history from backend
  Future<void> _fetchSessionHistoryAndEmission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');

      if (username == null || username.isEmpty) {
        // debugPrint("Username not found in SharedPreferences.");
        // debugPrint("Available keys in SharedPreferences:");
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          // debugPrint("  - $key: ${prefs.get(key)}");
        }
        return;
      }

      // Step 1: Fetch session history
      final sessionUri = Uri.parse('${ApiConfig.sessionHistory}?username=$username');
      final sessionRes = await http.get(sessionUri);
      // debugPrint("Session history response: ${sessionRes.statusCode}");

      // debugPrint("Requesting session history from: ${sessionUri.toString()}");

      if (sessionRes.statusCode == 200) {
        final sessionData = jsonDecode(sessionRes.body);
        final sessions = sessionData['sessions'] ?? [];

        // Save all entrance and exit data in memory or preferences if needed
        // debugPrint("Retrieved ${sessions.length} sessions");

        // Step 2: Fetch emission history (optional if you're already calculating it based on session data)
        final emissionUri = Uri.parse('${ApiConfig.emissionsHistory}?username=$username&limit=50');
        final emissionRes = await http.get(emissionUri);
        // debugPrint("Emission request to: ${emissionUri.toString()}");
        // debugPrint("Emission response: ${emissionRes.statusCode}");

        if (emissionRes.statusCode == 200) {
          final emissionData = jsonDecode(emissionRes.body);
          final records = emissionData['records'];
          // debugPrint("Found ${records.length} emission records for user: $username");
          
          if (records.isNotEmpty) {
            // debugPrint("First record sample: ${records[0]}");
            final firstRecord = records[0];
            final buildingName = firstRecord['map_info']?['building_name'] ?? 'No building name';
            // debugPrint("First record building: $buildingName");
          }

          setState(() {
            carbonHistory = records;
          });
          
          // debugPrint("Carbon history updated with ${records.length} records");
        } else {
          // debugPrint("Failed to load carbon history: ${emissionRes.statusCode}");
          // debugPrint("Response body: ${emissionRes.body}");
        }
      } else {
        // debugPrint("Failed to load session history: ${sessionRes.statusCode}");
      }
    } catch (e) {
      // debugPrint("Exception while fetching data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4EECD),
        elevation: 0,
        leading: showHistory
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() {
                    showHistory = false;
                  });
                },
              )
            : null,
        title: const Text(
          'AutoSpot',
          style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : showHistory
                ? _buildHistoryCard()
                : _buildIntroScreen(context),
      ),
    );
  }

  // Intro screen shown before user opens history
  Widget _buildIntroScreen(BuildContext context) {
    // debugPrint("Entered _buildIntroScreen");
    // debugPrint("Carbon history length: ${carbonHistory.length}");

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco, size: 100, color: Color(0xFF68B245)),
          const SizedBox(height: 24),
          const Text(
            'Carbon Emission Savings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Track your eco-friendly parking benefits with our smart routing system.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              // debugPrint("Button pressed: View My Carbon Savings");
              if (carbonHistory.isNotEmpty) {
                // debugPrint("Showing carbon history");
                setState(() {
                  showHistory = true;
                });
              } else {
                // debugPrint("No carbon history found");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("No carbon emission history found."),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA3DB94),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'View My Carbon Savings',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List of historical carbon savings records
  Widget _buildHistoryCard() {
    // debugPrint("_buildHistoryCard: Entered _buildHistoryCard with ${carbonHistory.length} records");

    if (carbonHistory.isEmpty) {
      // debugPrint(" _buildHistoryCard: No records to display in history");
      return const Center(child: Text("No carbon savings records found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: carbonHistory.length,
      itemBuilder: (context, index) {
        final record = carbonHistory[index];
        // debugPrint("Rendering record $index: ${record['session_info']?['session_id']}");
        // debugPrint("Record created_at: ${record['created_at']}");

        final date = record['created_at']?.split('T')[0] ?? 'Unknown Date';
        // debugPrint("Parsed date: $date");

        return _buildCarbonCard(
          title: record['map_info']?['building_name'] ?? 'Unknown Location',
          date: date,
          emissionsSaved: record['emissions_saved'].toString(),
          efficiency: record['percentage_saved'].toString(),
          method: record['calculation_method'] ?? 'N/A',
          message: record['message'] ?? 'This trip saved you emissions using AutoSpot!',
        );
      },
    );
  }

  // Individual card UI for a carbon savings record
  Widget _buildCarbonCard({
    required String title,
    required String date,
    required String emissionsSaved,
    required String efficiency,
    required String method,
    required String? message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF76C893), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 8),
          Text("Date: $date", style: const TextStyle(color: Colors.black)),
          Text("Emissions Saved: $emissionsSaved g CO₂", style: const TextStyle(color: Colors.black)),
          Text("Efficiency: $efficiency%", style: const TextStyle(color: Colors.black)),
          Text("Method: $method", style: const TextStyle(color: Colors.black)),
          const SizedBox(height: 12),
          Text(
            message ?? '',
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
