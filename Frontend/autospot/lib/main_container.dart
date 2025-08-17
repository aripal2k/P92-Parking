import 'package:flutter/material.dart';
import 'package:autospot/user/userDashboard_screen.dart';
import 'package:autospot/user/userCheckParking_screen.dart';
import 'package:autospot/user/userInitialMap_screen.dart';
import 'package:autospot/user/userWallet_screen.dart';
import 'package:autospot/user/userProfile_screen.dart';
import 'package:autospot/user/userCarbonEmission_screen.dart';
import 'package:autospot/user/userActiveParking_screen.dart';
import 'package:autospot/user/userMapOnly_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainContainer extends StatefulWidget {
  final int initialIndex;
  
  const MainContainer({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;
  
  // Constants for navigation
  static const int HOME_INDEX = 0;
  static const int MAP_INDEX = 1;
  static const int PLANT_INDEX = 2;
  static const int QR_INDEX = 3;  // This index is only for BottomNavigationBar
  static const int WALLET_INDEX = 4;
  static const int PROFILE_INDEX = 5;
  
  // Maintain instances of our main screens (excluding QR scanner)
  late List<Widget> _screens;
  
  // Initialize page controller for smooth transitions
  PageController? _pageController;
  
  @override
  void initState() {
    super.initState();
    
    // Check if we should auto-navigate to Map tab due to active session
    _checkAndSetInitialTab();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Force refresh map screen when returning from payment/session end screens
    final route = ModalRoute.of(context);
    if (route != null && route.settings.name == '/dashboard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // debugPrint('Returned to dashboard - refreshing map state');
        _forceRefreshMapScreen();
      });
    }
  }
  
  Future<void> _forceRefreshMapScreen() async {
    // debugPrint('Force refreshing map screen state...');
    
    // Safety check to avoid LateInitializationError
    try {
      final _ = _screens;
    } catch (e) {
      // debugPrint('Skipping map refresh - screens not initialized yet');
      return;
    }
    
    final mapScreen = await _getMapScreen();
    if (mounted) {
      setState(() {
        _screens[MAP_INDEX] = mapScreen;
      });
    }
  }
  
  // Checks stored session data to determine the initial tab when the app starts
  void _checkAndSetInitialTab() async {
    final prefs = await SharedPreferences.getInstance();
    final hasActiveSession = prefs.getString('parking_start_time') != null;
    
    // If there's an active session, automatically go to Map tab
    int initialIndex = hasActiveSession ? MAP_INDEX : widget.initialIndex;
    
    setState(() {
      _selectedIndex = initialIndex;
      _pageController = PageController(initialPage: _getPageViewIndex(initialIndex));
    });

    
    int initialPageIndex = _getPageViewIndex(initialIndex);
    _pageController = PageController(initialPage: initialPageIndex);
    
    // Initialize screens array synchronously
    _initializeScreensSync();
  }
  
  // Creates the initial list of screens for PageView
  void _initializeScreensSync() {
    // Always start with InitialMapScreen as default to reset state
    Widget mapScreen = const InitialMapScreen();
    
    // Quick sync check for common case: QR scanned but no destination
    if (widget.initialIndex == MAP_INDEX) {
      // This is likely the case where user returned from destination selection
      // Use MapOnlyScreen as the default for better UX
      mapScreen = const MapOnlyScreen(key: ValueKey('map_only_default'));
    }
    
    // Initialize screens array with proper initial state
    _screens = [
      const DashboardScreen(),
      mapScreen,
      const UserCarbonEmissionScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];
    
    // Always update the map screen asynchronously for accuracy
    _updateMapScreenAsync();
  }
  
  // Updates the map screen asynchronously to ensure correct state
  Future<void> _updateMapScreenAsync() async {
    final mapScreen = await _getMapScreen();
    
    if (mounted) {
      // Only update if the screen type has actually changed
      if (_screens[MAP_INDEX].runtimeType != mapScreen.runtimeType) {
        setState(() {
          _screens[MAP_INDEX] = mapScreen;
        });
      }
    }
  }

  // Convert navigation index to page view index (skip QR scanner)
  int _getPageViewIndex(int navIndex) {
    if (navIndex < QR_INDEX) {
      return navIndex;  // Indices before QR are the same
    } else if (navIndex > QR_INDEX) {
      return navIndex - 1;  // Indices after QR need to be adjusted
    }
    return 0;  // Default to home if QR index is selected
  }
  
  // Convert page view index back to navigation index
  int _getNavIndex(int pageIndex) {
    if (pageIndex < QR_INDEX) {
      return pageIndex;  // Indices before QR are the same
    } else {
      return pageIndex + 1;  // Indices after QR need to be adjusted
    }
  }

  // Unified method to determine which map screen to show
  Future<Widget> _getMapScreen() async {
    final prefs = await SharedPreferences.getInstance();

    final entranceId = prefs.getString('entrance_id');
    final selectedDestination = prefs.getString('selected_destination');
    final hasValidNavigation = prefs.getBool('has_valid_navigation') ?? false;
    final storedStartTime = prefs.getString('parking_start_time');

    final hasScannedQR = entranceId != null;
    final hasSelectedDestination = selectedDestination != null;
    final hasActiveSession = storedStartTime != null;

    // debugPrint('_getMapScreen DEBUG:');
    // debugPrint('  - entrance_id: "$entranceId"');
    // debugPrint('  - selected_destination: "$selectedDestination"');
    // debugPrint('  - has_valid_navigation: $hasValidNavigation');
    // debugPrint('  - parking_start_time: "$storedStartTime"');
    // debugPrint('  - hasActiveSession: $hasActiveSession');
    // debugPrint('  - hasValidNavigation: $hasValidNavigation');
    // debugPrint('  - hasSelectedDestination: $hasSelectedDestination');
    // debugPrint('  - hasScannedQR: $hasScannedQR');

    // Priority order:
    // 1. Active parking session -> ActiveParkingScreen
    // 2. Has valid navigation (selected destination + paths) -> ParkingMapScreen with navigation
    // 3. Has scanned QR but no destination selected -> MapOnlyScreen (basic map view)
    // 4. Default -> InitialMapScreen
    
    if (hasActiveSession) {
      // debugPrint('Showing ActiveParkingScreen');
      return ActiveParkingScreen(
        startTime: DateTime.parse(storedStartTime),
        showNavigationBar: false, // Embedded in MainContainer, don't show navigation bar
      );
    } else if (hasValidNavigation && hasSelectedDestination) {
      // User has completed the full flow: QR + destination + paths
      // debugPrint('Showing ParkingMapScreen with navigation');
      return const ParkingMapScreen(forceShowMap: true);
    } else if (hasScannedQR) {
      // User has scanned QR but hasn't selected destination yet 
      // Use ParkingMapScreen for both basic and premium users to ensure consistent behavior
      // debugPrint('Showing ParkingMapScreen (unified experience for basic and premium users)');
      return const ParkingMapScreen(forceShowMap: true);
    } else {
      // Default state - show initial screen
      // debugPrint('Showing InitialMapScreen (default)');
      return const InitialMapScreen();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
  
  // Handles tapping a bottom navigation item
  void _onItemTapped(int navIndex) async {
    // Special case for QR scanner which needs to open as a separate page
    if (navIndex == QR_INDEX) {
      Navigator.pushNamed(context, '/qr-intro');  // Go to QR intro page first
      return;
    }
    
    // For map tab, update the screen based on current state (only if needed)
    if (navIndex == MAP_INDEX) {
      final mapScreen = await _getMapScreen();
      // Only update if the screen type has actually changed
      if (_screens[MAP_INDEX].runtimeType != mapScreen.runtimeType) {
        setState(() {
          _screens[MAP_INDEX] = mapScreen;
        });
      }
    }
    
    // Convert to pageView index (skipping QR scanner)
    int pageViewIndex = _getPageViewIndex(navIndex);
    
    setState(() {
      _selectedIndex = navIndex;
      // Animate to the correct page
      _pageController?.animateToPage(
        pageViewIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pageController != null ? PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping
        children: _screens,
        onPageChanged: (pageIndex) {
          // Convert page index back to navigation index
          int navIndex = _getNavIndex(pageIndex);
          
          setState(() {
            _selectedIndex = navIndex;
          });
        },
      ) : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.black,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: const Color(0xFFD4EECD),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.eco), label: 'Plant'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Helper class for navigating to specific tabs from anywhere in the app
class MainNavigator {
  static void navigateToTab(BuildContext context, int index) {
    // Find the MainContainer and update its state
    final mainContainer = context.findAncestorStateOfType<_MainContainerState>();
    if (mainContainer != null) {
      mainContainer._onItemTapped(index);
    } else {
      // If not found, navigate to main container with initial index
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MainContainer(initialIndex: index),
        ),
        (route) => false,
      );
    }
  }
} 