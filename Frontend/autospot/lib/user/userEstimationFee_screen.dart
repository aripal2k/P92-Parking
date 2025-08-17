import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class EstimationFeeScreen extends StatefulWidget {
  const EstimationFeeScreen({super.key});

  @override
  State<EstimationFeeScreen> createState() => _EstimationFeeScreenState();
}

class _EstimationFeeScreenState extends State<EstimationFeeScreen> {
  String building = 'Loading...';
  String date = '';
  String timeStart = '';
  String durationText = '';
  double ratePerHour = 0.0;
  double estimatedPrice = 0.0;
  double weekendSurcharge = 0.0;
  double peakSurcharge = 0.0;
  double publicHolidaySurcharge = 0.0;
  double totalPrice = 0.0;
  bool isLoading = true;

  // Fetch fare estimation from backend API
  Future<void> _fetchFareEstimation() async {
    final prefs = await SharedPreferences.getInstance();
    final destination = prefs.getString('selected_destination') ?? '';
    final parkingDate = prefs.getString('selected_date') ?? '';
    final parkingStartTime = prefs.getString('selected_time') ?? '';
    double durationHours = prefs.getDouble('selected_duration_in_hours') ?? 2.0;
    int hours = prefs.getInt('selected_hours') ?? 0;
    final minutes = prefs.getInt('selected_minutes') ?? 0;

    if (durationHours == 0.0) hours = 2;
    if (durationHours == 0.0) durationHours = 2.0;

    final durationFormatted = '${durationHours.toStringAsFixed(2)} hour '
        '($hours hour${hours > 1 ? 's' : ''}'
        '${minutes > 0 ? ' and $minutes minute${minutes != 1 ? 's' : ''}' : ''})';

    // Use API configuration - it automatically switches between local and production
    // For local testing: set useLocalHost = true in api_config.dart
    final url = Uri.parse(ApiConfig.predictFareEndpoint);

    final body = {
      'destination': destination,
      if (parkingDate.isNotEmpty) 'date': parkingDate,
      if (parkingStartTime.isNotEmpty) 'time': parkingStartTime,
      'duration_hours': durationHours.ceil(),
    };

    try {
      final response = await http.post(
        url, // local testing
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final breakdown = data['breakdown'];

        setState(() {
          building = data['destination'];
          date = data['parking_date'];
          timeStart = data['parking_start_time'];
          durationText = durationFormatted;
          ratePerHour = breakdown['base_rate_per_hour']?.toDouble() ?? 0.0;
          estimatedPrice = breakdown['total_duration_base_cost']?.toDouble() ?? 0.0;
          peakSurcharge = breakdown['peak_hour_surcharge']?.toDouble() ?? 0.0;
          weekendSurcharge = breakdown['weekend_surcharge']?.toDouble() ?? 0.0;
          publicHolidaySurcharge = breakdown['public_holiday_surcharge']?.toDouble() ?? 0.0;
          totalPrice = breakdown['total']?.toDouble() ?? 0.0;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load fare data");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching fare: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchFareEstimation();
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
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
                                      'Fare Estimation',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(color: Colors.black45),
                                  _infoRow("Building", building),
                                  _infoRow("Date", date),
                                  _infoRow("Time start", timeStart),
                                  _infoRow("Duration", durationText),
                                  const Divider(color: Colors.black45),
                                  _infoRow("Rate per hour", "\$${ratePerHour.toStringAsFixed(2)}/hr"),
                                  const SizedBox(height: 5),
                                  _infoRow("Base Cost", "\$${estimatedPrice.toStringAsFixed(2)}"),
                                  const SizedBox(height: 5),
                                  _infoRow("Peak Hour Surcharge", "\$${peakSurcharge.toStringAsFixed(2)}"),
                                  const SizedBox(height: 5),
                                  _infoRow("Weekend Surcharge", "\$${weekendSurcharge.toStringAsFixed(2)}"),
                                  const SizedBox(height: 5),
                                  _infoRow("Holiday Surcharge", "\$${publicHolidaySurcharge.toStringAsFixed(2)}"),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Total Estimated Price: \$${totalPrice.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _styledButton("Cancel", Colors.grey[300]!, () {
                                Navigator.pop(context);
                              }),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _styledButton("Get Lot", const Color(0xFFA3DB94), () {
                                  Navigator.pushNamed(context, '/qr-intro');
                              }),
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

  // Helper method to build an information row
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              "$label:",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a styled button
  Widget _styledButton(String label, Color color, VoidCallback onPressed, {Color textColor = Colors.black}) {
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