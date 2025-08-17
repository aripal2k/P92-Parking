import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'package:autospot/main_container.dart';
import 'package:autospot/user/userCheckParking_screen.dart';

// Screen for selecting the destination after scanning an entrance QR
class DestinationSelectScreen extends StatefulWidget {
  const DestinationSelectScreen({super.key});

  @override
  State<DestinationSelectScreen> createState() => _DestinationSelectScreenState();
}

class _DestinationSelectScreenState extends State<DestinationSelectScreen> {
  bool isLoading = false;
  String? entranceId;
  String? errorMessage;
  String? selectedDestination;
  List<String> destinations = [];
  
  @override
  void initState() {
    super.initState();
    _loadEntranceData();
    _fetchAvailableDestinations();
  }
  
  // Load stored entrance data from SharedPreferences
  Future<void> _loadEntranceData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEntranceId = prefs.getString('entrance_id');
    
    setState(() {
      entranceId = storedEntranceId;
    });
    
    if (entranceId == null) {
      setState(() {
        errorMessage = 'No entrance data found. Please scan a valid entrance QR code.';
      });
    }
  }
  
  // Fetch the list of available destinations from the server
  Future<void> _fetchAvailableDestinations() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // Try to fetch destination data from server
      final prefs = await SharedPreferences.getInstance();
      final entranceId = prefs.getString('entrance_id') ?? '';
      final building = prefs.getString('building_id') ?? '';

      // debugPrint('Fetching destinations, entrance ID: $entranceId, building: $building');

      // Build API request URL with entrance ID
      var url = Uri.parse(ApiConfig.getAvailableDestinationsEndpoint);
      if (entranceId.isNotEmpty && building.isNotEmpty) {
        url = Uri.parse(ApiConfig.getAvailableDestinationsEndpoint).replace(
          queryParameters: {
            'entrance_id': entranceId,
            'building_name': building,
          },
        );
      }

      // Add shorter timeout and handle network issues more aggressively
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        // debugPrint('API request timed out - using fallback data');
        throw TimeoutException('API request timed out');
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // debugPrint('Server returned destination data: $data');
        
        List<dynamic> destinationList = [];
        if (data.containsKey('destinations')) {
          destinationList = data['destinations'];
        } else if (data.containsKey('success') && data['success'] == true && data.containsKey('destinations')) {
          destinationList = data['destinations'];
        } else {
          // If API doesn't have destinations field, try other possible fields
          destinationList = data['points'] ?? [];
        }
        
        // Always use fallback if server returns empty list
        if (destinationList.isEmpty) {
          // debugPrint('Server returned empty destinations list, using fallback');
          destinationList = [
            'Westfield Sydney',
            'Building Entrance (BE1)',
            'Building Entrance (BE2)', 
            'Exit (X1)',
            'Exit (X2)'
          ];
        }
        
        setState(() {
          destinations = destinationList.map((d) => d.toString()).toList();
          isLoading = false;
        });
        
        // Debug output of parsed destinations
        // debugPrint('Parsed destinations: $destinations');
      } else {
        // debugPrint('Server returned error code: ${response.statusCode}');
        throw Exception('Failed to load destinations: ${response.statusCode}');
      }
    } catch (e) {
      // If server call fails, use mock data as fallback
      // debugPrint('Failed to fetch destinations: $e, using fallback data');
      
      // Use fallback data matching the map - NO delay this time
      setState(() {
        destinations = [
          'Westfield Sydney',
          'Building Entrance (BE1)',
          'Building Entrance (BE2)',
          'Exit (X1)',
          'Exit (X2)'
        ];
        isLoading = false;
      });
    }
  }
  
  // Process the selected destination and request the best parking spot
  Future<void> _processDestinationSelection() async {
    if (selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (entranceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entrance data found. Please scan again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      isLoading = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Get user email from SharedPreferences for authentication
      final email = prefs.getString('user_email');
      final building = prefs.getString('building_id') ?? 'Westfield Sydney';

      if (email == null) {
        throw Exception('User not logged in');
      }
      
      final targetPointId = _convertToPointId(selectedDestination!);
      
      // Save building name as selected_destination (for map API calls)
      // and target point ID separately (for pathfinding)
      await prefs.setString('selected_destination', building);
      await prefs.setString('target_point_id', targetPointId);
      
      // Construct the API URL with query parameters
      final url = '${ApiConfig.allocateSpotEndpoint}?entrance_id=$entranceId&target_point_id=$targetPointId&building_name=$building';
      
      // Call API to find nearest available slot and plan path
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // debugPrint('Server returned data: success=${data['success']}');
        
        // Save parking spot info
        if (data.containsKey('nearest_slot') && data['nearest_slot'] != null) {
          final slot = data['nearest_slot'];
          await prefs.setString('allocated_spot_id', slot['slot_id'] ?? 'Unknown');
          await prefs.setInt('slot_x', slot['x'] ?? 0);
          await prefs.setInt('slot_y', slot['y'] ?? 0);
          await prefs.setInt('slot_level', slot['level'] ?? 1);
          
          // debugPrint('Allocated spot: ${slot['slot_id']} at (${slot['x']}, ${slot['y']}, L${slot['level']})');
        } else {
          await prefs.setString('allocated_spot_id', 'No available spot');
        }
        
        // Save path from entrance to slot
        if (data.containsKey('route_from_entrance_to_slot') && 
            data['route_from_entrance_to_slot'] != null && 
            data['route_from_entrance_to_slot'].containsKey('path')) {
          final path = data['route_from_entrance_to_slot']['path'];
          await prefs.setString('navigation_path', jsonEncode(path));
          // debugPrint('Entrance to slot path: ${path.length} points');
        } else {
          await prefs.setString('navigation_path', jsonEncode([]));
        }
        
        // Save path from slot to destination
        if (data.containsKey('route_from_slot_to_target') && 
            data['route_from_slot_to_target'] != null && 
            data['route_from_slot_to_target'].containsKey('path')) {
          final path = data['route_from_slot_to_target']['path'];
          await prefs.setString('destination_path', jsonEncode(path));
          // debugPrint('Slot to destination path: ${path.length} points');
        }
        
        if (mounted) {
          // Navigate to parking map screen with allocated spot
          Navigator.pushNamed(context, '/parking-map');
        }
      } else {
        // Show specific error message based on HTTP status
        String errorMessage = 'Failed to allocate parking spot: ${response.statusCode}';
        if (response.statusCode == 404) {
          errorMessage = 'Route not found. Please check entrance and destination IDs.';
          // debugPrint('Error 404: Route not found with entrance_id=$entranceId, target_point_id=$targetPointId');
        } else if (response.statusCode == 500) {
          errorMessage = 'Server error occurred while planning route.';
          // debugPrint('Error 500: Server error processing request');
        }
        
        // debugPrint('API error: $errorMessage');
        // debugPrint('Response body: ${response.body}');
        throw Exception(errorMessage);
      }
    } catch (e) {
      // debugPrint('Error in parking allocation: $e');
      
      // Show error message and offer to retry or use demo data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to calculate path: $e\n\nWould you like to retry or use demo data?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isLoading = false;
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processDestinationSelection(); // Retry
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Use demo data (only as fallback)
                final prefs = await SharedPreferences.getInstance();
                String spotId = '1A';
                int spotX = 2;
                int spotY = 2;
                int spotLevel = 1;
                
                List<List<dynamic>> navigationPath = [];
                
                if (_convertToPointId(selectedDestination!) == 'X1') {
                  spotId = '1D';
                  spotX = 3;
                  spotY = 3;
                  spotLevel = 1;
                  
                  navigationPath = [
                    [1, 0, 3], [1, 1, 3], [1, 1, 4], [1, 2, 4],
                    [1, 3, 4], [1, 4, 4], [1, 4, 3], [1, 3, 3]
                  ];
                  
                  await prefs.setString('destination_path', jsonEncode([
                    [1, 3, 3], [1, 4, 3], [1, 5, 3]
                  ]));
                } else {
                  navigationPath = [[1, 0, 3], [1, 1, 3], [1, 1, 2], [1, 2, 2]];
                }
                
                await prefs.setString('allocated_spot_id', spotId);
                await prefs.setInt('slot_x', spotX);
                await prefs.setInt('slot_y', spotY);
                await prefs.setInt('slot_level', spotLevel);
                
                await prefs.setString('navigation_path', jsonEncode(navigationPath));
                
                // debugPrint('Using DEMO data for $selectedDestination');
                
                if (mounted) {
                  // Set flag in SharedPreferences to indicate we've selected a destination
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_valid_navigation', true);
                  
                  // Navigate directly to the detailed parking map
                  // We use pushAndRemoveUntil to clear the navigation stack
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => const ParkingMapScreen(forceShowMap: true),
                    ),
                    (route) => false,  // Clear all previous routes
                  );
                }
              },
              child: const Text('Use Demo Data'),
            ),
          ],
        ),
      );
      
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Convert destination name to point ID needed by API
  String _convertToPointId(String destination) {
    // If format is "Exit (X1)", extract "X1"
    if (destination.startsWith('Exit (') && destination.endsWith(')')) {
      final id = destination.substring(6, destination.length - 1);
      // debugPrint('Extracted exit ID: $id');
      return id;
    }
    
    // If format is "Building Entrance (BE1)", extract "BE1"
    if (destination.contains('(') && destination.contains(')')) {
      final idPattern = RegExp(r'\(([^)]+)\)');
      final match = idPattern.firstMatch(destination);
      if (match != null && match.groupCount >= 1) {
        final id = match.group(1)!;
  
        return id;
      }
    }
    
    // Handle special cases
    switch (destination) {
      case 'Westfield Sydney':
        // debugPrint('Special case: Westfield Sydney -> BE1');
        return 'BE1';  // Default to main entrance
      case 'Westfield Sydney1':
        // debugPrint('Special case: Westfield Sydney1 -> BE1');
        return 'BE1';  // Default to main entrance
      default:
        // debugPrint('Using destination as is: $destination');
        return destination;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Reset isLoading if it's been more than 10 seconds
    if (isLoading) {
      // Start a timer to force-exit loading state after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && isLoading) {
  
          setState(() {
            isLoading = false;
            // Set fallback destinations if needed
            if (destinations.isEmpty) {
              destinations = [
                'Westfield Sydney',
                'Building Entrance (BE1)',
                'Building Entrance (BE2)', 
                'Exit (X1)',
                'Exit (X2)'
              ];
            }
          });
        }
      });
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        title: const Text('Select Destination', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFA3DB94),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Clear QR scanning session data when user cancels destination selection
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('entrance_id');
            await prefs.remove('navigation_path');
            await prefs.remove('destination_path');
            await prefs.remove('allocated_spot_id');
            await prefs.remove('slot_x');
            await prefs.remove('slot_y');
            await prefs.remove('slot_level');
            await prefs.setBool('has_valid_navigation', false);
            
            // Clear navigation stack and return to map tab
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const MainContainer(initialIndex: 1), // 1 is MAP_INDEX
              ),
              (route) => false, // Remove all previous routes
            );
          },
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
                    ),
                    SizedBox(height: 20),
                    Text('Loading...', style: TextStyle(fontSize: 18)),
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/qr-scanner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA3DB94),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Scan Again'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Entrance information
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Entrance Detected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ID: ${entranceId ?? 'Unknown'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'Select Your Destination:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Destination list
                        Expanded(
                          child: ListView.builder(
                            itemCount: destinations.length,
                            itemBuilder: (context, index) {
                              final destination = destinations[index];
                              final isSelected = selectedDestination == destination;
                              
                              return Card(
                                elevation: isSelected ? 4 : 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                color: isSelected ? const Color(0xFFA3DB94) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? Colors.green : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    destination,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    setState(() {
                                      selectedDestination = destination;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _processDestinationSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA3DB94),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Find Best Parking Spot',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
} 