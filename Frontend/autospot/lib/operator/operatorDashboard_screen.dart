import 'package:autospot/models/parking_map.dart';
import 'package:autospot/operator/operatorCheckAndEditLotInfo_screen.dart';
import 'package:autospot/widgets/parkingMap/legend.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class OperatorDashboardScreen extends StatefulWidget {
  const OperatorDashboardScreen({super.key});

  @override
  State<OperatorDashboardScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<OperatorDashboardScreen> {
  List<ParkingMap> maps = [];
  bool isLoading = true;
  String? building;
  int? selectedLevel;
  int? selectedX;
  int? selectedY;

  late TextEditingController _levelController;
  
  // Auto-refresh timer for real-time data sync
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    selectedLevel = 1;
    _levelController = TextEditingController(text: 'Level $selectedLevel');
    fetchParkingMaps();
    _startAutoRefresh(); // Start auto-refresh for real-time sync
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Start auto-refresh timer for real-time data synchronization
  void _startAutoRefresh() {
    // Refresh every 15 seconds for operator dashboard
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && building != null) {
        // debugPrint('Auto-refreshing operator dashboard for real-time sync');
        _refreshParkingData();
      }
    });
  }

  // Refresh parking data without showing loading indicator
  Future<void> _refreshParkingData() async {
    if (building == null) return;
    
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(building!))),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            maps = (decoded['map']['parking_map'] as List)
                .map((e) => ParkingMap.fromJson(e))
                .toList();
          });
        }
        
        // debugPrint('Operator dashboard auto-refresh completed successfully');
      }
    } catch (e) {
      // debugPrint('Operator dashboard auto-refresh failed: $e');
      // Don't show error to user for background refresh
    }
  }

  // Fetches the parking map from API for the operator's building.
  Future<void> fetchParkingMaps() async {
    final prefs = await SharedPreferences.getInstance();
    building = prefs.getString('building');

    final response = await http.get(
      Uri.parse(ApiConfig.getParkingMapByBuilding(Uri.encodeComponent(building!))),
      headers: ApiConfig.headers,
    );

    final decoded = json.decode(response.body);

    if (response.statusCode == 200) {
      setState(() {
        maps = (decoded['map']['parking_map'] as List)
            .map((e) => ParkingMap.fromJson(e))
            .toList();
        isLoading = false;
      });

      if (maps.isEmpty) {
        // debugPrint('WARNING: API returned empty parking map');
      }
    } else {
      throw Exception('Failed to load parking map');
    }
  }

  final int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final int maxLevel = maps
        .map((map) => map.level)
        .fold(0, (prev, curr) => curr > prev ? curr : prev);

    final ParkingMap currentMap = maps.firstWhere(
      (map) => map.level == selectedLevel,
      orElse: () => maps[0],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4EECD),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'AutoSpot',
          style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Parking Map - ${currentMap.building} Level ${currentMap.level}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                ParkingMapWidget(
                  map: currentMap,
                  isOperator: true,
                  preview: true,
                  selectedX: selectedX,
                  selectedY: selectedY,
                  selectedLevel: selectedLevel,
                  onTapCell: (x, y) {
                    setState(() {
                      selectedX = x;
                      selectedY = y;
                    });
                  },
                ),
                const SizedBox(height: 5),
                const ParkingMapLegend(),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedX == null || selectedY == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please select a lot first.")),
                              );
                              return;
                            }

                            final slot = currentMap.slots.firstWhere(
                              (s) => s['x'] == selectedX && s['y'] == selectedY,
                              orElse: () => null,
                            );

                            if (slot == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("No lot found at the selected location.")),
                              );
                              return;
                            }

                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) => LotInfoDialog(
                                slotId: slot['slot_id'] ?? '-',
                                status: slot['status'] ?? '-',
                                allocatedUser: slot['allocatedUser'] ?? '-',
                                fullName: '-',
                                plateNumber: '-',
                                phoneNumber: '-',
                              ),
                            );

                            if (result != null) {
                              setState(() {
                                slot['status'] = result['status'];
                                slot['allocatedUser'] = result['allocatedUser'];
                              });

                              // Optional: Send PATCH/PUT request to server to persist it
                            }

                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Check Lot Info', style: TextStyle(color: Colors.black)),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showLevelPicker(context, maxLevel),
                          child: AbsorbPointer(
                            child: TextFormField(
                              readOnly: true,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Select Level',
                                filled: true,
                                fillColor: const Color(0xFFA3DB94),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              controller: _levelController,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: const Color(0xFFD4EECD),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamedAndRemoveUntil(context, '/operator_dashboard', (route) => false);
          } else if (index == 3) {
            Navigator.pushNamedAndRemoveUntil(context, '/operator_profile', (route) => false);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // Shows a modal picker for selecting the parking level
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
}
