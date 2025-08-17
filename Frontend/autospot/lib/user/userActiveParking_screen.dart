import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/main_container.dart';
import 'package:autospot/config/api_config.dart';
import 'package:autospot/models/parking_map.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';

class ActiveParkingScreen extends StatefulWidget {
  final DateTime startTime;
  final bool showNavigationBar;

  const ActiveParkingScreen({
    super.key, 
    required this.startTime,
    this.showNavigationBar = false, // Default to false when embedded in MainContainer
  });

  @override
  State<ActiveParkingScreen> createState() => _ActiveParkingScreenState();
}

class _ActiveParkingScreenState extends State<ActiveParkingScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _sessionStarted = false;
  
  // Map display toggle
  bool _showMap = false;
  
  // Map related variables
  List<ParkingMap> maps = [];
  bool isLoadingMap = false;
  String? selectedDestination;
  int? selectedLevel;
  int? selectedX;
  int? selectedY;
  String? allocatedSpotId;
  List<List<dynamic>> navigationPath = [];
  List<List<dynamic>> destinationPath = [];
  
  // Path display control
  String _pathDisplayMode = "entrance_to_slot"; // "entrance_to_slot", "slot_to_destination"
  int maxLevel = 1;

  @override
  void initState() {
    super.initState();
    _attemptStartSession();
  }

  Future<void> _attemptStartSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');
    final slotId = prefs.getString('allocated_spot_id');
    final existingSessionId = prefs.getString('session_id');
    final storedStartTimeStr = prefs.getString('parking_start_time');

    if (username == null || vehicleId == null || slotId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing session data")),
      );
      return;
    }

    // Resume timer if already stored
    if (existingSessionId != null && storedStartTimeStr != null) {
      final storedStartTime = DateTime.tryParse(storedStartTimeStr);
      if (storedStartTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(storedStartTime);

          _sessionStarted = true;
          allocatedSpotId = slotId;
        });
        _startTimer(storedStartTime);
        return;
      }
    }

    // Otherwise, attempt to start a new session
    final uri = Uri.parse(
      '${ApiConfig.startSessionEndpoint}?username=${Uri.encodeComponent(username)}'
      '&vehicle_id=${Uri.encodeComponent(vehicleId)}'
      '&slot_id=${Uri.encodeComponent(slotId)}'
    );

    try {
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        final session = jsonBody['session'];
        final startTime = DateTime.parse(session['start_time']);

        await prefs.setString('parking_start_time', startTime.toIso8601String());
        await prefs.setString('session_id', session['session_id']);
        await prefs.setString('allocated_spot_id', slotId);

        if (!mounted) return;

        setState(() {
          _elapsed = DateTime.now().difference(startTime);
          _sessionStarted = true;
          allocatedSpotId = slotId;
        });

        _startTimer(startTime);
      } else {
        final error = json.decode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['detail'] ?? 'Failed to start session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  void _startTimer(DateTime actualStartTime) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(actualStartTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // Toggle between timer and map display
  void _toggleMapDisplay() {
    setState(() {
      _showMap = !_showMap;
    });
    
    // Load map data when switching to map view for the first time
    if (_showMap && maps.isEmpty && !isLoadingMap) {
      _loadMapData();
    }
  }

  // Load map and navigation data
  Future<void> _loadMapData() async {
    if (isLoadingMap) return;
    
    setState(() {
      isLoadingMap = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get stored data
      selectedDestination = prefs.getString('selected_destination');
      allocatedSpotId = prefs.getString('allocated_spot_id');
      selectedX = prefs.getInt('slot_x');
      selectedY = prefs.getInt('slot_y');
      selectedLevel = prefs.getInt('slot_level');
      
      // Get navigation paths
      final navigationPathJson = prefs.getString('navigation_path');
      final destinationPathJson = prefs.getString('destination_path');
      
      if (navigationPathJson != null) {
        navigationPath = List<List<dynamic>>.from(
          json.decode(navigationPathJson).map((x) => List<dynamic>.from(x))
        );
        // debugPrint('Loaded navigation path with ${navigationPath.length} points: $navigationPath');
      } else {
        // debugPrint('No navigation_path found in SharedPreferences');
      }
      
      if (destinationPathJson != null) {
        destinationPath = List<List<dynamic>>.from(
          json.decode(destinationPathJson).map((x) => List<dynamic>.from(x))
        );
        // debugPrint('Loaded destination path with ${destinationPath.length} points: $destinationPath');
      } else {
        // debugPrint('No destination_path found in SharedPreferences');
      }
      
      // debugPrint('Selected destination: $selectedDestination');
      // debugPrint('Allocated spot: $allocatedSpotId at ($selectedX, $selectedY, Level $selectedLevel)');
      
      // Load parking map
      if (selectedDestination != null) {
        final response = await http.get(
          Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(selectedDestination!))),
          headers: ApiConfig.headers,
        );
        
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          
          if (decoded.containsKey('map') && 
              decoded['map'] != null &&
              decoded['map'].containsKey('parking_map') &&
              decoded['map']['parking_map'] is List && 
              (decoded['map']['parking_map'] as List).isNotEmpty) {
            
            setState(() {
              maps = (decoded['map']['parking_map'] as List)
                  .map((e) => ParkingMap.fromJson(e))
                  .toList();
              
              // Set max level and default selected level
              maxLevel = maps.isNotEmpty ? maps.map((m) => m.level).reduce((a, b) => a > b ? a : b) : 1;
              selectedLevel ??= (selectedLevel != null && selectedLevel! <= maxLevel) ? selectedLevel : 1;
            });
            
            // Add navigation paths to maps
            _addNavigationPathsToMaps();
          }
        }
      }
    } catch (e) {
      // debugPrint('Error loading map data: $e');
    } finally {
      setState(() {
        isLoadingMap = false;
      });
    }
  }

  // Add navigation paths to the maps for display
  void _addNavigationPathsToMaps() {
    if (maps.isEmpty) return;
    
    // Clear existing navigation paths
    for (var mapLevel in maps) {
      mapLevel.corridors.removeWhere((corridor) => 
        corridor['is_path'] == true
      );
    }
    
    // Add paths based on current display mode
    if (_pathDisplayMode == "entrance_to_slot") {
      // Show entrance to slot path
      if (navigationPath.isNotEmpty) {
        _addNavigationPathToMaps(navigationPath, true);
        // debugPrint('Added entrance-to-slot path with ${navigationPath.length} points');
      }
    } else if (_pathDisplayMode == "slot_to_destination") {
      // Show slot to destination path  
      if (destinationPath.isNotEmpty) {
        _addNavigationPathToMaps(destinationPath, false);
        // debugPrint('Added slot-to-destination path with ${destinationPath.length} points');
      }
    }
  }
  
  // Toggle path display mode and refresh map
  void _togglePathMode() {
    setState(() {
      _pathDisplayMode = _pathDisplayMode == "entrance_to_slot" 
          ? "slot_to_destination" 
          : "entrance_to_slot";
    });
    
    // Force refresh the paths on maps
    _addNavigationPathsToMaps();
    
    // Trigger a UI refresh to ensure map updates
    Future.microtask(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // debugPrint('Switched to path mode: $_pathDisplayMode');
  }

  // Helper method to add navigation path to maps
  void _addNavigationPathToMaps(List<List<dynamic>> path, bool isEntryPath) {
    if (path.isEmpty || maps.isEmpty) return;
    
    // Normalize path format - backend returns [level, x, y] format
    List<Map<String, dynamic>> normalizedPath = path.map((point) {
      if (point.length >= 3) {
        final normalized = {
          'level': point[0] is int ? point[0] : int.tryParse(point[0].toString()) ?? 1,
          'x': point[1] is int ? point[1] : int.tryParse(point[1].toString()) ?? 0,
          'y': point[2] is int ? point[2] : int.tryParse(point[2].toString()) ?? 0,
        };
        // debugPrint('Normalized point: $point → L${normalized['level']}(${normalized['x']},${normalized['y']})');
        return normalized;
      }
      // debugPrint('Invalid point format: $point');
      return {'level': 1, 'x': 0, 'y': 0};
    }).toList();
    
    // Group by level
    Map<int, List<Map<String, dynamic>>> pointsByLevel = {};
    for (var point in normalizedPath) {
      if (!pointsByLevel.containsKey(point['level'])) {
        pointsByLevel[point['level']] = [];
      }
      pointsByLevel[point['level']]!.add(point);
    }
    
    // debugPrint('Path grouped by levels: ${pointsByLevel.keys.toList()}');
    for (var level in pointsByLevel.keys) {
      // debugPrint(' Level $level: ${pointsByLevel[level]!.length} points');
    }
    
    // Add paths for each level
    // debugPrint('Available map levels: ${maps.map((m) => m.level).toList()}');
    for (var mapLevel in maps) {
      int level = mapLevel.level;
      // debugPrint('Checking map level $level for path data...');
      if (!pointsByLevel.containsKey(level) || pointsByLevel[level]!.isEmpty) {
        // debugPrint('No path data for level $level');
        continue;
      }
      
      var levelPoints = pointsByLevel[level]!;
      // debugPrint('Found ${levelPoints.length} path points for level $level');
      
      // Process each segment of the path
      for (int i = 0; i < levelPoints.length - 1; i++) {
        Map<String, dynamic> start = levelPoints[i];
        Map<String, dynamic> end = levelPoints[i + 1];
        
        // Calculate direction vector (dx, dy) from start to end point
        int dx = end['x'] - start['x'];
        int dy = end['y'] - start['y'];
        
        // debugPrint('Path segment: (${start['x']},${start['y']}) → (${end['x']},${end['y']}) = dx=$dx, dy=$dy');
        
        // Create corridor for this segment
        Map<String, dynamic> segmentCorridor = {
          'corridor_id': isEntryPath 
              ? 'nav_entry_segment_${level}_$i' 
              : 'nav_exit_segment_${level}_$i',
          'level': level,
          'points': [[start['x'], start['y']], [end['x'], end['y']]],
          'direction': 'forward',
          'is_path': true,
          'path_type': isEntryPath ? 'entry' : 'exit',
          'priority': true,
        };
        
        mapLevel.corridors.add(segmentCorridor);
        // debugPrint('Added segment L$level: (${start['x']},${start['y']}) → (${end['x']},${end['y']}) [${isEntryPath ? "Entry" : "Exit"}]');
        
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
            'priority': true,
          };
          
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

  Future<void> _confirmEndParkingSession() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 24,
          backgroundColor: const Color(0xFFCFF4D2), // Light green
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'End Parking Session',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'Are you sure you want to end the parking session?',
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 24),

                // Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel Button
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black12),
                        ),
                        shadowColor: Colors.black26,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),

                    // End Session Button
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        shadowColor: Colors.black38,
                      ),
                      child: const Text('End Session'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    _timer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');
    final sessionId = prefs.getString('session_id');
    final slotId = prefs.getString('allocated_spot_id');

    if (username == null || vehicleId == null || sessionId == null || slotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing session info.")),
      );
      return;
    }

    final uri = Uri.parse(
      '${ApiConfig.endSessionEndpoint}?username=${Uri.encodeComponent(username)}'
      '&vehicle_id=${Uri.encodeComponent(vehicleId)}'
      '&session_id=${Uri.encodeComponent(sessionId)}'
      '&slot_id=${Uri.encodeComponent(slotId)}'
    );

    try {
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final now = DateTime.now();

        // Save temporary data for payment screen
        await prefs.setString('temp_parking_start_time', widget.startTime.toIso8601String());
        await prefs.setString('temp_parking_end_time', now.toIso8601String());
        await prefs.setInt('temp_parking_duration_seconds', _elapsed.inSeconds);
        
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

        // Calculate emission before clearing session data
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

        // Clear ALL session and navigation related data to completely reset state
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
        // debugPrint('🧹 ActiveParking: Data cleanup completed, verifying...');
        final verifyStartTime = prefs.getString('parking_start_time');
        final verifyEntranceId = prefs.getString('entrance_id');
        final verifyBuildingId = prefs.getString('building_id');
        final verifyDestination = prefs.getString('selected_destination');
        final verifyNavigation = prefs.getBool('has_valid_navigation');
        
        // debugPrint('ActiveParking Verification - parking_start_time: $verifyStartTime');
        // debugPrint('ActiveParking Verification - entrance_id: $verifyEntranceId');
        // debugPrint('ActiveParking Verification - building_id: $verifyBuildingId');
        // debugPrint('ActiveParking Verification - selected_destination: $verifyDestination');
        // debugPrint('ActiveParking Verification - has_valid_navigation: $verifyNavigation');

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          '/parking-fee',
          arguments: {
            'startTime': widget.startTime,
            'endTime': now,
            'isActiveSession': false,
            'duration': _elapsed,
          },
        );
      } else {
        final error = json.decode(response.body);
        final message = error['detail'] ?? 'Failed to end session';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Build timer display view
  Widget _buildTimerView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 100, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_elapsed),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 30),
          
          // Toggle button to switch to map view
          ElevatedButton.icon(
            onPressed: _toggleMapDisplay,
            icon: const Icon(Icons.map),
            label: const Text('View Navigation Map'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // End parking session button
          ElevatedButton.icon(
            onPressed: _confirmEndParkingSession,
            icon: const Icon(Icons.stop),
            label: const Text('End Parking Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  // Build map display view
  Widget _buildMapView() {
    if (isLoadingMap) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Loading Navigation Map...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (maps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Navigation Map Not Available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No navigation data found for this session',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            
            // Button to go back to timer view
            ElevatedButton.icon(
              onPressed: _toggleMapDisplay,
              icon: const Icon(Icons.timer),
              label: const Text('Back to Timer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Find current level map or default to first map
    ParkingMap? currentMap = maps.isNotEmpty ? maps.first : null;
    if (selectedLevel != null) {
      currentMap = maps.firstWhere(
        (map) => map.level == selectedLevel,
        orElse: () => maps.first,
      );
    }

    return Column(
      children: [
        // Timer display and controls at top
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timer display
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              
              // Right side controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Parking spot info
                  if (allocatedSpotId != null)
                    ElevatedButton.icon(
                      onPressed: null, // Disabled button
                      icon: Icon(
                        Icons.local_parking, 
                        size: 14, 
                        color: const Color(0xFF68B245),
                      ),
                      label: Text(
                        '$allocatedSpotId',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF68B245),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF68B245).withOpacity(0.1),
                        foregroundColor: const Color(0xFF68B245),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // Path mode toggle button
                  ElevatedButton.icon(
                    onPressed: (navigationPath.isNotEmpty && destinationPath.isNotEmpty) ? _togglePathMode : null,
                    icon: Icon(_pathDisplayMode == "entrance_to_slot" ? Icons.directions_walk : Icons.location_on),
                    label: Text(_pathDisplayMode == "entrance_to_slot" ? "To Slot" : "To Destination"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pathDisplayMode == "entrance_to_slot" ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  // Debug button to reload paths
                  if (kDebugMode) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {
                        // debugPrint('Debug: Reloading paths...');
                        _addNavigationPathsToMaps();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      tooltip: 'Reload Paths',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Level selector (if multiple levels)
        if (maxLevel > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: maxLevel,
              itemBuilder: (context, index) {
                final level = index + 1;
                final isSelected = selectedLevel == level;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedLevel = level;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.green : Colors.grey[300],
                      foregroundColor: isSelected ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text('Level $level'),
                  ),
                );
              },
            ),
          ),

        // Map display
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: currentMap != null
                  ? ParkingMapWidget(
                      map: currentMap,
                      isOperator: false,
                      preview: true,
                      selectedX: selectedX,
                      selectedY: selectedY,
                      selectedLevel: selectedLevel,
                      onTapCell: null,
                    )
                  : const Center(
                      child: Text(
                        'Map display error',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
            ),
          ),
        ),

        // Path info display
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Route info
                Icon(
                  _pathDisplayMode == "entrance_to_slot" 
                      ? Icons.directions_walk 
                      : Icons.location_on,
                  size: 14,
                  color: _pathDisplayMode == "entrance_to_slot" 
                      ? Colors.blue 
                      : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _pathDisplayMode == "entrance_to_slot" 
                      ? "Entrance → Parking Slot" 
                      : "Parking Slot → Destination",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    letterSpacing: 0.1,
                  ),
                ),
                
                // Distance info
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _pathDisplayMode == "entrance_to_slot" 
                        ? Colors.blue.withOpacity(0.08) 
                        : Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 10,
                        color: _pathDisplayMode == "entrance_to_slot" 
                            ? Colors.blue 
                            : Colors.orange,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_pathDisplayMode == "entrance_to_slot" ? navigationPath.length : destinationPath.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _pathDisplayMode == "entrance_to_slot" 
                              ? Colors.blue 
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Control buttons at bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Back to timer button
              ElevatedButton.icon(
                onPressed: _toggleMapDisplay,
                icon: const Icon(Icons.timer),
                label: const Text('Timer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              // End session button
              ElevatedButton.icon(
                onPressed: _confirmEndParkingSession,
                icon: const Icon(Icons.stop),
                label: const Text('End Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
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
            child: Column(
              children: [
                // 🅰 Title pinned to top
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'AutoSpot',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                Expanded(
                  child: _sessionStarted
                      ? (_showMap ? _buildMapView() : _buildTimerView())
                      : const Center(child: CircularProgressIndicator(color: Colors.green)),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: widget.showNavigationBar ? BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) => MainNavigator.navigateToTab(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: const Color(0xFFD4EECD),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), label: 'Plant'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ) : null,
    );
  }
}