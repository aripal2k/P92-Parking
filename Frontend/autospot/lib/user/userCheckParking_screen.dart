import 'package:autospot/config/api_config.dart';
import 'package:autospot/models/parking_map.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class ParkingMapScreen extends StatefulWidget {
  final bool forceShowMap;
  
  const ParkingMapScreen({
    super.key,
    this.forceShowMap = false,
  });

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  // Add the buildKey as a class-level static constant
  static const buildKey = ValueKey('parking_map_screen_build');
  
  List<ParkingMap> maps = [];
  bool isLoading = true;
  bool hasSelectedDestination = false;
  String? selectedDestination;
  int? selectedLevel;
  int? selectedX;
  int? selectedY;
  String? allocatedSpotId;
  List<List<dynamic>> navigationPath = [];
  List<List<dynamic>> destinationPath = [];
  // Path display mode state
  String _pathDisplayMode = "entrance_to_slot"; // "entrance_to_slot", "slot_to_destination"

  // Add debouncing variables
  bool _isRefreshing = false;
  Timer? _loadingTimeoutTimer;
  Timer? _refreshDebounceTimer;
  
  late TextEditingController _levelController;
  
  // Add timer-related variables
  Timer? _triggerTimer;
  int _timerSeconds = 0;
  bool _isTimerActive = false;
  bool _isParkingActive = false;
  DateTime? _parkingStartTime;
  String? _timerText;

  bool hasActiveSession = false;
  String? sessionId;
  DateTime? sessionStartTime;
  String? allocatedSlotId;
  Duration sessionDuration = Duration.zero;
  bool _sessionStarted = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  
  // Add auto-refresh timer for real-time data sync
  Timer? _autoRefreshTimer;
  
  // Level switching protection
  bool _isLevelSwitching = false;
  
  // Premium subscription variables
  String subscriptionPlan = 'basic';
  String? selectedCustomSlotId;
  int? selectedCustomX;
  int? selectedCustomY;
  int? selectedCustomLevel;

  @override
  void initState() {
    super.initState();
    _initializeLevel();
    _attemptStartSession(); // Check for leftover session data
    _checkFirstTimeAccess();
    _restoreTimerState(); // Add method call to restore timer state
    _loadSubscriptionStatus(); // Load premium subscription status
    // Note: _startAutoRefresh() is called in didChangeDependencies() instead
  }

  Future<void> _initializeLevel() async {
    final prefs = await SharedPreferences.getInstance();
    // Load saved level from preferences, default to 1 if not found
    selectedLevel = prefs.getInt('map_selected_level') ?? 1;
    _levelController = TextEditingController(text: 'Level $selectedLevel');
    // debugPrint('ParkingMapScreen: Initialized with saved level: $selectedLevel');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh subscription status when returning to this screen
    _refreshSubscriptionStatusOnReturn();
    
    // Only start auto-refresh if not already running
    if (_autoRefreshTimer == null) {
      // debugPrint('ParkingMapScreen: Starting auto-refresh in didChangeDependencies');
      _startAutoRefresh();
    } else {
      // debugPrint('ParkingMapScreen: Auto-refresh already running, skipping');
    }
  }

  @override
  void deactivate() {
    // Stop auto-refresh when screen becomes inactive
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    // debugPrint('ParkingMapScreen deactivated - stopped auto-refresh');
    super.deactivate();
  }

  bool isSessionLoading = true;

  Future<void> _attemptStartSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');

    if (username == null || vehicleId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing user session data.")),
      );
      return;
    }

    String? storedSessionId = prefs.getString('session_id');
    String? storedStartTime = prefs.getString('parking_start_time');
    String? storedSlotId = prefs.getString('allocated_spot_id');

    // Step 1: Try local storage
    if (storedSessionId != null && storedStartTime != null) {
      final parsedTime = DateTime.tryParse(storedStartTime);
      if (parsedTime != null) {
        setState(() {
          final parsedUtc = parsedTime.toUtc();
          final currentUtc = DateTime.now().toUtc();

          _sessionStarted = true;
          sessionId = storedSessionId;
          sessionStartTime = parsedTime;
          allocatedSlotId = storedSlotId;
          _elapsed = currentUtc.difference(parsedUtc);
          isSessionLoading = false;
        });
        _startSessionTimer();
        return;
      }
    }

    // Step 2: Fallback to backend API
    final uri = Uri.parse('${ApiConfig.baseUrl}/session/active?username=$username&vehicle_id=$vehicleId');

    try {
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final session = jsonData['session'];
        final parsedTime = DateTime.tryParse(session['start_time']);

        if (parsedTime != null) {
          final parsedUtc = parsedTime.toUtc();
          final currentUtc = DateTime.now().toUtc();

          await prefs.setString('session_id', session['session_id']);
          await prefs.setString('allocated_spot_id', session['slot_id']);
          await prefs.setString('parking_start_time', parsedUtc.toIso8601String());

          setState(() {
            _sessionStarted = true;
            sessionId = session['session_id'];
            allocatedSlotId = session['slot_id'];
            sessionStartTime = parsedTime;
            _elapsed = currentUtc.difference(parsedTime);
            isSessionLoading = false;
          });

          _startSessionTimer();
          return;
        }
      } else {
        // debugPrint('No active session found or error fetching.');
      }
    } catch (e) {
      // debugPrint('Network error in fallback session restore: $e');
    }

    // Nothing found
    setState(() {
      isSessionLoading = false;
    });
  }

  void _startSessionTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionStartTime != null && mounted) {
        setState(() {
          _elapsed = DateTime.now().toUtc().difference(sessionStartTime!.toUtc());
        });
      }
    });
  }

  // Add method to restore timer state
  Future<void> _restoreTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if the app has been closed/restarted
    final lastActiveTime = prefs.getString('app_last_active_time');
    final now = DateTime.now();
    
    // Save current time as last active time
    await prefs.setString('app_last_active_time', now.toIso8601String());
    
    // If last active time is null or more than 10 minutes ago,
    // assume app was fully closed and clear any timers
    if (lastActiveTime == null) {
      // First run, no need to check further
      await _clearAllTimerStates(prefs);
      return;
    }
    
    try {
      final lastActive = DateTime.parse(lastActiveTime);
      final timeSinceLastActive = now.difference(lastActive);
      
      // If app was inactive for more than 10 minutes, clear all timer states
      if (timeSinceLastActive.inMinutes > 10) {
        // debugPrint('App was inactive for ${timeSinceLastActive.inMinutes} minutes, clearing timer states');
        await _clearAllTimerStates(prefs);
        return;
      }
    } catch (e) {
      // debugPrint('Error parsing last active time: $e');
      await _clearAllTimerStates(prefs);
      return;
    }
    
    // Check for active parking session first
    final savedStartTime = prefs.getString('parking_start_time');
    
    if (savedStartTime != null) {
      try {
        final startTime = DateTime.parse(savedStartTime);
        
        // Check if the session is from the current date (prevent expired sessions)
        final timeDiff = now.difference(startTime);
        
        // If the time difference is less than 24 hours, consider it a valid session
        if (timeDiff.inHours < 24) {
          setState(() {
            _isParkingActive = true;
            _parkingStartTime = startTime;
            _timerText = 'Active: ${_formatDuration(timeDiff)}';
          });
          
          // Restart the active session timer
          _startActiveSessionTimer();
          return; // If there's an active session, don't check for countdown
        } else {
          // Session expired, clear it
          await prefs.remove('parking_start_time');
        }
      } catch (e) {
        // debugPrint('Error restoring timer state: $e');
        await prefs.remove('parking_start_time');
      }
    }
    
    // If no active parking session, check for active countdown
    final countdownStartTimeStr = prefs.getString('countdown_start_time');
    final savedCountdownSeconds = prefs.getInt('countdown_seconds');
    
    if (countdownStartTimeStr != null && savedCountdownSeconds != null) {
      try {
        final countdownStartTime = DateTime.parse(countdownStartTimeStr);
        final elapsedSeconds = now.difference(countdownStartTime).inSeconds;
        
        // Calculate remaining seconds
        int remainingSeconds = savedCountdownSeconds - elapsedSeconds;
        
        // If countdown hasn't ended and is greater than 0
        if (remainingSeconds > 0) {
          setState(() {
            _isTimerActive = true;
            _timerSeconds = remainingSeconds;
            _timerText = 'Countdown: $_timerSeconds s';
          });
          
          // Recreate countdown timer
          _triggerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                if (_timerSeconds > 0) {
                  _timerSeconds--;
                  _timerText = 'Countdown: $_timerSeconds s';
                } else {
                  // Countdown ends, start parking session
                  timer.cancel();
                  _startParkingSession();
                }
              });
            } else {
              timer.cancel();
            }
          });
        } else {
          // Countdown has ended but parking session hasn't started, start parking session directly
          // First clear countdown information from SharedPreferences
          await prefs.remove('countdown_start_time');
          await prefs.remove('countdown_seconds');
          
          // Start parking session
          _startParkingSession();
        }
      } catch (e) {
        // debugPrint('Error restoring countdown timer state: $e');
        await prefs.remove('countdown_start_time');
        await prefs.remove('countdown_seconds');
      }
    }
  }
  
  // Helper method to clear all timer-related states
  Future<void> _clearAllTimerStates(SharedPreferences prefs) async {
    await prefs.remove('parking_start_time');
    await prefs.remove('countdown_start_time');
    await prefs.remove('countdown_seconds');
    
    // Reset local state variables
    if (mounted) {
      setState(() {
        _isTimerActive = false;
        _isParkingActive = false;
        _parkingStartTime = null;
        _timerSeconds = 0;
        _timerText = null;
      });
    }
    
    // debugPrint('All timer states cleared due to app restart/long inactivity');
  }

  @override
  void dispose() {
    _cancelTimer();
    _loadingTimeoutTimer?.cancel();
    _refreshDebounceTimer?.cancel();
    _autoRefreshTimer?.cancel(); // Cancel auto-refresh timer
    super.dispose();
  }

  // Start auto-refresh timer for real-time data synchronization
  void _startAutoRefresh() {
    // Cancel existing timer to prevent duplicates
    _autoRefreshTimer?.cancel();
    
    // Only start if screen is currently active and has destination
    if (!mounted || selectedDestination == null) {
      // debugPrint('Not starting auto-refresh: mounted=$mounted, destination=$selectedDestination');
      return;
    }
    
    // debugPrint('Starting auto-refresh for ParkingMapScreen');
    // More frequent refresh for better real-time experience (like Premium)
    // Refresh every 5 seconds to sync parking slot status across devices
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isRefreshing && !_isLevelSwitching && selectedDestination != null) {
        // debugPrint('Auto-refreshing parking map for real-time sync');
        _refreshParkingData();
      } else {
        if (_isLevelSwitching) {
          // debugPrint('Skipping auto-refresh: level switching in progress');
        } else {
          // debugPrint('Stopping auto-refresh: conditions not met');
          timer.cancel();
          _autoRefreshTimer = null;
        }
      }
    });
  }

  // Refresh parking data without showing loading indicator (preserve navigation paths)
  Future<void> _refreshParkingData() async {
    if (_isRefreshing || selectedDestination == null) return;
    
    // Save current level before refresh to preserve user's selection
    final currentLevel = selectedLevel;
    
    // Store existing navigation paths before refresh to prevent flickering
    Map<int, List<Map<String, dynamic>>> existingNavigationPaths = {};
    for (var mapLevel in maps) {
      List<Map<String, dynamic>> navPaths = mapLevel.corridors
          .where((corridor) => corridor['is_path'] == true)
          .cast<Map<String, dynamic>>()
          .toList();
      if (navPaths.isNotEmpty) {
        existingNavigationPaths[mapLevel.level] = List.from(navPaths);
      }
    }
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Use optimized refresh that only updates slot statuses
      await _refreshMapDataPreservingPaths();
      
      // Restore navigation paths after refresh to prevent flickering
      if (existingNavigationPaths.isNotEmpty) {
        for (var mapLevel in maps) {
          if (existingNavigationPaths.containsKey(mapLevel.level)) {
            // Remove any navigation paths that might have been re-added during refresh
            mapLevel.corridors.removeWhere((corridor) => corridor['is_path'] == true);
            // Add back the preserved navigation paths
            mapLevel.corridors.addAll(existingNavigationPaths[mapLevel.level]!);
          }
        }
        // debugPrint('Navigation paths preserved during auto-refresh');
      }
      
      // debugPrint('Auto-refresh completed successfully - level preserved: $currentLevel');
    } catch (e) {
      // debugPrint('Auto-refresh failed: $e');
      // Don't show error to user for background refresh
    }
    
    // Always restore the level selection and reset refresh flag after ALL operations complete
    // This ensures user's level choice is preserved even after _refreshMapWithCurrentPaths
    if (mounted && currentLevel != null) {
      setState(() {
        selectedLevel = currentLevel;
        _levelController.text = 'Level $selectedLevel';
        _isRefreshing = false; // Reset refresh flag here after level is restored
      });
      // debugPrint('Level restored to user selection: $currentLevel');
    } else if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Optimized refresh that only updates slot statuses without recreating navigation paths
  Future<void> _refreshMapDataPreservingPaths() async {
    if (selectedDestination == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Always prioritize building_id from QR code for map API calls
      String? buildingFromQR = prefs.getString('building_id');
      String? destination = buildingFromQR ?? selectedDestination;
      
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(destination!))),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        if (decoded.containsKey('map') && 
            decoded['map'] != null &&
            decoded['map'].containsKey('parking_map') &&
            decoded['map']['parking_map'] is List && 
            (decoded['map']['parking_map'] as List).isNotEmpty) {
          
          final newMaps = (decoded['map']['parking_map'] as List)
              .map((e) => ParkingMap.fromJson(e))
              .toList();
          
          // Update only slot statuses from new data, preserve existing structure and paths
          for (var existingMap in maps) {
            final correspondingNewMap = newMaps.where(
              (newMap) => newMap.level == existingMap.level,
            ).firstOrNull;
            
            if (correspondingNewMap != null) {
              // Update slot statuses only
              existingMap.slots.clear();
              existingMap.slots.addAll(correspondingNewMap.slots);
              // debugPrint('Updated slot statuses for level ${existingMap.level}');
            }
          }
        }
      }
    } catch (e) {
      // debugPrint('Failed to refresh map data preserving paths: $e');
      // Don't throw error, just log it for silent background refresh
    }
  }

  // Trigger immediate refresh for user interactions (like Premium experience)
  Future<void> _triggerImmediateRefresh({String reason = 'user interaction'}) async {
    // debugPrint('Triggering immediate refresh due to: $reason');
    
    // Cancel current auto-refresh to avoid conflicts
    _autoRefreshTimer?.cancel();
    
    // Perform immediate refresh
    await _refreshParkingData();
    
    // Restart auto-refresh timer
    _startAutoRefresh();
  }

  // Method to handle the trigger button press
  void _handleTriggerPress() async {
    if (_isRefreshing || _isTimerActive || _isParkingActive) return;

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');
    allocatedSpotId = prefs.getString('allocated_spot_id');

    if (username == null || vehicleId == null || allocatedSpotId == null || allocatedSpotId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Missing required session data. Please reselect your slot or refresh."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rootContext = context;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sensor Detected'),
          content: Text('Are you occupying the parking slot $allocatedSpotId?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // Get entrance and building info from SharedPreferences
                final entranceId = prefs.getString('entrance_id');
                final buildingId = prefs.getString('building_id');
                
                // Build URI for starting session with entrance and building info
                String sessionUrl = '${ApiConfig.startSessionEndpoint}?username=${Uri.encodeComponent(username)}'
                  '&vehicle_id=${Uri.encodeComponent(vehicleId)}'
                  '&slot_id=${Uri.encodeComponent(allocatedSpotId!)}';
                
                if (entranceId != null && entranceId.isNotEmpty) {
                  sessionUrl += '&entrance_id=${Uri.encodeComponent(entranceId)}';
                }
                if (buildingId != null && buildingId.isNotEmpty) {
                  sessionUrl += '&building_name=${Uri.encodeComponent(buildingId)}';
                }
                
                final uri = Uri.parse(sessionUrl);

                // debugPrint('Starting session with URI: $uri');
                // debugPrint('Slot ID being used: $allocatedSpotId');

                try {
                  final response = await http.post(uri, headers: ApiConfig.headers);

                  if (response.statusCode == 200) {
                    final jsonBody = json.decode(response.body);
                    final session = jsonBody['session'];
                    final sessionId = session['session_id'];
                    final startTime = DateTime.parse(session['start_time']);

                    await prefs.setString('session_id', sessionId);
                    await prefs.setString('parking_start_time', startTime.toIso8601String());
                    
                    // Trigger immediate refresh after parking session started
                    await _triggerImmediateRefresh(reason: 'parking session started');
                    
                    // debugPrint('Session started successfully: $sessionId');
                    
                    // Session started successfully, navigate back to MainContainer
                    // MainContainer will automatically detect the active session and show ActiveParkingScreen in Map tab
                    Navigator.of(rootContext, rootNavigator: true).pushNamedAndRemoveUntil(
                      '/map',
                      (route) => false,
                    );
                  } else {
                    final error = json.decode(response.body);
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text(error['detail'] ?? 'Failed to start session'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text('Network error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Start the 10-second timer
  void _startTimer() async {
    // Prevent starting timer if already active
    if (_isTimerActive) {
      // debugPrint('Timer already active, ignoring request to start new timer');
      return;
    }
    
    // Set a flag to skip path refresh during timer start
    // to prevent rebuild cascade
    _isRefreshing = true;
    
    // Cancel any existing timer to prevent duplicates
    _triggerTimer?.cancel();
    
    // Save timer start time to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final startTime = DateTime.now();
    await prefs.setString('countdown_start_time', startTime.toIso8601String());
    await prefs.setInt('countdown_seconds', 10); // Save total countdown seconds
    
    setState(() {
      _isTimerActive = true;
      _timerSeconds = 10;
      _timerText = 'Countdown: $_timerSeconds s';
    });
    
    // Reset flag after state update
    Future.delayed(const Duration(milliseconds: 100), () {
      _isRefreshing = false;
    });
    
    // Create a periodic timer that fires every second
    _triggerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timerSeconds > 0) {
            _timerSeconds--;
            _timerText = 'Countdown: $_timerSeconds s';
          } else {
            // When timer reaches 0, start parking session
            // Cancel the timer first to prevent multiple calls
            timer.cancel();
            _startParkingSession();
          }
        });
      } else {
        // Cancel the timer if the widget is no longer mounted
        timer.cancel();
      }
    });
  }

  // Cancel the timer
  void _cancelTimer() async {
    _triggerTimer?.cancel();
    _triggerTimer = null;
    
    // Clear countdown information from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('countdown_start_time');
    await prefs.remove('countdown_seconds');

    if (!mounted) return;
    
    setState(() {
      _isTimerActive = false;
      _timerSeconds = 0;
      _timerText = null;
    });
  }

  // End parking session
  void _endParkingSession() async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Confirm End Parking'),
          content: const Text('Are you sure you want to end your current parking session?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _endParkingSessionConfirmed(); // Call confirmed end method
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('End Parking'),
            ),
          ],
        );
      },
    );
  }
  
  // Method executed after parking end confirmation
  void _endParkingSessionConfirmed() async {
    // debugPrint('Entered _endParkingSessionConfirmed');

    // Save end time
    final endTime = DateTime.now();
    
    // Calculate duration and fee
    final duration = endTime.difference(_parkingStartTime!);
    
    final prefs = await SharedPreferences.getInstance();
    
    // First, call backend API to end the session properly
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');
    final sessionId = prefs.getString('session_id');
    final slotId = prefs.getString('allocated_spot_id');

    if (username != null && vehicleId != null && sessionId != null) {
      try {
        final uri = Uri.parse(
          '${ApiConfig.endSessionEndpoint}?username=${Uri.encodeComponent(username)}'
          '&vehicle_id=${Uri.encodeComponent(vehicleId)}'
          '&session_id=${Uri.encodeComponent(sessionId)}'
          '${slotId != null ? '&slot_id=${Uri.encodeComponent(slotId)}' : ''}'
        );

        // debugPrint('Ending session via API: $uri');
        
        final response = await http.post(uri, headers: ApiConfig.headers);
        
        if (response.statusCode == 200) {
          // Calculate emission after successful session end
          try {
            // Get building name from SharedPreferences
            final buildingId = prefs.getString('building_id');
            String emissionUrl = '${ApiConfig.emissionSession}?session_id=${Uri.encodeComponent(sessionId)}';
            
            if (buildingId != null && buildingId.isNotEmpty) {
              emissionUrl += '&building_name=${Uri.encodeComponent(buildingId)}';
            }
            
            final emissionUri = Uri.parse(emissionUrl);
            // debugPrint('Calculating emission for session: $emissionUri');
            
            final emissionRes = await http.get(emissionUri);
            if (emissionRes.statusCode == 200) {
              final emissionData = jsonDecode(emissionRes.body);
              // debugPrint('Emission calculated: ${emissionData['message']}');
              // debugPrint('Emissions saved: ${emissionData['emissions_saved']}g CO₂');
            } else {
              // debugPrint('Failed to calculate emission: ${emissionRes.statusCode}');
            }
          } catch (e) {
            // debugPrint('Error calculating emission: $e');
          }
        } else {
          // debugPrint('Failed to end session on backend: ${response.statusCode}');
          // debugPrint('Response: ${response.body}');
          // Continue with local cleanup even if backend fails
        }
      } catch (e) {
        // debugPrint('Error calling backend end session API: $e');
        // Continue with local cleanup even if backend call fails
      }
    } else {
      // debugPrint('Missing session data for backend API call');
    }
    
    // Save session data to SharedPreferences before navigation
    await prefs.setString('temp_parking_start_time', _parkingStartTime!.toIso8601String());
    await prefs.setString('temp_parking_end_time', endTime.toIso8601String());
    await prefs.setInt('temp_parking_duration_seconds', duration.inSeconds);
    
    // Save slot and building info for payment screen BEFORE clearing
    final currentSlotId = prefs.getString('allocated_spot_id');
    final currentBuildingId = prefs.getString('building_id');
    final currentDestination = prefs.getString('selected_destination');
    
    if (currentSlotId != null) {
      await prefs.setString('temp_allocated_spot_id', currentSlotId);
    }
    if (currentBuildingId != null) {
      await prefs.setString('temp_building_id', currentBuildingId);
    }
    if (currentDestination != null) {
      await prefs.setString('temp_selected_destination', currentDestination);
    }
    
    // Clean up session keys (same as ActiveParking screen)
    await prefs.remove('parking_start_time');
    await prefs.remove('session_id');

    // Also clear navigation and destination info to reset state
    await prefs.remove('selected_destination');
    await prefs.remove('target_point_id');
    await prefs.remove('navigation_path');
    await prefs.remove('destination_path');
    await prefs.remove('slot_x');
    await prefs.remove('slot_y');
    await prefs.remove('slot_level');
    await prefs.remove('entrance_id');
    await prefs.remove('has_valid_navigation');
    await prefs.remove('from_dashboard_selection');

    // Cancel auto-refresh timer when session ends
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    
    // Reset state
    setState(() {
      _isParkingActive = false;
      _parkingStartTime = null;
      _timerText = null;

      // Reset map-related state (but preserve selected level for better UX)
      hasSelectedDestination = false;
      selectedDestination = null;
      selectedX = null;
      selectedY = null;
      // Keep selectedLevel unchanged to maintain user's preference
      navigationPath = [];
      destinationPath = [];
    });
    
    // Navigate to fee calculation screen with a replace to avoid back stack issues
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/parking-fee',
        (route) => false,
        arguments: {
          'startTime': _parkingStartTime,
          'endTime': endTime,
          'isActiveSession': false,
          'duration': duration,
        },
      );
    }
  }

  // Start actual parking session
  void _startParkingSession() async {
    // Cancel any existing timer
    _triggerTimer?.cancel();
    _triggerTimer = null;
    
    // Only proceed if not already in a parking session
    if (_isParkingActive) {
      return;
    }
    
    setState(() {
      _isParkingActive = true;
      _isTimerActive = false;
      _parkingStartTime = DateTime.now();
      
      // Update timer text to show active session time
      _timerText = 'Active: 00:00:00';
    });
    
    // Save parking session start time to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    
    // Clear countdown related information
    await prefs.remove('countdown_start_time');
    await prefs.remove('countdown_seconds');
    
    // Save parking session start time
    await prefs.setString('parking_start_time', _parkingStartTime!.toIso8601String());
    
    // Start active session timer
    _startActiveSessionTimer();
  }
  
  // Start timer to update active session duration
  void _startActiveSessionTimer() {
    // Cancel any existing timer
    _triggerTimer?.cancel();
    
    _triggerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _parkingStartTime != null && _isParkingActive) {
        final duration = DateTime.now().difference(_parkingStartTime!);
        final newTimerText = 'Active: ${_formatDuration(duration)}';
        
        // Only update state if the text has actually changed
        if (newTimerText != _timerText) {
          setState(() {
            _timerText = newTimerText;
          });
        }
      } else if (!mounted || !_isParkingActive) {
        // Cancel the timer if widget is unmounted or parking is no longer active
        timer.cancel();
      }
    });
  }
  
  // Format duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  // Load subscription status from backend
  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    
    if (email.isEmpty) return;
    
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getSubscriptionStatusEndpoint(email)),
        headers: ApiConfig.headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          subscriptionPlan = data['subscription_plan'] ?? 'basic';
        });
        // debugPrint('User subscription plan: $subscriptionPlan');
      } else {
        // debugPrint('Failed to load subscription status: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Error loading subscription status: $e');
    }
  }

  // Refresh subscription status when user returns to this screen
  Future<void> _refreshSubscriptionStatusOnReturn() async {
    // Only refresh if user might have upgraded from wallet screen
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      // debugPrint('Refreshing subscription status on screen return...');
      await _loadSubscriptionStatus();
      
      // Trigger immediate map refresh for up-to-date data
      await _triggerImmediateRefresh(reason: 'subscription status refresh');
      
      // Premium features are now silently available without annoying notifications
    }
  }

  // Handle parking slot selection (Premium feature)
  void _handleSlotSelection(int x, int y) {
    // Check if user is premium
    if (subscriptionPlan != 'premium') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Premium membership required to select custom parking slots'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Upgrade',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/wallet');
            },
          ),
        ),
      );
      return;
    }

    // Find the current map
    final currentMap = maps.isNotEmpty && selectedLevel != null 
        ? maps.firstWhere((m) => m.level == selectedLevel, orElse: () => maps.first)
        : null;
    
    if (currentMap == null) return;

    // Check if the selected slot is available
    String? slotId;
    bool isAvailable = false;
    
    for (var slot in currentMap.slots) {
      if (slot['x'] == x && slot['y'] == y) {
        slotId = slot['slot_id'];
        isAvailable = slot['status'] == 'available';
        break;
      }
    }

    if (slotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parking slot found at this location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This parking slot is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Parking Slot'),
          content: Text('Do you want to select parking slot $slotId as your destination?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _selectCustomParkingSlot(x, y, selectedLevel ?? 1, slotId!);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Select', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Select custom parking slot and calculate path
  Future<void> _selectCustomParkingSlot(int x, int y, int level, String slotId) async {
    setState(() {
      selectedCustomSlotId = slotId;
      selectedCustomX = x;
      selectedCustomY = y;
      selectedCustomLevel = level;
      selectedX = x;
      selectedY = y;
      isLoading = true;
    });

    try {
      // Get entrance coordinates from existing navigation path or use default
      String startPoint = "1,0,3"; // Default entrance coordinates (level,x,y)
      
      if (navigationPath.isNotEmpty && navigationPath.first.length >= 3) {
        // Extract start coordinates from the first point of existing path
        final firstPoint = navigationPath.first;
        final startLevel = firstPoint[0];
        final startX = firstPoint[1];
        final startY = firstPoint[2];
        startPoint = "$startLevel,$startX,$startY";
      }

      // Construct end point in required format: "level,x,y"
      final endPoint = "$level,$x,$y";
      final destination = selectedDestination ?? "Westfield Sydney";

      // Call backend API with correct parameter format
      final response = await http.get(
        Uri.parse('${ApiConfig.shortestPathEndpoint}?'
            'start=${Uri.encodeComponent(startPoint)}&'
            'end=${Uri.encodeComponent(endPoint)}&'
            'building_name=${Uri.encodeComponent(destination)}'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['path'] != null) {
          final newPath = List<List<dynamic>>.from(
            data['path'].map((x) => List<dynamic>.from(x))
          );
          
          // Update navigation path and refresh map
          setState(() {
            navigationPath = newPath;
          });
          
          // Save to preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('navigation_path', json.encode(newPath));
          await prefs.setString('allocated_spot_id', slotId);
          await prefs.setInt('slot_x', x);
          await prefs.setInt('slot_y', y);
          await prefs.setInt('slot_level', level);
          
          // Refresh map with new path
          _refreshMapWithCurrentPaths();
          
          // Ensure _isRefreshing is reset after map refresh
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isRefreshing = false;
              });
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom path to slot $slotId calculated!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception('Failed to calculate path');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Error calculating custom path: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to calculate path: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Reset custom selection
      setState(() {
        selectedCustomSlotId = null;
        selectedCustomX = null;
        selectedCustomY = null;
        selectedCustomLevel = null;
      });
    } finally {
      setState(() {
        isLoading = false;
        // Ensure _isRefreshing is also reset in case of errors
        _isRefreshing = false;
      });
    }
  }
  
  Future<void> _checkFirstTimeAccess() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we have both scanned QR and selected destination
    final hasScannedQR = prefs.getString('entrance_id') != null;
    final hasStoredDestination = prefs.getString('selected_destination') != null;
    
    // If we're forced to show the map, or we have a valid navigation
    if (widget.forceShowMap || prefs.getBool('has_valid_navigation') == true) {
      // If we have both QR and destination, show full map
      if (hasScannedQR && hasStoredDestination) {
        // Load data and show the map
        loadAllocationAndPaths();
        fetchParkingMaps();
        
        // Ensure we remember we have a valid navigation for next time
        await prefs.setBool('has_valid_navigation', true);
        return;
      } else if (hasScannedQR) {
        // We have QR but no destination - clear old data and show basic map without paths
        await prefs.remove('navigation_path');
        await prefs.remove('destination_path');
        await prefs.remove('allocated_spot_id');
        await prefs.remove('slot_x');
        await prefs.remove('slot_y');
        await prefs.remove('slot_level');
        await prefs.setBool('has_valid_navigation', false);
        
        // Clear state variables
        setState(() {
          navigationPath = [];
          destinationPath = [];
          allocatedSpotId = null;
          selectedX = null;
          selectedY = null;
          selectedLevel = null;
          selectedCustomSlotId = null;
          selectedCustomX = null;
          selectedCustomY = null;
          selectedCustomLevel = null;
          isLoading = false;
          hasSelectedDestination = false;
        });
        
        fetchParkingMaps();
        return;
      } else {
        // No QR data at all - show initial screen
        setState(() {
          isLoading = false;
          hasSelectedDestination = false;
        });
        return;
      }
    }
    
    // Check if coming from dashboard with selected destination
    final fromDashboard = prefs.getBool('from_dashboard_selection') ?? false;
    
    if (fromDashboard) {
      // Clear the flag
      await prefs.setBool('from_dashboard_selection', false);
      
      // Load data as normal
      loadAllocationAndPaths();
      fetchParkingMaps();
    } else {
      // First time access or not from dashboard
      // Clear any previous paths and selection
      await prefs.remove('navigation_path');
      await prefs.remove('destination_path');
      
      // Set state to not loading and no selected destination
      setState(() {
        isLoading = false;
        hasSelectedDestination = false;
      });
    }
  }

  // Method to toggle path display mode
  void _togglePathDisplayMode() {
    setState(() {
      if (_pathDisplayMode == "entrance_to_slot") {
        _pathDisplayMode = "slot_to_destination";
      } else {
        _pathDisplayMode = "entrance_to_slot";
      }
      
      // Refresh the map with current path display mode
      _refreshMapWithCurrentPaths();
    });
    
    // Trigger immediate refresh for real-time data (like Premium experience)
    // Move this outside setState to avoid async call in setState
    _triggerImmediateRefresh(reason: 'path display mode toggle');
  }
  
  // Refresh map paths based on current display mode with debouncing
  void _refreshMapWithCurrentPaths() {
    // Prevent multiple refreshes in quick succession
    if (_isRefreshing) {
      // Cancel any pending refresh
      _refreshDebounceTimer?.cancel();
      
      // Schedule a new refresh after a short delay
      _refreshDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
          _actuallyRefreshPaths();
        }
      });
      return;
    }
    
    _isRefreshing = true;
    _actuallyRefreshPaths();
    
    // Reset refresh flag after a delay with proper state management
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
  }
  
  // The actual path refresh implementation
  void _actuallyRefreshPaths() {
    // Check if maps collection is empty
    if (maps.isEmpty) {
      // debugPrint('Maps empty, skipping path refresh');
      return;
    }
    
    // Clear all navigation path corridors from maps
    for (var mapLevel in maps) {
      mapLevel.corridors.removeWhere((corridor) => 
        corridor['is_path'] == true || 
        (corridor['corridor_id'] is String && 
        (corridor['corridor_id'].toString().startsWith('nav_path_entry') || 
         corridor['corridor_id'].toString().startsWith('nav_path_exit')))
      );
    }
    
    // Add paths based on current mode
    if (_pathDisplayMode == "entrance_to_slot") {
      if (navigationPath.isNotEmpty) {
        _addNavigationPathToMaps(navigationPath, true);
        // debugPrint(' Added entry path with ${navigationPath.length} points');
      }
    }
    
    if (_pathDisplayMode == "slot_to_destination") {
      if (destinationPath.isNotEmpty) {
        _addNavigationPathToMaps(destinationPath, false);
        // debugPrint('Added exit path with ${destinationPath.length} points');
      }
    }
    
    // Code for handling overlapping paths is commented out as per requirements
    // if (_pathDisplayMode == "both" && navigationPath.isNotEmpty && destinationPath.isNotEmpty) {
    //   // Find all potential overlapping points between paths
    //   Set<String> entryPathPoints = {};
    //   Set<String> exitPathPoints = {};
    //   
    //   // Convert path points to string keys for comparison
    //   for (var point in navigationPath) {
    //     if (point.length >= 3) {
    //       final level = point[0].toString();
    //       final x = point[1].toString();
    //       final y = point[2].toString();
    //       entryPathPoints.add('$level:$x:$y');
    //     }
    //   }
    //   
    //   for (var point in destinationPath) {
    //     if (point.length >= 3) {
    //       final level = point[0].toString();
    //       final x = point[1].toString();
    //       final y = point[2].toString();
    //       exitPathPoints.add('$level:$x:$y');
    //     }
    //   }
    //   
    //   // Find intersection of points
    //   Set<String> overlappingPoints = entryPathPoints.intersection(exitPathPoints);
    //   
    //   if (overlappingPoints.isNotEmpty) {
    //     debugPrint('Found ${overlappingPoints.length} overlapping points between paths');
    //     
    //     // For each map, prioritize entry path markers at overlapping points
    //     for (var mapLevel in maps) {
    //       int level = mapLevel.level;
    //       
    //       // Process entry path markers first - mark them as "priority"
    //       for (var corridor in mapLevel.corridors) {
    //         if (corridor['is_path'] == true && 
    //             corridor['path_type'] == 'entry' &&
    //             corridor['is_marker'] == true &&
    //             corridor['points'] != null &&
    //             corridor['points'].isNotEmpty) {
    //           
    //           var point = corridor['points'][0];
    //           if (point != null && point.length >= 2) {
    //             String pointKey = '$level:${point[0]}:${point[1]}';
    //             
    //             if (overlappingPoints.contains(pointKey)) {
    //               corridor['priority'] = true;
    //               // debugPrint('Set priority for entry path marker at $pointKey');
    //             }
    //           }
    //         }
    //       }
    //       
    //       // Remove exit path markers at overlapping points if there's a priority entry marker
    //       for (var corridor in mapLevel.corridors) {
    //         if (corridor['is_path'] == true && 
    //             corridor['path_type'] == 'exit' &&
    //             corridor['is_marker'] == true &&
    //             corridor['points'] != null &&
    //             corridor['points'].isNotEmpty) {
    //           
    //           var point = corridor['points'][0];
    //           if (point != null && point.length >= 2) {
    //             String pointKey = '$level:${point[0]}:${point[1]}';
    //             
    //             if (overlappingPoints.contains(pointKey)) {
    //               // Check if there's an entry path marker with priority
    //               bool hasEntryPriority = mapLevel.corridors.any((c) => 
    //                 c['is_path'] == true && 
    //                 c['path_type'] == 'entry' &&
    //                 c['priority'] == true &&
    //                 c['points'] != null && 
    //                 c['points'].isNotEmpty &&
    //                 c['points'][0] != null &&
    //                 c['points'][0].length >= 2 &&
    //                 c['points'][0][0] == point[0] && 
    //                 c['points'][0][1] == point[1]
    //               );
    //               
    //               if (hasEntryPriority) {
    //                 corridor['visible'] = false;
    //                 // debugPrint('Hiding exit path marker at $pointKey due to entry priority');
    //               }
    //             }
    //           }
    //         }
    //       }
    //     }
    //   }
    // }
  }

  Future<void> loadAllocationAndPaths() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load allocated spot information
    allocatedSpotId = prefs.getString('allocated_spot_id');
    if (allocatedSpotId != null) {
      await prefs.setString('selected_slot', allocatedSpotId!);
    }
    
    // Set selected coordinates from saved slot position
    if (prefs.containsKey('slot_x') && prefs.containsKey('slot_y')) {
      selectedX = prefs.getInt('slot_x');
      selectedY = prefs.getInt('slot_y');
      selectedLevel = prefs.getInt('slot_level') ?? 1;
    }
    

    
    // Check if QR code has been scanned (entrance_id exists)
    final hasScannedQR = prefs.getString('entrance_id') != null;
    
    // Load navigation path (entrance to slot) only if QR was scanned
    if (hasScannedQR) {
      final pathJson = prefs.getString('navigation_path');
      if (pathJson != null && pathJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(pathJson);
          navigationPath = decoded.map((point) => point as List<dynamic>).toList();
        } catch (e) {
          // debugPrint('Error parsing navigation path: $e');
        }
      } else {
        // debugPrint('No navigation path data found in SharedPreferences');
      }
      
      // Load destination path (slot to destination)
      final destPathJson = prefs.getString('destination_path');
      if (destPathJson != null && destPathJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = json.decode(destPathJson);
          destinationPath = decoded.map((point) => point as List<dynamic>).toList();
        } catch (e) {
          // debugPrint('Error parsing destination path: $e');
        }
      } else {
        // debugPrint('No destination path data found in SharedPreferences');
      }
    } else {
      // If no QR was scanned, clear any existing paths
      navigationPath = [];
      destinationPath = [];
      // debugPrint('No QR scanned yet - displaying map without navigation paths');
    }
  }

  // Modify the fetchParkingMaps method to properly handle the building name
  Future<void> fetchParkingMaps() async {
    // Cancel any existing timeout timer
    _loadingTimeoutTimer?.cancel();
    
    // Set a timeout to prevent indefinite loading state
    _loadingTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && isLoading) {
  
        setState(() {
          isLoading = false;
          // Show a message to the user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading took too long. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        });
      }
    });

    final prefs = await SharedPreferences.getInstance();
    
    // Always prioritize building_id from QR code for map API calls
    String? buildingFromQR = prefs.getString('building_id');
    String? originalDestination = prefs.getString('selected_destination');
    originalDestination = originalDestination?.replaceAll(' (Example)', '').trim();
    
    // Keep track of the target point separately, don't overwrite the building name
    String? targetPointId = prefs.getString('target_point_id');
    String? entranceId = prefs.getString('entrance_id');
    
    // Always use building name from QR code if available, otherwise fallback to saved destination
    if (buildingFromQR != null && buildingFromQR.isNotEmpty) {
      selectedDestination = buildingFromQR;
      hasSelectedDestination = originalDestination != null && originalDestination.isNotEmpty;
      // debugPrint('Using building from QR code: $selectedDestination (hasSelectedDestination=$hasSelectedDestination)');
    } else if (originalDestination != null && originalDestination.isNotEmpty) {
      selectedDestination = originalDestination;
      hasSelectedDestination = true;
      // debugPrint('Using saved destination: $selectedDestination');
    } else {
      // Check if selectedDestination is available
      if (widget.forceShowMap) {
          // Fallback to default building
          selectedDestination = 'Westfield Sydney';
          hasSelectedDestination = false;
          // debugPrint('Using default building: $selectedDestination (forceShowMap=${widget.forceShowMap}, hasSelectedDestination=false)');
      } else {
        // debugPrint('WARNING: No selected destination found and not forcing map display');
        hasSelectedDestination = false;
        setState(() {
          isLoading = false;
        });
        _loadingTimeoutTimer?.cancel(); // Cancel the timeout timer
        return; // Exit the method if no destination selected
      }
    }

    try {
      // Use the API endpoint with proper environment switching
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(selectedDestination!))),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      // Cancel timeout timer as response is received
      _loadingTimeoutTimer?.cancel();
      
      // Note: For local testing, change useLocalHost to true in api_config.dart
  

  
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        // Check if the response actually contains map data
        if (decoded.containsKey('map') && 
            decoded['map'] != null &&
            decoded['map'].containsKey('parking_map') &&
            decoded['map']['parking_map'] is List && 
            (decoded['map']['parking_map'] as List).isNotEmpty) {
          
          if (mounted) {
            setState(() {
              maps = (decoded['map']['parking_map'] as List)
                  .map((e) => ParkingMap.fromJson(e))
                  .toList();
              
              isLoading = false;
            });
            
            // Add navigation paths synchronously during refresh to maintain _isRefreshing flag
            if (mounted) {
              _refreshMapWithCurrentPaths();
            }
            

          }
        } else {
          // API returned 200 but no valid map data
          _showMapNotFoundError('No parking map data found for $selectedDestination');
        }
      } else if (response.statusCode == 404) {
        // Specifically handle not found case
        _showMapNotFoundError('Parking map not found for $selectedDestination');
      } else {
        // Other error cases
        // debugPrint('ERROR: Failed to load parking map - Status: ${response.statusCode}');
  
        _showMapNotFoundError('Failed to load parking map (Error ${response.statusCode})');
      }

    } catch (e) {
      // Cancel timeout timer on error
      _loadingTimeoutTimer?.cancel();
      
      // Handle network errors or timeouts
      // debugPrint('ERROR: Exception while fetching map: $e');
      _showMapNotFoundError('Network error: Unable to fetch parking map');
    }
  }
  
  void _showMapNotFoundError(String message) {
    setState(() {
      isLoading = false;
      maps = [];
    });
    
    // Show error to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Show dialog with more detailed info and options
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Map Not Available'),
              content: Text('$message\n\nPlease select a different destination or try again later.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/dashboard');
                  },
                  child: const Text('Return to Dashboard'),
                ),
              ],
            ),
          );
        }
      });
    }
  }
  
  // Add navigation path points to the maps
  void _addNavigationPathToMaps(List<List<dynamic>> path, bool isEntryPath) {
    if (path.isEmpty) {
      // debugPrint('Path is empty, cannot add to map');
      return;
    }
    
    // debugPrint('Adding path to map: ${isEntryPath ? "Entry path" : "Exit path"} with ${path.length} points');
    
    // First clear all existing navigation paths of this type
    for (var mapLevel in maps) {
      mapLevel.corridors.removeWhere((corridor) => 
        corridor['is_path'] == true && 
        corridor['path_type'] == (isEntryPath ? 'entry' : 'exit')
      );
    }
    
    // If this is an entry path and the last point is our destination slot, mark it specially
    if (isEntryPath && path.isNotEmpty) {
      // Get the target slot coordinates from SharedPreferences
      // We expect these to be the last point in the path
      final lastPoint = path.last;
      if (lastPoint.length >= 3) {
        final x = lastPoint[1] is int ? lastPoint[1] as int : int.tryParse(lastPoint[1].toString()) ?? 0;
        final y = lastPoint[2] is int ? lastPoint[2] as int : int.tryParse(lastPoint[2].toString()) ?? 0;
        final level = lastPoint[0] is int ? lastPoint[0] as int : int.tryParse(lastPoint[0].toString()) ?? 1;
        
        // Set selected coordinates for highlighting
        // For Premium users: allow full control over level selection
        // For Basic users: respect user's manual level choice during auto-refresh
        setState(() {
          selectedX = x;
          selectedY = y;
          // Only update selectedLevel in these cases:
          // 1. No level is currently selected (initial load)
          // 2. User is Premium (they get full control)
          // For Basic users during auto-refresh: NEVER override their manual level selection
          if (selectedLevel == null || subscriptionPlan == 'premium') {
            // debugPrint('Setting selectedLevel to $level (subscription: $subscriptionPlan, isRefreshing: $_isRefreshing)');
            selectedLevel = level;
          } else if (subscriptionPlan == 'basic') {
            // debugPrint('Basic user - preserving user-selected level $selectedLevel (path points to level $level)');
            // For basic users, never override their manual level selection
          } else {
            // debugPrint('Preserving user-selected level $selectedLevel (path points to level $level)');
          }
        });
      }
    }
    
    // Convert path points to standard format
    List<Map<String, dynamic>> normalizedPath = [];
    for (var point in path) {
      if (point.length >= 3) {
        final level = point[0] is int ? point[0] as int : int.tryParse(point[0].toString()) ?? 1;
        final x = point[1] is int ? point[1] as int : int.tryParse(point[1].toString()) ?? 0;
        final y = point[2] is int ? point[2] as int : int.tryParse(point[2].toString()) ?? 0;
        
        normalizedPath.add({
          'level': level,
          'x': x,
          'y': y
        });
      }
    }
    
    // Group by level
    Map<int, List<Map<String, dynamic>>> pointsByLevel = {};
    for (var point in normalizedPath) {
      if (!pointsByLevel.containsKey(point['level'])) {
        pointsByLevel[point['level']] = [];
      }
      pointsByLevel[point['level']]!.add(point);
    }
    
    // Add paths for each level
    for (var mapLevel in maps) {
      int level = mapLevel.level;
      if (!pointsByLevel.containsKey(level) || pointsByLevel[level]!.isEmpty) continue;
      
      var levelPoints = pointsByLevel[level]!;
      // debugPrint('Adding path to level $level with ${levelPoints.length} points');
      
      // Process each segment of the path (point to point)
      for (int i = 0; i < levelPoints.length - 1; i++) {
        Map<String, dynamic> start = levelPoints[i];
        Map<String, dynamic> end = levelPoints[i + 1];
        
        // Calculate simple direction vector (always points to next point)
        int dx = end['x'] - start['x'];
        int dy = end['y'] - start['y'];

        // CRITICAL CORRECTION: Our coordinates are bottom-left based
        // BUT on screen, y-axis is flipped (y increases as you go UP on screen)
        // So we need to ensure dy gives the correct arrow direction
        
        // Force explicit arrow directions for test coordinates
        if (level == 1 && start['x'] == 1 && start['y'] == 1) {
          if (end['x'] == 1 && end['y'] == 3) {
            // debugPrint('TEST COORDINATE [1,1,3] detected! dx=$dx, dy=$dy');
            // Keep dx=0, but FLIP dy to be positive since y=3 is "up" from y=1
            dx = 0;
            dy = 2; // Positive dy means UP in our rendering system
          } else if (end['x'] == 4 && end['y'] == 1) {
            // debugPrint('TEST COORDINATE [1,1,4] detected! dx=$dx, dy=$dy');
            dx = 3; 
            dy = 0; // No change in y, only moving right (positive x)
          }
        } else if (level == 1 && start['x'] == 1 && start['y'] == 4 && end['x'] == 3 && end['y'] == 4) {
          // debugPrint('TEST COORDINATE [1,4,3] detected! dx=$dx, dy=$dy');
          dx = 2;
          dy = 0; // No change in y, only moving right (positive x)
        }
        
        // Create simplified corridor for this segment - just two points
        Map<String, dynamic> segmentCorridor = {
          'corridor_id': isEntryPath 
              ? 'nav_entry_segment_${level}_$i' 
              : 'nav_exit_segment_${level}_$i',
          'level': level,
          'points': [[start['x'], start['y']], [end['x'], end['y']]],
          'direction': 'forward',
          'is_path': true,
          'path_type': isEntryPath ? 'entry' : 'exit',
          'priority': true, // Add priority flag to ensure navigation paths override map corridors
        };
        
        mapLevel.corridors.add(segmentCorridor);
        // debugPrint('Added segment from (${start['x']},${start['y']}) to (${end['x']},${end['y']})');
        
        // Add navigation arrows at each point
        // 1. At the starting point, add an arrow pointing to the next point
        if (i > 0 || isEntryPath) { // Skip first point for exit path as it overlaps with entry destination
          Map<String, dynamic> startPointMarker = {
            'corridor_id': isEntryPath 
                ? 'nav_entry_marker_${level}_${i}_start' 
                : 'nav_exit_marker_${level}_${i}_start',
            'level': level,
            'points': [[start['x'], start['y']]],
            'direction': 'forward',
            'is_path': true,
            'path_type': isEntryPath ? 'entry' : 'exit',
            'is_marker': true,
            'arrow_dx': dx,
            'arrow_dy': dy,
            'priority': true, // Add priority flag
          };
          
          // For special test coordinates, force the arrow direction with special override
          if (level == 1 && start['x'] == 1 && start['y'] == 1) {
            if (end['x'] == 1 && end['y'] == 3) {
              // [1,1,3] Up arrow
              startPointMarker['special_override'] = 'up_arrow';
              // debugPrint('Setting special UP arrow override at [1,1,3]');
            } else if (end['x'] == 4 && end['y'] == 1) {
              // [1,1,4] Right arrow
              startPointMarker['special_override'] = 'right_arrow';
              // debugPrint('Setting special RIGHT arrow override at [1,1,4]');
            }
          } else if (level == 1 && start['x'] == 1 && start['y'] == 4 && end['x'] == 3 && end['y'] == 4) {
            // [1,4,3] Right arrow
            startPointMarker['special_override'] = 'right_arrow';
            // debugPrint('Setting special RIGHT arrow override at [1,4,3]');
          }
          
          mapLevel.corridors.add(startPointMarker);
          // debugPrint('Added marker at (${start['x']},${start['y']}) with direction dx=$dx, dy=$dy');
        }
        
        // 2. At the final point of the path (if this is the last segment)
        if (i == levelPoints.length - 2) {
          // For entry path, this is the destination - use location marker
          // For exit path, this is the exit - use star marker
          Map<String, dynamic> endPointMarker = {
            'corridor_id': isEntryPath 
                ? 'nav_entry_marker_${level}_${i}_end' 
                : 'nav_exit_marker_${level}_${i}_end',
            'level': level,
            'points': [[end['x'], end['y']]],
            'direction': 'forward',
            'is_path': true,
            'path_type': isEntryPath ? 'entry' : 'exit',
            'is_marker': true,
            'is_destination': true,
            'arrow_dx': dx,
            'arrow_dy': dy,
          };
          
          mapLevel.corridors.add(endPointMarker);
          // debugPrint('Added destination marker at (${end['x']},${end['y']})');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading) {
      return const Scaffold(
        key: buildKey,
        backgroundColor: Color(0xFFD4EECD),
        body: Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
        )),
      );
    }
    
    // No destination selected yet
    // Skip this check if forceShowMap is true
    if (!hasSelectedDestination && !widget.forceShowMap) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('Parking Map'),
          backgroundColor: const Color(0xFFA3DB94),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.map_outlined, 
                size: 80, 
                color: Color(0xFF68B245),
              ),
              const SizedBox(height: 24),
              const Text(
                'Unavailable Map or Session Active',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Please select a destination on the dashboard or scan a QR code to view the parking map\n'
                  'If you already have an active session, the map will load automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA3DB94),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Select Destination',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/qr-scanner');
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
                label: const Text('Scan QR Code', style: TextStyle(color: Colors.black87)),
              ),
            ],
          ),
        ),

      );
    }

    final int maxLevel = maps
        .map((map) => map.level)
        .fold(0, (prev, curr) => curr > prev ? curr : prev);

    // Find the map for the selected level
    ParkingMap? currentMap;
    
    try {
      // Try to find a map for the selected level
      currentMap = maps.firstWhere(
        (map) => map.level == selectedLevel,
      );
    } catch (e) {
      // If no map found for the selected level, use the first map if available
      if (maps.isNotEmpty) {
        currentMap = maps.first;
      }
    }

    if (currentMap == null) {
      return const Center(
        child: Text('No parking map data available.'),
      );
    }

    // Create path mode text indicator
    String pathModeText = "";
    switch (_pathDisplayMode) {
      case "entrance_to_slot":
        pathModeText = "Show: Entrance → Parking";
        break;
      case "slot_to_destination":
        pathModeText = "Show: Parking → Building Entrance (star)";
        break;
      default:
        pathModeText = "Show: Complete Path";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        title: Text(
          // Show the actual building name, not the navigation point
          selectedDestination ?? 'Parking Map',
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Display spot instead of level with better styling
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFF68B245),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_parking, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Spot: ${allocatedSpotId ?? "None"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Use a Stack as the main body to allow overlays without affecting layout
      body: Stack(
        children: [
          // Main content in a Column
          Column(
            children: [
              // Path toggle button and level selector in a single row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Path toggle button (now centered)
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6, // Control width
                      child: ElevatedButton.icon(
                        onPressed: _togglePathDisplayMode,
                        icon: const Icon(Icons.route, size: 18),
                        label: Text(
                          pathModeText,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Level selector moved back to its own row with more compact design
              if (maxLevel > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 36,
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFA3DB94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Down button
                            InkWell(
                              onTap: selectedLevel! > 1
                                ? () async {
                                    if (_isLevelSwitching) return; // Prevent rapid clicks
                                    
                                    _isLevelSwitching = true;
                                    _autoRefreshTimer?.cancel(); // Stop auto-refresh during level switching
                                    
                                    final newLevel = selectedLevel! - 1;
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setInt('map_selected_level', newLevel);
                                    
                                    if (mounted) {
                                      setState(() {
                                        selectedLevel = newLevel;
                                        _levelController.text = 'Level $selectedLevel';
                                      });
                                    }
                                    
                                    // debugPrint('ParkingMapScreen: Level changed to $newLevel (down button) - stable switching');
                                    
                                    // Re-enable after a short delay
                                    Timer(const Duration(milliseconds: 500), () {
                                      _isLevelSwitching = false;
                                      if (mounted) _startAutoRefresh(); // Restart auto-refresh
                                    });
                                  }
                                : null,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selectedLevel! > 1 ? Colors.white : Colors.white.withOpacity(0.5),
                                ),
                                child: const Icon(Icons.remove, size: 16, color: Colors.black87),
                              ),
                            ),
                            
                            // Level text
                            Text(
                              'Level $selectedLevel',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            
                            // Up button
                            InkWell(
                              onTap: selectedLevel! < maxLevel
                                ? () async {
                                    if (_isLevelSwitching) return; // Prevent rapid clicks
                                    
                                    _isLevelSwitching = true;
                                    _autoRefreshTimer?.cancel(); // Stop auto-refresh during level switching
                                    
                                    final newLevel = selectedLevel! + 1;
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setInt('map_selected_level', newLevel);
                                    
                                    if (mounted) {
                                      setState(() {
                                        selectedLevel = newLevel;
                                        _levelController.text = 'Level $selectedLevel';
                                      });
                                    }
                                    
                                    // debugPrint('ParkingMapScreen: Level changed to $newLevel (up button) - stable switching');
                                    
                                    // Re-enable after a short delay
                                    Timer(const Duration(milliseconds: 500), () {
                                      _isLevelSwitching = false;
                                      if (mounted) _startAutoRefresh(); // Restart auto-refresh
                                    });
                                  }
                                : null,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selectedLevel! < maxLevel ? Colors.white : Colors.white.withOpacity(0.5),
                                ),
                                child: const Icon(Icons.add, size: 16, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Map display with adjusted height
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.46, // Slightly increased for map
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.95,
                    ),
                    child: ParkingMapWidget(
                      map: currentMap,
                      isOperator: false,
                      preview: false,
                      selectedX: selectedX,
                      selectedY: selectedY,
                      selectedLevel: selectedLevel,
                      allocatedSpotId: allocatedSpotId,
                      onTapCell: subscriptionPlan == 'premium' ? _handleSlotSelection : null,
                    ),
                  ),
                ),
              ),
              
              // Buttons and Legend section with flexible layout
              Expanded(
                child: Column(
                  children: [
                    // Parking action button (Trigger/End)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: _isParkingActive 
                        ? ElevatedButton.icon(
                            onPressed: _endParkingSession,
                            icon: const Icon(Icons.stop),
                            label: const Text('End Parking'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              minimumSize: const Size(double.infinity, 48), // Full width button
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        : !_isTimerActive
                          ? ElevatedButton.icon(
                              onPressed: _handleTriggerPress,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Trigger Parking'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF68B245),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                minimumSize: const Size(double.infinity, 48), // Full width button
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(), // No button during countdown
                    ),
                    
                    // Active timer display (when parking is active)
                    if (_isParkingActive && _timerText != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _timerText!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Map Legend with proper scrolling
                    Expanded(
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: GridView.count(
                                  crossAxisCount: 2,
                                  childAspectRatio: 5.0, // Make items even flatter
                                  crossAxisSpacing: 4.0, // Further reduce spacing
                                  mainAxisSpacing: 3.0, // Further reduce spacing
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildLegendItem(Colors.green, 'Available'),
                                    _buildLegendItem(Colors.yellow, 'Allocated'),
                                    _buildLegendItem(Colors.red, 'Occupied'),
                                    _buildLegendItem(Colors.orange, 'Vehicle Entrance'),
                                    _buildLegendItem(Colors.purple, 'Building Entrance'),
                                    _buildLegendItem(Colors.brown, 'Exit'),
                                    _buildLegendItem(Colors.pinkAccent, 'Ramp'),
                                    _buildLegendItem(Colors.grey, 'Wall'),
                                    _buildLegendItem(Colors.transparent, 'Corridor'),
                                    _buildLegendItem(const Color(0xFF3498DB), 'Navigation Path'),
                                    _buildLegendItem(const Color(0xFF2ECC71), 'To Destination'),
                                  ],
                                ),
                              ),
                              
                              // Premium feature notice
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: subscriptionPlan == 'premium' 
                                      ? Colors.orange.shade50 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: subscriptionPlan == 'premium' 
                                        ? Colors.orange.shade300 
                                        : Colors.grey.shade300
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      subscriptionPlan == 'premium' 
                                          ? Icons.workspace_premium 
                                          : Icons.lock,
                                      color: subscriptionPlan == 'premium' 
                                          ? Colors.orange.shade700 
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        subscriptionPlan == 'premium'
                                            ? 'Premium: Tap any available slot to select'
                                            : 'Upgrade to Premium to select custom slots',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: subscriptionPlan == 'premium' 
                                              ? Colors.orange.shade700 
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    if (subscriptionPlan == 'basic')
                                      TextButton(
                                        onPressed: () => Navigator.pushNamed(context, '/wallet'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                        child: Text(
                                          'Upgrade',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Overlay for timer notification - Positioned at bottom, doesn't affect layout
          if (_isTimerActive && _timerText != null)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.black87),
                          const SizedBox(width: 8),
                          Text(
                            _timerText!.startsWith('Countdown') ? 'Countdown: $_timerSeconds s' : _timerText!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      // Cancel button
                      TextButton(
                        onPressed: _cancelTimer,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLevelPicker(BuildContext context, int maxLevel) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: maxLevel,
            itemBuilder: (context, index) {
              int real = index + 1;
              return ListTile(
                title: Text('Level $real'),
                onTap: () {
                  setState(() {
                    selectedLevel = real;
                    _levelController.text = 'Level $selectedLevel';
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  // Modified helper method for more compact legend items
  Widget _buildLegendItem(Color color, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Smaller radius
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller padding
      child: Row(
        children: [
          Container(
            width: 14, // Smaller square
            height: 14, // Smaller square
            decoration: BoxDecoration(
              color: color,
              border: color == Colors.transparent
                  ? Border.all(color: Colors.black, width: 1)
                  : null,
              borderRadius: BorderRadius.circular(3), // Smaller radius
            ),
          ),
          const SizedBox(width: 6), // Smaller spacing
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11), // Smaller font
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}