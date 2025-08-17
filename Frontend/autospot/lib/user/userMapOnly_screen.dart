import 'package:flutter/material.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';
import 'package:autospot/models/parking_map.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:autospot/config/api_config.dart';

class MapOnlyScreen extends StatefulWidget {
  const MapOnlyScreen({super.key});

  @override
  State<MapOnlyScreen> createState() => _MapOnlyScreenState();
}

class _MapOnlyScreenState extends State<MapOnlyScreen> {
  List<ParkingMap> maps = [];
  bool isLoading = true;
  String? selectedDestination;
  String? errorMessage;
  int? selectedLevel;
  int? selectedX;
  int? selectedY;

  late TextEditingController _levelController;
  
  // Add auto-refresh timer for real-time data sync (like ParkingMapScreen)
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  
  // Level switching protection
  bool _isLevelSwitching = false;

  @override
  void dispose() {
    _levelController.dispose();
    _autoRefreshTimer?.cancel(); // Cancel auto-refresh timer
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only start auto-refresh if not already running and has destination
    if (_autoRefreshTimer == null && selectedDestination != null) {
      // debugPrint('MapOnlyScreen: Starting auto-refresh in didChangeDependencies');
      _startAutoRefresh();
    } else {
      // debugPrint('MapOnlyScreen: Auto-refresh already running or no destination, skipping');
    }
  }

  @override
  void deactivate() {
    // Stop auto-refresh when screen becomes inactive
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    // debugPrint('MapOnlyScreen deactivated - stopped auto-refresh');
    super.deactivate();
  }

  Future<void> _initializeAndLoad() async {
    await _initializeLevel();
    await _loadDestinationAndMap();
  }

  Future<void> _initializeLevel() async {
    final prefs = await SharedPreferences.getInstance();
    // Load saved level from preferences, default to 1 if not found
    selectedLevel = prefs.getInt('map_selected_level') ?? 1;
    _levelController = TextEditingController(text: 'Level $selectedLevel');
    // debugPrint('MapOnlyScreen: Initialized with saved level: $selectedLevel');
    
    // Add state to prevent immediate rerenders
    if (mounted) {
      setState(() {
        // Force UI update with the correct level
      });
    }
  }

  Future<void> _validateSelectedLevel() async {
    if (maps.isEmpty) return;
    
    final availableLevels = maps.map((m) => m.level).toList();
    final maxLevel = availableLevels.fold(0, (prev, curr) => curr > prev ? curr : prev);
    final minLevel = availableLevels.fold(maxLevel, (prev, curr) => curr < prev ? curr : prev);
    
    // If current selected level is not available, use the closest available level
    if (selectedLevel == null || !availableLevels.contains(selectedLevel)) {
      int newLevel;
      if (selectedLevel == null) {
        newLevel = minLevel; // Default to minimum available level
      } else if (selectedLevel! < minLevel) {
        newLevel = minLevel; // Use minimum if selected is too low
      } else {
        newLevel = maxLevel; // Use maximum if selected is too high
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('map_selected_level', newLevel);
      
      setState(() {
        selectedLevel = newLevel;
        _levelController.text = 'Level $selectedLevel';
      });
    }
  }

  Future<void> _loadDestinationAndMap() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First try to get selected destination
    String? destination = prefs.getString('selected_destination');
    
    // If no destination selected, try to get building from QR code
    if (destination == null || destination.isEmpty) {
      final buildingFromQR = prefs.getString('building_id');
      if (buildingFromQR != null && buildingFromQR.isNotEmpty) {
        destination = buildingFromQR;
      }
    }
    
    setState(() {
      selectedDestination = destination;
      isLoading = true;
    });

    if (destination == null || destination.isEmpty) {
      setState(() {
        errorMessage = 'No destination or building information available.';
        isLoading = false;
      });
      return;
    }

    // Check if it's the example map (handle both formats)
    if (destination == 'Westfield Sydney (Example)' || destination == 'Westfield Sydney') {
      // Load example map data
      _loadExampleMap();
    } else {
      // Attempt to load from API
      _loadMapFromAPI(destination);
    }
  }

  Future<void> _loadExampleMap() async {
    try {
      // Create first level of example map
      final exampleMap1 = ParkingMap(
        building: 'Westfield Sydney (Example)',
        level: 1,
        rows: 6,
        cols: 6,
        entrances: [
          {'x': 0, 'y': 3, 'type': 'car'},
          {'x': 3, 'y': 0, 'type': 'building'}
        ],
        exits: [
          {'x': 5, 'y': 3},
        ],
        slots: [
          {'x': 2, 'y': 2, 'status': 'available'},
          {'x': 2, 'y': 3, 'status': 'available'},
          {'x': 3, 'y': 2, 'status': 'available'},
          {'x': 3, 'y': 3, 'status': 'available'},
        ],
        corridors: [
          {
            'points': [[1, 1], [2, 1], [3, 1], [4, 1]], // bottom horizontal
            'direction': 'both'
          },
          {
            'points': [[4, 1], [4, 2], [4, 3], [4, 4]], // right vertical
            'direction': 'both'
          },
          {
            'points': [[4, 4], [3, 4], [2, 4], [1, 4]], // top horizontal
            'direction': 'both'
          },
          {
            'points': [[1, 4], [1, 3], [1, 2], [1, 1]], // left vertical
            'direction': 'both'
          },
          {
            'points': [[0, 3], [1, 3]], // entrance access
            'direction': 'both'
          },
          {
            'points': [[4, 3], [5, 3]], // exit access
            'direction': 'both'
          },
          {
            'points': [[3, 1], [3, 0]], // building access
            'direction': 'both'
          }
        ],
        walls: [
          {
            'points': [[0, 0], [5, 0]]
          },
          {
            'points': [[5, 0], [5, 5]]
          },
          {
            'points': [[5, 5], [0, 5]]
          },
          {
            'points': [[0, 5], [0, 0]]
          }
        ],
        ramps: [
          {'x': 1, 'y': 0}
        ]
      );
      
      // Create second level of example map
      final exampleMap2 = ParkingMap(
        building: 'Westfield Sydney (Example)',
        level: 2,
        rows: 6,
        cols: 6,
        entrances: [
          {'x': 3, 'y': 0, 'type': 'building'},
        ],
        exits: [
          {'x': 5, 'y': 3},
        ],
        slots: [
          {'x': 2, 'y': 2, 'status': 'occupied'},
          {'x': 2, 'y': 3, 'status': 'allocated'},
          {'x': 3, 'y': 2, 'status': 'allocated'},
          {'x': 3, 'y': 3, 'status': 'occupied'},
        ],
        corridors: [
          {
            'points': [[1, 1], [2, 1], [3, 1], [4, 1]], // bottom horizontal
            'direction': 'both'
          },
          {
            'points': [[4, 1], [4, 2], [4, 3], [4, 4]], // right vertical
            'direction': 'both'
          },
          {
            'points': [[4, 4], [3, 4], [2, 4], [1, 4]], // top horizontal
            'direction': 'both'
          },
          {
            'points': [[1, 4], [1, 3], [1, 2], [1, 1]], // left vertical
            'direction': 'both'
          },
          {
            'points': [[4, 3], [5, 3]], // exit access
            'direction': 'both'
          },
          {
            'points': [[3, 1], [3, 0]], // building access
            'direction': 'both'
          }
        ],
        walls: [
          {
            'points': [[0, 0], [5, 0]]
          },
          {
            'points': [[5, 0], [5, 5]]
          },
          {
            'points': [[5, 5], [0, 5]]
          },
          {
            'points': [[0, 5], [0, 0]]
          }
        ],
        ramps: [
          {'x': 1, 'y': 0}
        ]
      );
      
      setState(() {
        maps = [exampleMap1, exampleMap2];
        isLoading = false;
      });
      
      // Ensure selected level is valid for the loaded maps
      await _validateSelectedLevel();
      
      // Start auto-refresh after loading maps successfully
      _startAutoRefresh();
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading example map: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadMapFromAPI(String destination) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(destination))),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));

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
            
            isLoading = false;
          });
          
          // Ensure selected level is valid for the loaded maps
          await _validateSelectedLevel();
          
          // Start auto-refresh after loading maps successfully
          _startAutoRefresh();
        } else {
          _showMapNotFoundError('No parking map data found for $destination');
        }
      } else if (response.statusCode == 404) {
        _showMapNotFoundError('Parking map not found for $destination');
      } else {
        _showMapNotFoundError('Failed to load parking map (Error ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading map: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _showMapNotFoundError(String message) {
    setState(() {
      isLoading = false;
      maps = [];
      errorMessage = message;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
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
                    _navigateBackToInitialMap();
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

  void _navigateBackToInitialMap() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear navigation related flags before navigating back
    await prefs.setBool('from_dashboard_selection', false);
    await prefs.setBool('has_valid_navigation', false);
    
    if (mounted) {
      // Navigate back to Dashboard instead of map screen
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  // Start auto-refresh timer for real-time data synchronization (like ParkingMapScreen)
  void _startAutoRefresh() {
    // Cancel existing timer to prevent duplicates
    _autoRefreshTimer?.cancel();
    
    // Only start if screen is currently active and has destination
    if (!mounted || selectedDestination == null) {
      // debugPrint('MapOnlyScreen: Not starting auto-refresh: mounted=$mounted, destination=$selectedDestination');
      return;
    }
    
    // debugPrint('MapOnlyScreen: Starting auto-refresh for real-time sync');
    // Refresh every 5 seconds to sync parking slot status across devices (same as ParkingMapScreen)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isRefreshing && !_isLevelSwitching && selectedDestination != null) {
        // debugPrint('MapOnlyScreen: Auto-refreshing map for real-time sync');
        _refreshMapData();
      } else {
        if (_isLevelSwitching) {
          // debugPrint('MapOnlyScreen: Skipping auto-refresh: level switching in progress');
        } else {
          // debugPrint('MapOnlyScreen: Stopping auto-refresh: conditions not met');
          timer.cancel();
          _autoRefreshTimer = null;
        }
      }
    });
  }

  // Refresh map data without showing loading indicator (preserve user's level selection and navigation paths)
  Future<void> _refreshMapData() async {
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
    
    try {
      setState(() {
        _isRefreshing = true;
      });
      
      // Check if it's the example map (handle both formats)
      if (selectedDestination == 'Westfield Sydney (Example)' || selectedDestination == 'Westfield Sydney') {
        // Refresh example map data (only slot statuses, preserve structure)
        await _refreshExampleMapPreservingPaths();
      } else {
        // Refresh from API (only slot statuses, preserve structure)
        await _refreshMapFromAPIPreservingPaths(selectedDestination!);
      }
      
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
        // debugPrint('MapOnlyScreen: Navigation paths preserved during refresh');
      }
      
      // Restore the level selection after refresh
      if (mounted && currentLevel != null) {
        setState(() {
          selectedLevel = currentLevel;
          _levelController.text = 'Level $selectedLevel';
        });
      }
      
      // debugPrint('MapOnlyScreen: Auto-refresh completed successfully - level preserved: $currentLevel');
    } catch (e) {
      // debugPrint('MapOnlyScreen: Auto-refresh failed: $e');
      // Don't show error to user for background refresh
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Refresh example map data preserving paths (optimized for auto-refresh)
  Future<void> _refreshExampleMapPreservingPaths() async {
    if (maps.isEmpty) return;
    
    // Only update slot statuses, preserve existing map structure and paths
    for (var mapLevel in maps) {
      if (mapLevel.level == 1) {
        // Update level 1 slots with potentially new statuses
        for (var slot in mapLevel.slots) {
          if (slot['x'] == 2 && slot['y'] == 2) {
            slot['status'] = 'available';
          } else if (slot['x'] == 2 && slot['y'] == 3) {
            slot['status'] = 'available';
          } else if (slot['x'] == 3 && slot['y'] == 2) {
            slot['status'] = 'available';
          } else if (slot['x'] == 3 && slot['y'] == 3) {
            slot['status'] = 'available';
          }
        }
      } else if (mapLevel.level == 2) {
        // Update level 2 slots with potentially new statuses
        for (var slot in mapLevel.slots) {
          if (slot['x'] == 2 && slot['y'] == 2) {
            slot['status'] = 'occupied';
          } else if (slot['x'] == 2 && slot['y'] == 3) {
            slot['status'] = 'allocated';
          } else if (slot['x'] == 3 && slot['y'] == 2) {
            slot['status'] = 'allocated';
          } else if (slot['x'] == 3 && slot['y'] == 3) {
            slot['status'] = 'occupied';
          }
        }
      }
    }
    
    // debugPrint('MapOnlyScreen: Updated example map slot statuses without recreating structure');
  }

  // Refresh map from API preserving paths (optimized for auto-refresh)
  Future<void> _refreshMapFromAPIPreservingPaths(String destination) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(destination))),
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
          
          // Update only slot statuses from new data, preserve existing structure
          for (var existingMap in maps) {
            final correspondingNewMap = newMaps.firstWhere(
              (newMap) => newMap.level == existingMap.level,
              orElse: () => newMaps.first,
            );
            
            // Update slot statuses only
            existingMap.slots.clear();
            existingMap.slots.addAll(correspondingNewMap.slots);
            // debugPrint('MapOnlyScreen: Updated slot statuses for level ${existingMap.level}');
                    }
        }
      }
    } catch (e) {
      // debugPrint('MapOnlyScreen: Failed to refresh map from API: $e');
      // Don't throw error, just log it for silent background refresh
    }
  }

  // Original refresh example map data (for full reload scenarios)
  Future<void> _refreshExampleMap() async {
    // Create first level of example map with potentially updated slot statuses
    final exampleMap1 = ParkingMap(
      building: 'Westfield Sydney (Example)',
      level: 1,
      rows: 6,
      cols: 6,
      entrances: [
        {'x': 0, 'y': 3, 'type': 'car'},
        {'x': 3, 'y': 0, 'type': 'building'}
      ],
      exits: [
        {'x': 5, 'y': 3},
      ],
      slots: [
        {'x': 2, 'y': 2, 'status': 'available'},
        {'x': 2, 'y': 3, 'status': 'available'},
        {'x': 3, 'y': 2, 'status': 'available'},
        {'x': 3, 'y': 3, 'status': 'available'},
      ],
      corridors: [
        {
          'points': [[1, 1], [2, 1], [3, 1], [4, 1]], // bottom horizontal
          'direction': 'both'
        },
        {
          'points': [[4, 1], [4, 2], [4, 3], [4, 4]], // right vertical
          'direction': 'both'
        },
        {
          'points': [[4, 4], [3, 4], [2, 4], [1, 4]], // top horizontal
          'direction': 'both'
        },
        {
          'points': [[1, 4], [1, 3], [1, 2], [1, 1]], // left vertical
          'direction': 'both'
        },
        {
          'points': [[0, 3], [1, 3]], // entrance access
          'direction': 'both'
        },
        {
          'points': [[4, 3], [5, 3]], // exit access
          'direction': 'both'
        },
        {
          'points': [[3, 1], [3, 0]], // building access
          'direction': 'both'
        }
      ],
      walls: [
        {
          'points': [[0, 0], [5, 0]]
        },
        {
          'points': [[5, 0], [5, 5]]
        },
        {
          'points': [[5, 5], [0, 5]]
        },
        {
          'points': [[0, 5], [0, 0]]
        }
      ],
      ramps: [
        {'x': 1, 'y': 0}
      ]
    );
    
    // Create second level of example map
    final exampleMap2 = ParkingMap(
      building: 'Westfield Sydney (Example)',
      level: 2,
      rows: 6,
      cols: 6,
      entrances: [
        {'x': 3, 'y': 0, 'type': 'building'},
      ],
      exits: [
        {'x': 5, 'y': 3},
      ],
      slots: [
        {'x': 2, 'y': 2, 'status': 'occupied'},
        {'x': 2, 'y': 3, 'status': 'allocated'},
        {'x': 3, 'y': 2, 'status': 'allocated'},
        {'x': 3, 'y': 3, 'status': 'occupied'},
      ],
      corridors: [
        {
          'points': [[1, 1], [2, 1], [3, 1], [4, 1]], // bottom horizontal
          'direction': 'both'
        },
        {
          'points': [[4, 1], [4, 2], [4, 3], [4, 4]], // right vertical
          'direction': 'both'
        },
        {
          'points': [[4, 4], [3, 4], [2, 4], [1, 4]], // top horizontal
          'direction': 'both'
        },
        {
          'points': [[1, 4], [1, 3], [1, 2], [1, 1]], // left vertical
          'direction': 'both'
        },
        {
          'points': [[4, 3], [5, 3]], // exit access
          'direction': 'both'
        },
        {
          'points': [[3, 1], [3, 0]], // building access
          'direction': 'both'
        }
      ],
      walls: [
        {
          'points': [[0, 0], [5, 0]]
        },
        {
          'points': [[5, 0], [5, 5]]
        },
        {
          'points': [[5, 5], [0, 5]]
        },
        {
          'points': [[0, 5], [0, 0]]
        }
      ],
      ramps: [
        {'x': 1, 'y': 0}
      ]
    );
    
    setState(() {
      maps = [exampleMap1, exampleMap2];
    });
  }

  // Refresh map data from API
  Future<void> _refreshMapFromAPI(String destination) async {
    final response = await http.get(
      Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(destination))),
      headers: ApiConfig.headers,
    ).timeout(const Duration(seconds: 10));

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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: Text(selectedDestination ?? 'Loading Map...'),
          backgroundColor: const Color(0xFFA3DB94),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBackToInitialMap,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(selectedDestination ?? 'View Map'),
          backgroundColor: const Color(0xFFA3DB94),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBackToInitialMap,
          ),
        ),
        body: Container(
          color: const Color(0xFFD4EECD),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    errorMessage!,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        errorMessage = null;
                        isLoading = true;
                      });
                      _loadDestinationAndMap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA3DB94),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    final int maxLevel = maps
        .map((map) => map.level)
        .fold(0, (prev, curr) => curr > prev ? curr : prev);

    ParkingMap? currentMap;
    try {
      currentMap = maps.firstWhere(
        (map) => map.level == selectedLevel,
      );
    } catch (e) {
      if (maps.isNotEmpty) {
        currentMap = maps.first;
        selectedLevel = currentMap.level;
        _levelController.text = 'Level $selectedLevel';
      }
    }

    if (currentMap == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(selectedDestination ?? 'View Map'),
          backgroundColor: const Color(0xFFA3DB94),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBackToInitialMap,
          ),
        ),
        body: Container(
          color: const Color(0xFFD4EECD),
          child: const Center(
            child: Text('No map data available.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            children: [
              const TextSpan(
                text: 'Real-time Parking',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' • ${selectedDestination?.replaceAll(' (Example)', '') ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFA3DB94),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackToInitialMap,
        ),
      ),
      body: Column(
        children: [
          // Level selector - made more compact
          if (maxLevel > 1)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA3DB94),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Level $selectedLevel',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: selectedLevel! > 1
                            ? () async {
                                setState(() {
                                  _isLevelSwitching = true;
                                });
                                
                                final newLevel = selectedLevel! - 1;
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setInt('map_selected_level', newLevel);
                                // debugPrint('MapOnlyScreen: Level changed to $newLevel (down button)');
                                
                                setState(() {
                                  selectedLevel = newLevel;
                                  _levelController.text = 'Level $selectedLevel';
                                  _isLevelSwitching = false;
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedLevel! > 1 
                              ? const Color(0xFFA3DB94) 
                              : Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(6),
                          elevation: selectedLevel! > 1 ? 1 : 0,
                          minimumSize: const Size(32, 32),
                        ),
                        child: const Icon(Icons.keyboard_arrow_down, size: 20),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: selectedLevel! < maxLevel
                            ? () async {
                                setState(() {
                                  _isLevelSwitching = true;
                                });
                                
                                final newLevel = selectedLevel! + 1;
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setInt('map_selected_level', newLevel);
                                // debugPrint('MapOnlyScreen: Level changed to $newLevel (up button)');
                                
                                setState(() {
                                  selectedLevel = newLevel;
                                  _levelController.text = 'Level $selectedLevel';
                                  _isLevelSwitching = false;
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedLevel! < maxLevel 
                              ? const Color(0xFFA3DB94) 
                              : Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(6),
                          elevation: selectedLevel! < maxLevel ? 1 : 0,
                          minimumSize: const Size(32, 32),
                        ),
                        child: const Icon(Icons.keyboard_arrow_up, size: 20),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          // Enlarged map container
          Expanded(
            flex: 7, // Give more space to the map
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ParkingMapWidget(
                    map: currentMap,
                    isOperator: false,
                    preview: true,
                    selectedX: selectedX,
                    selectedY: selectedY,
                    selectedLevel: selectedLevel,
                    onTapCell: null,
                  ),
                ),
              ),
            ),
          ),
          // Compact legend and button section
          Container(
            constraints: const BoxConstraints(maxHeight: 180), // Limit max height
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F0F8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6.0, left: 4.0),
                      child: Text(
                        'Map Legend',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const CompactParkingMapLegend(),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            if (selectedDestination != null) {
                              final cleanedDestination = selectedDestination!
                                  .replaceAll(' (Example)', '')
                                  .trim();
                              await prefs.setString('selected_destination', cleanedDestination);
                            }
                            Navigator.pushNamed(context, '/estimation-fee');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            foregroundColor: Colors.black87,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.monetization_on_outlined, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Check Fee Estimation', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                )
                              ),
                            ],
                          ),
                        ),
                      ),
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
} 

class CompactParkingMapLegend extends StatelessWidget {
  const CompactParkingMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        children: [
          // First row - parking spots
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildCompactLegendItem(Colors.green, 'Available'),
              _buildCompactLegendItem(Colors.yellow, 'Allocated'),
              _buildCompactLegendItem(Colors.red, 'Occupied'),
              _buildCompactLegendItem(Colors.orange, 'Vehicle Entry'),
              _buildCompactLegendItem(Colors.purple, 'Building Entry'),
            ],
          ),
          const SizedBox(height: 4),
          // Second row - structure elements
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildCompactLegendItem(Colors.brown, 'Exit'),
              _buildCompactLegendItem(Colors.pinkAccent, 'Ramp'),
              _buildCompactLegendItem(Colors.grey, 'Wall'),
              _buildCompactLegendItem(Colors.transparent, 'Corridor'),
              _buildCompactLegendItem(const Color(0xFF3498DB), 'Navigation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLegendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              border: color == Colors.transparent
                  ? Border.all(color: Colors.black, width: 0.8)
                  : null,
              borderRadius: BorderRadius.circular(2),
              boxShadow: color != Colors.transparent
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 0.5,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Keep original legend class for backward compatibility
class EnhancedParkingMapLegend extends StatelessWidget {
  const EnhancedParkingMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.start,
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
          _buildLegendItem(const Color(0xFF2ECC71), 'To Destination')
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              border: color == Colors.transparent
                  ? Border.all(color: Colors.black, width: 1)
                  : null,
              borderRadius: BorderRadius.circular(4),
              boxShadow: color != Colors.transparent
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 1,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 