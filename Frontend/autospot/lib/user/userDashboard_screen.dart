import 'package:autospot/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/main_container.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:autospot/main.dart';
import 'package:flutter/foundation.dart';

// Dashboard screen for planning parking, checking active sessions, and navigating to maps.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedDestination;
  int selectedHours = 0;
  int selectedMinutes = 0;
  double selectedDurationInHours = 0.0;
  bool _destinationError = false;

  double balance = 0.0;
  List<String> savedCards = [];
  List<Map<String, dynamic>> pendingPayments = [];
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  
  // Active parking session variables
  bool hasActiveSession = false;
  String? sessionId;
  DateTime? sessionStartTime;
  String? allocatedSlotId;
  Duration sessionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkActiveSession();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _checkProfileCompletion();
  }

  @override
  void didPopNext() {
    _checkProfileCompletion();
  }

  // Fetch and store user profile data. If incomplete, prompt user.
  Future<void> _checkProfileCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');

    if (email == null) return;

    try {
      final response = await http.get(
          Uri.parse("${ApiConfig.getUserProfileEndpoint}?email=$email"),
          headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final username = data['username'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);

        final phoneNumber = data['phone_number'];
        final licensePlate = data['license_plate'];

        if (phoneNumber == null || phoneNumber.isEmpty || licensePlate == null || licensePlate.isEmpty) {
          _showProfileIncompleteDialog();
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('phone_number', phoneNumber);
          await prefs.setString('vehicle_id', licensePlate);
        }
      } else {
        // debugPrint('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Error fetching profile: $e');
    }
  }

  // Format a Duration as HH:mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Timer? _sessionTimer;
  
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionStartTime != null && mounted) {
        setState(() {
          sessionDuration = DateTime.now().difference(sessionStartTime!);
        });
      }
    });
  }

  // Check for active parking session
  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();

    final storedSessionId = prefs.getString('session_id');
    final storedStartTime = prefs.getString('parking_start_time');
    final storedSlotId = prefs.getString('allocated_spot_id');

    if (storedSessionId != null && storedStartTime != null) {
      final startTime = DateTime.tryParse(storedStartTime);
      if (startTime != null) {
        setState(() {
          hasActiveSession = true;
          sessionId = storedSessionId;
          sessionStartTime = startTime;
          allocatedSlotId = storedSlotId;
          sessionDuration = DateTime.now().difference(startTime);
        });
        if (kDebugMode) {
          // debugPrint('Dashboard: Active session detected - Slot: ${allocatedSlotId ?? "Unknown"}, Duration: ${_formatDuration(sessionDuration)}');
        }
        _startSessionTimer();
        return;
      }
    }

    // Fallback: try fetching from API if nothing found locally
    await _checkActiveSessionAndStore(); // Uses endpoint

    // Try again after attempting restore
    final updatedSessionId = prefs.getString('session_id');
    final updatedStartTime = prefs.getString('parking_start_time');
    final updatedSlotId = prefs.getString('allocated_spot_id');

    if (updatedSessionId != null && updatedStartTime != null) {
      final parsedStartTime = DateTime.tryParse(updatedStartTime);
      if (parsedStartTime != null) {
        setState(() {
          hasActiveSession = true;
          sessionId = updatedSessionId;
          sessionStartTime = parsedStartTime;
          allocatedSlotId = updatedSlotId;
          sessionDuration = DateTime.now().difference(parsedStartTime);
        });
        _startSessionTimer();

        if (kDebugMode) {
          // debugPrint('Dashboard: Active session detected - Slot: ${updatedSlotId ?? "Unknown"}, Duration: ${_formatDuration(sessionDuration)}');
        }
      }
    }
  }

  // Fallback to fetch session from /session/active
  Future<void> _checkActiveSessionAndStore() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');

    if (username == null || vehicleId == null) return;

    final uri = Uri.parse('${ApiConfig.baseUrl}/session/active?username=$username&vehicle_id=$vehicleId');

    try {
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final session = jsonData['session'];

        await prefs.setString('session_id', session['session_id']);
        await prefs.setString('allocated_spot_id', session['slot_id']);
        await prefs.setString('vehicle_id', session['vehicle_id']);
        await prefs.setString('parking_start_time', session['start_time']);
        // debugPrint('Active session restored!');
      } else {
        // debugPrint('No active session found or not 200!');
        await prefs.remove('session_id');
        await prefs.remove('parking_start_time');
        await prefs.remove('allocated_spot_id');
      }
    } catch (e) {
      // debugPrint('Error fetching active session: $e');
    }

    if (hasActiveSession && sessionStartTime != null && mounted) {
    Future.microtask(() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        ),
      );
    });
    }
  }

  // Only Westfield Sydney has actual map data in our current example
  final collaboratingPlaces = [
    'Westfield Sydney (Example)',
  ];

  final int _selectedIndex = 0;

  // Opens a date picker dialog
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // Opens a time picker dialog
  Future<void> _pickTime() async {
    final TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => selectedTime = picked);
  }

  // Opens a dialog to select parking duration
  Future<void> _pickDuration() async {
    int hours = 0;
    int minutes = 0;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Duration"),
          content: Row(
            children: [
              Expanded(
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hours'),
                  onChanged: (value) => hours = int.tryParse(value) ?? 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                  onChanged: (value) => minutes = int.tryParse(value) ?? 0,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  selectedHours = hours;
                  selectedMinutes = minutes;
                  selectedDurationInHours = hours + (minutes / 60);
                });
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Opens bottom sheet to pick a destination
  void _showDestinationPicker() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User already has active session'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return; // Block the picker
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F6FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 0,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Select Destination',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1),
              // List of places
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: collaboratingPlaces.length,
                  itemBuilder: (context, index) {
                    final place = collaboratingPlaces[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA3DB94).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.store, // Changed from shopping_mall to store
                            color: const Color(0xFF68B245),
                            size: 24,
                          ),
                        ),
                        title: Text(
                          place,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: place.contains('Example')
                            ? const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Demo location with available parking data',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.black54,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          setState(() {
                            selectedDestination = place;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Format date for UI
  String formatDate(DateTime? date) =>
      date == null ? '' : "${date.day}/${date.month}/${date.year}";

  // Format time for UI
  String formatTime(TimeOfDay? time) => time == null ? '' : time.format(context);

  // Consistent input field style
  InputDecoration _inputStyle(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),  // Lower opacity to show gradient background
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 2.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 2.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2.5),
      ),
    );
  }

  // Alert dialog shown if profile is incomplete
  void _showProfileIncompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button closing
          child: AlertDialog(
            title: const Text('Profile Incomplete'),
            content: const Text(
              'You must complete your profile before using the system.\n\n'
              'Please update your license plate and phone number.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  MainNavigator.navigateToTab(context, 5); // Or wherever the update screen is
                },
                child: const Text('Go to Profile'),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'AutoSpot',
          style: TextStyle(
            color: Colors.black, 
            fontSize: 28, 
            fontWeight: FontWeight.bold,
          ),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dashboard title
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA3DB94),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dashboard_rounded,
                        size: 20,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form container
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE5EFDF),  // Darker light green shade
                        const Color(0xFFD9E7D3),  // Darker medium transition color
                        const Color(0xFFCFE2C7),  // Darker deep green closer to background
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA3DB94),
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section heading
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Plan Your Parking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),

                      // Destination
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          'Destination',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextFormField(
                        readOnly: true,
                        onTap: _showDestinationPicker,
                        controller: TextEditingController(text: selectedDestination ?? ''),
                        decoration: _inputStyle('Select Destination').copyWith(
                          prefixIcon: const Icon(Icons.location_on, size: 20),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _destinationError ? Colors.red : const Color(0xFFA3DB94),
                              width: 2.0, // Increase border width to match other fields
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _destinationError ? Colors.red : Colors.green,
                              width: 2.5, // Increase border width to match other fields
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      const SizedBox(height: 12),

                      // Date
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextFormField(
                        readOnly: true,
                        onTap: _pickDate,
                        controller: TextEditingController(text: formatDate(selectedDate)),
                        decoration: _inputStyle('Date (Optional)').copyWith(
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          suffixIcon: selectedDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      selectedDate = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      const SizedBox(height: 12),

                      // Start Time
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      TextFormField(
                        readOnly: true,
                        onTap: _pickTime,
                        controller: TextEditingController(text: formatTime(selectedTime)),
                        decoration: _inputStyle('Start Time (Optional)').copyWith(
                          prefixIcon: const Icon(Icons.access_time, size: 20),
                          suffixIcon: selectedTime != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      selectedTime = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      const SizedBox(height: 12),

                      // Duration
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickDuration,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: TextEditingController(
                              text: selectedDurationInHours == 0.0
                                  ? ''
                                  : '${selectedDurationInHours.toStringAsFixed(2)} hour '
                                    '($selectedHours hour${selectedHours != 1 ? 's' : ''}'
                                    '${selectedMinutes > 0 ? ' and $selectedMinutes minute${selectedMinutes != 1 ? 's' : ''}' : ''})',
                            ),
                            decoration: _inputStyle('Duration (Optional, in hours)').copyWith(
                              prefixIcon: const Icon(Icons.timer, size: 20),
                            ),
                            style: const TextStyle(fontSize: 14, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (selectedDestination == null || selectedDestination!.isEmpty) {
                        setState(() {
                          _destinationError = true;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a destination.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      } else {
                        setState(() {
                          _destinationError = false;
                        });
                      }

                      final prefs = await SharedPreferences.getInstance();

                      // Save selectedDestination
                      await prefs.setString('selected_destination', selectedDestination!);

                      final now = DateTime.now();

                      // Save selectedDate as "YYYY-MM-DD"
                      final dateToUse = selectedDate ?? now;
                      final dateStr = '${dateToUse.year.toString().padLeft(4, '0')}-'
                                      '${dateToUse.month.toString().padLeft(2, '0')}-'
                                      '${dateToUse.day.toString().padLeft(2, '0')}';
                      await prefs.setString('selected_date', dateStr);

                      // Save selectedTime as 24-hour format "HH:mm"
                      final timeToUse = selectedTime ?? TimeOfDay(hour: now.hour, minute: now.minute);
                      final timeStr = '${timeToUse.hour.toString().padLeft(2, '0')}:'
                                      '${timeToUse.minute.toString().padLeft(2, '0')}';
                      await prefs.setString('selected_time', timeStr);

                      // Save duration components
                      await prefs.setInt('selected_hours', selectedHours);
                      await prefs.setInt('selected_minutes', selectedMinutes);
                      await prefs.setDouble('selected_duration_in_hours', selectedDurationInHours);
                      
                      // Set flags to indicate valid navigation and bypass initial screen
                      await prefs.setBool('from_dashboard_selection', true);
                      await prefs.setBool('has_valid_navigation', true);
                      
                      // Navigate to the map-only screen which will handle both example and API maps
                      Navigator.pushReplacementNamed(context, '/map-only');
                    },

                    icon: const Icon(Icons.search, color: Colors.black87, size: 18),
                    label: const Text(
                      'Check Space',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.black87,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA3DB94),
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFF8BC474),
                          width: 2.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
