import 'package:autospot/main_container.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/config/api_config.dart';

class ParkingFeeScreen extends StatefulWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isActiveSession;
  final Duration? duration;
  
  const ParkingFeeScreen({
    super.key, 
    this.startTime,
    this.endTime,
    this.isActiveSession = false,
    this.duration,
  });

  @override
  State<ParkingFeeScreen> createState() => _ParkingFeeScreenState();
}

class _ParkingFeeScreenState extends State<ParkingFeeScreen> {
  bool isLoading = true;
  bool isParkingActive = false;
  String? buildingName;
  String? parkingSlotId;
  DateTime? parkingStartTime;
  DateTime? parkingEndTime;
  Duration parkingDuration = Duration.zero;
  double parkingFee = 0.0;
  Timer? _timer;
  String errorMessage = '';
  Map<String, dynamic> parkingRates = {};
  double estimatedCarbonSaved = 0.0;
  int estimatedTimeSaved = 0;

  @override
  void initState() {
    super.initState();
    
    if (widget.isActiveSession && widget.startTime != null) {
      // If this is an active session with a provided start time
      isParkingActive = true;
      parkingStartTime = widget.startTime;
      _startDurationTimer(); // Start a timer to update duration continuously
    } else if (widget.startTime != null && widget.endTime != null) {
      // Session already ended
      isParkingActive = false;
      parkingStartTime = widget.startTime;
      parkingEndTime = widget.endTime;
      
      // Use provided duration if available, otherwise calculate
      if (widget.duration != null) {
        parkingDuration = widget.duration!;
      } else {
        parkingDuration = parkingEndTime!.difference(parkingStartTime!);
      }
      
      // Calculate the fee
      parkingFee = _calculateFee(parkingDuration);
      
      // Calculate eco metrics
      estimatedCarbonSaved = parkingDuration.inMinutes * 0.012;
      estimatedTimeSaved = parkingDuration.inMinutes ~/ 3;
      
      isLoading = false;
    } else {
      // Check if we have a saved parking session
      _loadParkingSession();
    }
    
    // Load parking rates for fee calculation
    _loadParkingRates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _handleBackNavigation() async {
    // debugPrint('_handleBackNavigation called - isParkingActive: $isParkingActive, parkingEndTime: $parkingEndTime');
    
    // If the parking session is active, allow back navigation without restrictions
    if (isParkingActive) {
      // debugPrint('Parking session is active, allowing back navigation');
      return true;
    }
    
    // If this is an ended session, check for existing pending payments
    if (!isParkingActive && parkingEndTime != null) {
      // debugPrint('Parking session ended, checking for existing pending payments');
      
      // Check if user already has pending payments
      final hasPendingPayments = await _checkExistingPendingPayments();
      
      // debugPrint('Has existing pending payments: $hasPendingPayments');
      
      if (hasPendingPayments) {
        // Block exit when user already has pending payments
        // debugPrint('Blocking exit: user already has pending payments');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete your existing pending payments first before leaving this screen'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false; // Block navigation
      }
      
      // No existing pending payments, save this payment to pending list
      // debugPrint('No existing pending payments, saving current payment to pending list');
      
      // Ensure we have slot and building info before saving
      final prefs = await SharedPreferences.getInstance();
      if (parkingSlotId == null || buildingName == null) {
        // Load from temporary data if not already loaded
        buildingName = prefs.getString('temp_selected_destination') ?? 
                      prefs.getString('temp_building_id') ?? 
                      prefs.getString('selected_destination') ?? 
                      prefs.getString('building_id') ?? 
                      'Unknown Location';
        
        final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                      prefs.getString('allocated_spot_id');
        parkingSlotId = spotId ?? 'Unknown';
        
        // debugPrint('WillPop: Loaded slot info - slot: $parkingSlotId, building: $buildingName');
      }
      
      await _savePaymentToPendingList();
      
      // Clear ALL session and navigation related data to completely reset state
      await prefs.remove('temp_parking_start_time');
      await prefs.remove('temp_parking_end_time');
      await prefs.remove('temp_parking_duration_seconds');
      await prefs.remove('temp_allocated_spot_id');
      await prefs.remove('temp_building_id');
      await prefs.remove('temp_selected_destination');
      await prefs.remove('parking_start_time');
      await prefs.remove('session_id');
      await prefs.remove('allocated_spot_id');

      // Clear navigation and map state completely
      await prefs.setBool('has_valid_navigation', false);
      await prefs.remove('from_dashboard_selection');
      await prefs.remove('selected_destination');
      await prefs.remove('target_point_id');
      await prefs.remove('navigation_path');
      await prefs.remove('destination_path');
      await prefs.remove('slot_x');
      await prefs.remove('slot_y');
      await prefs.remove('slot_level');
      await prefs.remove('entrance_id');
      await prefs.remove('building_id'); // This was missing!
      
      // Clear reservation related data
      await prefs.remove('selected_date');
      await prefs.remove('selected_time');
      await prefs.remove('selected_hours');
      await prefs.remove('selected_minutes');
      await prefs.remove('selected_duration_in_hours');

      // Verify critical data is cleared
      // debugPrint('WillPop: Data cleanup completed, verifying...');
      final verifyStartTime = prefs.getString('parking_start_time');
      final verifyEntranceId = prefs.getString('entrance_id');
      final verifyBuildingId = prefs.getString('building_id');
      final verifyDestination = prefs.getString('selected_destination');
      final verifyNavigation = prefs.getBool('has_valid_navigation');
      
      // debugPrint('WillPop Verification - parking_start_time: $verifyStartTime');
      // debugPrint('WillPop Verification - entrance_id: $verifyEntranceId');
      // debugPrint('WillPop Verification - building_id: $verifyBuildingId');
      // debugPrint('WillPop Verification - selected_destination: $verifyDestination');
      // debugPrint('WillPop Verification - has_valid_navigation: $verifyNavigation');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment saved to wallet'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    
    return true;
  }

  Future<bool> _checkExistingPendingPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      
      if (email == null) {
        // debugPrint('No user email found in SharedPreferences');
        return false;
      }
      
      // debugPrint('Checking existing pending payments for user: $email');
      
      final response = await http.get(
        ApiConfig.getPendingPaymentsEndpoint(email: email),
        headers: ApiConfig.headers,
      );
      
      // debugPrint('Pending payments API response status: ${response.statusCode}');
      // debugPrint('Pending payments API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> payments;
        
        // Handle both possible response formats
        if (data is List) {
          // Direct array format: [{"transaction_id": "...", ...}, ...]
          payments = data;
        } else if (data is Map && data.containsKey('pending_payments')) {
          // Wrapped format: {"pending_payments": [...]}
          payments = data['pending_payments'] as List<dynamic>? ?? [];
        } else {
          // debugPrint('Unexpected response format: $data');
          payments = [];
        }
        
        // debugPrint('Found ${payments.length} existing pending payments');
        return payments.isNotEmpty;
      } else {
        // debugPrint('Failed to get pending payments: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // debugPrint('Error checking existing pending payments: $e');
    }
    
    return false;
  }



  void _navigateToMainContainer() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainContainer(initialIndex: 0), // 0 is dashboard
      ),
      (route) => false, // Clear all previous routes
    );
  }

  Future<Map<String, dynamic>> _sendPayLaterToBackend({
    required double amount,
    required String slotId,
    required String sessionId,
    required String buildingName,
    required DateTime startTime,
    required DateTime endTime,
    required Duration duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email'); // Make sure this is saved during login

    if (email == null) {
      // debugPrint('No user email found in SharedPreferences');
      return {'success': false, 'message': 'User not logged in. Please log in again.'};
    }

    final uri = ApiConfig.getPayLaterEndpoint(
      email: email,
      amount: amount,
      slotId: slotId,
      sessionId: sessionId,
      buildingName: buildingName,
      startTime: startTime,
      endTime: endTime,
      duration: duration,
    );


    try {
      final response = await http.post(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // debugPrint('Payment saved: ${data['message']}');
          return {'success': true, 'message': data['message']};
        } else {
          // debugPrint('Failed: ${data['message']}');
          return {'success': false, 'message': data['message']};
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['detail'] ?? 'Failed to save payment';
        // debugPrint('Error: ${response.statusCode} - $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      // debugPrint('Exception while sending pay later request: $e');
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }


  // Start a timer to update the parking duration and fee
  void _startDurationTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && parkingStartTime != null) {
        setState(() {
          parkingDuration = DateTime.now().difference(parkingStartTime!);
          parkingFee = _calculateFee(parkingDuration);
        });
      }
    });
  }

  // Calculate parking fee based on duration and rates
  double _calculateFee(Duration duration) {
    // Default hourly rate if rates couldn't be loaded
    double hourlyRate = parkingRates['hourly_rate'] ?? 5.0; 

    // Enforce minimum duration of 30 minutes
    if (duration.inMinutes < 30) {
      duration = const Duration(minutes: 30);
    }

    // Calculate hours, including partial hours
    double hours = duration.inMinutes / 60.0;

    // Round up to the nearest 15 minutes for billing
    double billableHours = (hours * 4).ceil() / 4;

    return billableHours * hourlyRate;
  }

  // Helper method to clear all temporary data
  Future<void> _clearAllTempData(SharedPreferences prefs) async {
    await prefs.remove('temp_parking_start_time');
    await prefs.remove('temp_parking_end_time');
    await prefs.remove('temp_parking_duration_seconds');
    await prefs.remove('temp_allocated_spot_id');
    await prefs.remove('temp_building_id');
    await prefs.remove('temp_selected_destination');
    // debugPrint('Cleared all temporary data');
  }

  Future<void> _loadParkingSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Debug: Print all relevant SharedPreferences values
    // debugPrint('Debug - SharedPreferences values:');
    // debugPrint('  selected_destination: ${prefs.getString('selected_destination')}');
    // debugPrint('  building_id: ${prefs.getString('building_id')}');
    // debugPrint('  allocated_spot_id: ${prefs.getString('allocated_spot_id')}');
    // debugPrint('  parking_start_time: ${prefs.getString('parking_start_time')}');
    // debugPrint('  entrance_id: ${prefs.getString('entrance_id')}');
    
    // First check for temp session data (from End Parking button)
    final tempStartTimeStr = prefs.getString('temp_parking_start_time');
    final tempEndTimeStr = prefs.getString('temp_parking_end_time');
    final tempDurationSeconds = prefs.getInt('temp_parking_duration_seconds');
    
    if (tempStartTimeStr != null && tempEndTimeStr != null && tempDurationSeconds != null) {
      try {
        // We have temp session data, this is a completed session
        parkingStartTime = DateTime.parse(tempStartTimeStr);
        parkingEndTime = DateTime.parse(tempEndTimeStr);
        
        // Validate duration: reject if longer than 12 hours (43200 seconds)
        if (tempDurationSeconds > 43200) {
          // debugPrint('TIMEZONE FIX: Detected invalid temp duration (${tempDurationSeconds}s = ${(tempDurationSeconds/3600).toStringAsFixed(1)}h)');
          // debugPrint('TIMEZONE FIX: Recalculating duration from start/end times instead');
          
          // Recalculate duration from temp start and end times (correct way)
          final tempStart = DateTime.parse(tempStartTimeStr);
          final tempEnd = DateTime.parse(tempEndTimeStr);
          parkingDuration = tempEnd.difference(tempStart);
          isParkingActive = false;
          
          // debugPrint('TIMEZONE FIX: Corrected duration from ${(tempDurationSeconds/3600).toStringAsFixed(1)}h to ${(parkingDuration.inSeconds/3600).toStringAsFixed(1)}h');
          
          // Clear only the corrupted duration, keep other temp data
          await prefs.remove('temp_parking_duration_seconds');
        } else {
          // Use validated temp duration
          parkingDuration = Duration(seconds: tempDurationSeconds);
          isParkingActive = false;
        }
        
        // Calculate the fee (now always valid since we fixed duration above)
        parkingFee = _calculateFee(parkingDuration);
        
        // Calculate eco metrics
        estimatedCarbonSaved = parkingDuration.inMinutes * 0.012;
        estimatedTimeSaved = parkingDuration.inMinutes ~/ 3;
        
        // Now that we've loaded the data, clear active session if it exists
        await prefs.remove('parking_start_time');
        
        // Set building name and slot ID from temporary data with better fallback
        buildingName = prefs.getString('temp_selected_destination') ?? 
                      prefs.getString('temp_building_id') ?? 
                      prefs.getString('selected_destination') ?? 
                      prefs.getString('building_id') ?? 
                      'Westfield Sydney';
        
        final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                      prefs.getString('allocated_spot_id');
        if (spotId == null || spotId == 'Unknown' || spotId == 'No available spot') {
          parkingSlotId = 'Allocated Spot';
          // debugPrint('Warning: No valid parking slot ID found, using fallback');
        } else {
          parkingSlotId = spotId;
          // debugPrint('Found parking slot ID: $parkingSlotId');
        }
        setState(() {
          isLoading = false;
        });
        return;
      } catch (e) {
        // debugPrint('Error loading temp session data: $e');
        // Continue to regular session loading if temp data is invalid
      }
    }
    
    // Regular session loading (for active sessions)
    // Load parking session data from SharedPreferences
    final startTimeStr = prefs.getString('parking_start_time');
    final buildingId = prefs.getString('building_id');
    final slotId = prefs.getString('allocated_spot_id');
    
    setState(() {
      buildingName = prefs.getString('selected_destination') ?? 
                    prefs.getString('building_id') ?? 
                    'Westfield Sydney';
      
      if (slotId == null || slotId == 'Unknown' || slotId == 'No available spot') {
        parkingSlotId = 'Allocated Spot';
        // debugPrint('Warning: No valid parking slot ID found, using fallback');
      } else {
        parkingSlotId = slotId;
      }
    });
    
    if (startTimeStr != null) {
      try {
        parkingStartTime = DateTime.parse(startTimeStr);
        isParkingActive = true;
        _startDurationTimer();
      } catch (e) {
        setState(() {
          errorMessage = 'Error loading parking session: Invalid start time';
          isLoading = false;
        });
        return;
      }
    } else {
      setState(() {
        errorMessage = 'No active parking session found';
        isLoading = false;
      });
      return;
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadParkingRates() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingRatesEndpoint),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            parkingRates = data;
          });
        }
      } else {
        // Use default rates on error
        if (mounted) {
          setState(() {
            parkingRates = {
              'hourly_rate': 5.0,
              'daily_max': 25.0
            };
          });
        }
      }
    } catch (e) {
      // Use default rates on error
      if (mounted) {
        setState(() {
          parkingRates = {
            'hourly_rate': 5.0,
            'daily_max': 25.0
          };
        });
      }
    }
  }

  void _endParkingSession() async {
    // Stop the timer
    _timer?.cancel();
    
    // Set end time to now
    setState(() {
      parkingEndTime = DateTime.now();
      isParkingActive = false;
      
      // Calculate estimated carbon and time savings
      // These are placeholder calculations - adjust as needed
      estimatedCarbonSaved = parkingDuration.inMinutes * 0.012; // Example: 12g CO2 saved per minute
      estimatedTimeSaved = parkingDuration.inMinutes ~/ 3; // Example: 1/3 of parking time saved
    });
    
    // Save session end details
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parking_end_time', parkingEndTime!.toIso8601String());
    await prefs.setDouble('parking_fee', parkingFee);

    
    // Generate session ID
    final sessionId = 'PARK-${DateTime.now().millisecondsSinceEpoch}';
    
    // Show confirmation dialog with final fee
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          title: Center(
            child: Text(
              'Parking Session Ended',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber.shade600, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    'Final Fee: \$${parkingFee.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.blueGrey, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Duration: ${_formatDuration(parkingDuration)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(thickness: 1),
              const SizedBox(height: 20),
              Text(
                'Thank you for using our service!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimated Carbon Saved: ${estimatedCarbonSaved.toStringAsFixed(2)} kg CO2',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_filled, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated Time Saved: $estimatedTimeSaved minutes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      // Ensure we have slot and building info before saving
                      if (parkingSlotId == null || buildingName == null) {
                        // Load from temporary data if not already loaded
                        buildingName = prefs.getString('temp_selected_destination') ?? 
                                      prefs.getString('temp_building_id') ?? 
                                      prefs.getString('selected_destination') ?? 
                                      prefs.getString('building_id') ?? 
                                      'Unknown Location';
                        
                        final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                                      prefs.getString('allocated_spot_id');
                        parkingSlotId = spotId ?? 'Unknown';
                        
                        // debugPrint('PayNow: Loaded slot info - slot: $parkingSlotId, building: $buildingName');
                      }
                      
                      // Save to pending payments
                      final pendingPayments = prefs.getStringList('pending_payments') ?? [];
                      
                      // Create payment record
                      final paymentData = {
                        'sessionId': sessionId,
                        'amount': parkingFee,
                        'date': DateTime.now().toIso8601String(),
                        'location': buildingName ?? 'Unknown Location',
                        'slot': parkingSlotId ?? 'Unknown',
                        'duration': parkingDuration.inSeconds,
                      };

                      // debugPrint('PayNow: Saving payment - slot: $parkingSlotId, building: $buildingName');

                      final result = await _sendPayLaterToBackend(
                        amount: parkingFee,
                        slotId: parkingSlotId ?? 'Unknown',
                        sessionId: sessionId,
                        buildingName: buildingName ?? 'Unknown Location',
                        startTime: parkingStartTime ?? DateTime.now(),
                        endTime: parkingEndTime ?? DateTime.now(),
                        duration: parkingDuration,
                      );

                      // Handle result from backend
                      if (result['success'] == true) {
                        // Clear ALL session and navigation related data to completely reset state
                        await prefs.remove('temp_parking_start_time');
                        await prefs.remove('temp_parking_end_time');
                        await prefs.remove('temp_parking_duration_seconds');
                        await prefs.remove('temp_allocated_spot_id');
                        await prefs.remove('temp_building_id');
                        await prefs.remove('temp_selected_destination');
                        await prefs.remove('parking_start_time');
                        await prefs.remove('session_id');
                        await prefs.remove('allocated_spot_id');

                        // Clear navigation and map state completely
                        await prefs.setBool('has_valid_navigation', false);
                        await prefs.remove('from_dashboard_selection');
                        await prefs.remove('selected_destination');
                        await prefs.remove('target_point_id');
                        await prefs.remove('navigation_path');
                        await prefs.remove('destination_path');
                        await prefs.remove('slot_x');
                        await prefs.remove('slot_y');
                        await prefs.remove('slot_level');
                        await prefs.remove('entrance_id');
                        await prefs.remove('building_id'); // This was missing!
                        
                        // Clear reservation related data
                        await prefs.remove('selected_date');
                        await prefs.remove('selected_time');
                        await prefs.remove('selected_hours');
                        await prefs.remove('selected_minutes');
                        await prefs.remove('selected_duration_in_hours');

                        // Ensure all SharedPreferences changes are completely flushed
                        // debugPrint('Data cleanup completed, verifying...');
                        
                        // Verify critical data is cleared
                        final verifyStartTime = prefs.getString('parking_start_time');
                        final verifyEntranceId = prefs.getString('entrance_id');
                        final verifyBuildingId = prefs.getString('building_id');
                        final verifyDestination = prefs.getString('selected_destination');
                        final verifyNavigation = prefs.getBool('has_valid_navigation');
                        
                        // debugPrint('Verification - parking_start_time: $verifyStartTime');
                        // debugPrint('Verification - entrance_id: $verifyEntranceId');
                        // debugPrint('Verification - building_id: $verifyBuildingId');
                        // debugPrint('Verification - selected_destination: $verifyDestination');
                        // debugPrint('Verification - has_valid_navigation: $verifyNavigation');
                        
                        // Extra delay to ensure changes are persisted
                        await Future.delayed(const Duration(milliseconds: 200));
                        
                        // Close dialog and navigate to dashboard
                        Navigator.pop(context);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/dashboard',
                          (route) => false,
                        );
                        
                        // Show success snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Payment saved to wallet'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else {
                        // Show error message and keep dialog open
                        Navigator.pop(context); // Close only the confirmation dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Failed to save payment'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    child: const Text('Pay Later'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Ensure we have slot and building info before navigating
                      final prefs = await SharedPreferences.getInstance();
                      if (parkingSlotId == null || buildingName == null) {
                        // Load from temporary data if not already loaded
                        buildingName = prefs.getString('temp_selected_destination') ?? 
                                      prefs.getString('temp_building_id') ?? 
                                      prefs.getString('selected_destination') ?? 
                                      prefs.getString('building_id') ?? 
                                      'Unknown Location';
                        
                        final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                                      prefs.getString('allocated_spot_id');
                        parkingSlotId = spotId ?? 'Unknown';
                        
                        // debugPrint('PaymentNavDialog: Loaded slot info - slot: $parkingSlotId, building: $buildingName');
                      }
                      
                      // debugPrint('PaymentNavDialog: Navigating with - slot: $parkingSlotId, building: $buildingName');
                      
                      Navigator.pop(context);
                      // Navigate to payment screen
                      Navigator.pushNamed(
                        context, 
                        '/payment',
                        arguments: {
                          'amount': parkingFee,
                          'sessionId': sessionId,
                          'parkingLocation': buildingName ?? 'Unknown Location',
                          'parkingSlot': parkingSlotId ?? 'Unknown',
                          'parkingDate': parkingEndTime ?? DateTime.now(),
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  void _navigateToPayment() {
    // Navigate to payment screen
    // TODO: Implement payment screen navigation
    Navigator.pushNamed(context, '/dashboard');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _savePaymentToPendingList() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingPayments = prefs.getStringList('pending_payments') ?? [];

    final sessionId = 'PARK-${DateTime.now().millisecondsSinceEpoch}';

    // debugPrint('Saving payment - slot: $parkingSlotId, building: $buildingName');

    final paymentData = {
      'sessionId': sessionId,
      'amount': parkingFee,
      'date': DateTime.now().toIso8601String(),
      'location': buildingName ?? 'Unknown Location',
      'slot': parkingSlotId ?? 'Unknown',
      'duration': parkingDuration.inSeconds,
    };

    await _sendPayLaterToBackend(
      amount: parkingFee,
      slotId: parkingSlotId ?? 'Unknown',
      sessionId: sessionId,
      buildingName: buildingName ?? 'Unknown Location',
      startTime: parkingStartTime ?? DateTime.now(),
      endTime: parkingEndTime ?? DateTime.now(),
      duration: parkingDuration,
    );
    
    // Clear temporary data to prevent duplicates
    await prefs.remove('temp_parking_start_time');
    await prefs.remove('temp_parking_end_time');
    await prefs.remove('temp_parking_duration_seconds');
    
    // Log that payment was saved
    // debugPrint('Payment saved to wallet: \$${parkingFee.toStringAsFixed(2)} at ${DateTime.now()}');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('Parking Fee'),
          backgroundColor: const Color(0xFFA3DB94),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('Parking Fee'),
          backgroundColor: const Color(0xFFA3DB94),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 72,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Clear ALL session and navigation related data to completely reset state
                  final prefs = await SharedPreferences.getInstance();
                  
                  // Clear session data
                  await prefs.remove('temp_parking_start_time');
                  await prefs.remove('temp_parking_end_time');
                  await prefs.remove('temp_parking_duration_seconds');
                  await prefs.remove('temp_allocated_spot_id');
                  await prefs.remove('temp_building_id');
                  await prefs.remove('temp_selected_destination');
                  await prefs.remove('parking_start_time');
                  await prefs.remove('session_id');
                  await prefs.remove('allocated_spot_id');
                  
                  // Clear navigation and map state completely
                  await prefs.setBool('has_valid_navigation', false);
                  await prefs.remove('from_dashboard_selection');
                  await prefs.remove('selected_destination');
                  await prefs.remove('target_point_id');
                  await prefs.remove('navigation_path');
                  await prefs.remove('destination_path');
                  await prefs.remove('slot_x');
                  await prefs.remove('slot_y');
                  await prefs.remove('slot_level');
                  await prefs.remove('entrance_id');
                  await prefs.remove('building_id'); // This was missing!
                  
                  // Clear reservation related data
                  await prefs.remove('selected_date');
                  await prefs.remove('selected_time');
                  await prefs.remove('selected_hours');
                  await prefs.remove('selected_minutes');
                  await prefs.remove('selected_duration_in_hours');

                  // Ensure all SharedPreferences changes are completely flushed
                  // debugPrint('Data cleanup completed, verifying...');
                  
                  // Verify critical data is cleared
                  final verifyStartTime = prefs.getString('parking_start_time');
                  final verifyEntranceId = prefs.getString('entrance_id');
                  final verifyBuildingId = prefs.getString('building_id');
                  final verifyDestination = prefs.getString('selected_destination');
                  final verifyNavigation = prefs.getBool('has_valid_navigation');
                  
                  // debugPrint('Verification - parking_start_time: $verifyStartTime');
                  // debugPrint('Verification - entrance_id: $verifyEntranceId');
                  // debugPrint('Verification - building_id: $verifyBuildingId');
                  // debugPrint('Verification - selected_destination: $verifyDestination');
                  // debugPrint('Verification - has_valid_navigation: $verifyNavigation');
                  
                  // Extra delay to ensure changes are persisted
                  await Future.delayed(const Duration(milliseconds: 200));
                  
                  // Clear navigation history and go back to dashboard directly
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/dashboard',
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA3DB94),
                ),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    // Wrap the scaffold with WillPopScope to handle back button press
    return WillPopScope(
      onWillPop: () async {
        final canGoBack = await _handleBackNavigation();
        if (canGoBack) {
          _navigateToMainContainer();
          return false; // Prevent default pop behavior since we're using custom navigation
        }
        return false; // Stay on current screen
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('Parking Fee'),
          backgroundColor: const Color(0xFFA3DB94),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canGoBack = await _handleBackNavigation();
              if (canGoBack) {
                _navigateToMainContainer();
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buildingName ?? 'Unknown Location',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Parking Slot: $parkingSlotId',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              'Start Time: ${parkingStartTime?.hour}:${parkingStartTime?.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              'End Time: ${parkingEndTime?.hour}:${parkingEndTime?.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 15),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: ${_formatDuration(parkingDuration)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        // Clarification note only for durations under 30 minutes
                        if (parkingDuration.inMinutes < 30)
                          const Padding(
                            padding: EdgeInsets.only(top: 4.0, left: 32), // aligns with text start
                            child: Text(
                              '(Rounded up to 30 minutes minimum)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.monetization_on_outlined,
                                      color: Colors.green.shade700,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Total Fee:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '\$${parkingFee.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                    letterSpacing: -0.5,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 2.0,
                                        color: Colors.black.withOpacity(0.1),
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green.shade100),
                                  ),
                                  child: Text(
                                    'Rate: \$${(parkingRates['hourly_rate'] ?? 5.0).toStringAsFixed(2)}/hour',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Conditional action buttons - End Session or Payment Options
                if (isParkingActive) 
                  Center(
                    child: ElevatedButton(
                      onPressed: _endParkingSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'End Parking Session',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (!isParkingActive && parkingEndTime != null) 
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Session Summary Card
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Session Summary',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.eco, color: Colors.green.shade600, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Carbon Saved: ${estimatedCarbonSaved.toStringAsFixed(2)} kg',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.schedule, color: Colors.blue.shade600, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Time Saved: $estimatedTimeSaved minutes',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Payment options - 2 button options
                      const Text(
                        'Payment Options:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Generate session ID
                                final sessionId = 'PARK-${DateTime.now().millisecondsSinceEpoch}';
                                
                                // Save to pending payments
                                final prefs = await SharedPreferences.getInstance();
                                
                                // Ensure we have slot and building info before saving
                                if (parkingSlotId == null || buildingName == null) {
                                  // Load from temporary data if not already loaded
                                  buildingName = prefs.getString('temp_selected_destination') ?? 
                                                prefs.getString('temp_building_id') ?? 
                                                prefs.getString('selected_destination') ?? 
                                                prefs.getString('building_id') ?? 
                                                'Unknown Location';
                                  
                                  final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                                                prefs.getString('allocated_spot_id');
                                  parkingSlotId = spotId ?? 'Unknown';
                                  
                                  // debugPrint('PayLater: Loaded slot info - slot: $parkingSlotId, building: $buildingName');
                                }
                                
                                final pendingPayments = prefs.getStringList('pending_payments') ?? [];
                                
                                // Create payment record
                                final paymentData = {
                                  'sessionId': sessionId,
                                  'amount': parkingFee,
                                  'date': DateTime.now().toIso8601String(),
                                  'location': buildingName ?? 'Unknown Location',
                                  'slot': parkingSlotId ?? 'Unknown',
                                  'duration': parkingDuration.inSeconds,
                                };
                                
                                // debugPrint('PayLater: Saving payment - slot: $parkingSlotId, building: $buildingName');
                                
                                final result = await _sendPayLaterToBackend(
                                  amount: parkingFee,
                                  slotId: parkingSlotId ?? 'Unknown',
                                  sessionId: sessionId,
                                  buildingName: buildingName ?? 'Unknown Location',
                                  startTime: parkingStartTime ?? DateTime.now(),
                                  endTime: parkingEndTime ?? DateTime.now(),
                                  duration: parkingDuration,
                                );

                                // Handle result from backend
                                if (result['success'] == true) {
                                  // Success: Show confirmation and proceed
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message'] ?? 'Payment saved to wallet'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                } else {
                                  // Error: Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message'] ?? 'Failed to save payment'),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                  return; // Don't proceed with clearing data if payment failed
                                }
                                
                                // Clear temporary data
                                await prefs.remove('temp_parking_start_time');
                                await prefs.remove('temp_parking_end_time');
                                await prefs.remove('temp_parking_duration_seconds');
                                
                                // Navigate to dashboard
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/dashboard',
                                  (route) => false,
                                );
                                
                                // Show confirmation snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment saved to wallet'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.access_time),
                              label: const Text('Pay Later'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Ensure we have slot and building info before navigating
                                final prefs = await SharedPreferences.getInstance();
                                if (parkingSlotId == null || buildingName == null) {
                                  // Load from temporary data if not already loaded
                                  buildingName = prefs.getString('temp_selected_destination') ?? 
                                                prefs.getString('temp_building_id') ?? 
                                                prefs.getString('selected_destination') ?? 
                                                prefs.getString('building_id') ?? 
                                                'Unknown Location';
                                  
                                  final spotId = prefs.getString('temp_allocated_spot_id') ?? 
                                                prefs.getString('allocated_spot_id');
                                  parkingSlotId = spotId ?? 'Unknown';
                                  
                                  // debugPrint('PaymentNav: Loaded slot info - slot: $parkingSlotId, building: $buildingName');
                                }
                                
                                // Generate session ID
                                final sessionId = 'PARK-${DateTime.now().millisecondsSinceEpoch}';
                                
                                // debugPrint('PaymentNav: Navigating with - slot: $parkingSlotId, building: $buildingName');
                                
                                // Navigate to payment screen
                                Navigator.pushNamed(
                                  context, 
                                  '/payment',
                                  arguments: {
                                    'amount': parkingFee,
                                    'sessionId': sessionId,
                                    'parkingLocation': buildingName ?? 'Unknown Location',
                                    'parkingSlot': parkingSlotId ?? 'Unknown',
                                    'parkingDate': parkingEndTime ?? DateTime.now(),
                                  },
                                );
                              },
                              icon: const Icon(Icons.payment),
                              label: const Text('Pay Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
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
