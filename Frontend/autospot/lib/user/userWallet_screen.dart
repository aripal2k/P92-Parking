import 'package:autospot/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double balance = 0.0;
  List<String> savedCards = [];
  List<Map<String, dynamic>> pendingPayments = [];
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  
  // Subscription related variables
  String subscriptionPlan = 'basic';
  String subscriptionStatus = 'active';
  DateTime? subscriptionExpiresAt;
  int? daysRemaining;
  double premiumPrice = 20.0;
  
  // Active parking session variables
  bool hasActiveSession = false;
  String? sessionId;
  DateTime? sessionStartTime;
  String? allocatedSlotId;
  Duration sessionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _checkActiveSession();
    // Remove duplicate call - _checkActiveSession() already calls this internally
    // _checkActiveSessionAndStore();
    _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  // Loads wallet data from the backend: balance, saved card, pending payments, tarnsaction history
  Future<void> _loadWalletData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    double walletBalance = 0.0;
    List<String> loadedCards = [];

    try {
      final balanceResponse = await http.get(
        Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (balanceResponse.statusCode == 200) {
        final balanceData = json.decode(balanceResponse.body);
        walletBalance = (balanceData['balance'] as num).toDouble();
        await prefs.setDouble('wallet_balance', walletBalance);
      } else {
        debugPrint('Failed to fetch wallet balance: ${balanceResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching wallet balance: $e');
    }

    // Call API to fetch saved cards
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getPaymentMethodsEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> cardList = json.decode(response.body);

        debugPrint('fetch cards: $cardList');

        loadedCards = cardList.map<String>((card) {
          final lastFour = card['last_four_digits'].toString().padLeft(4, '0');
          final cardHolder = card['cardholder_name'] ?? 'Unnamed';
          return '**** **** **** $lastFour - $cardHolder';
        }).toList();
      } else {
        debugPrint('Failed to fetch cards: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching cards: $e');
    }

    // Load pending payments
    List<Map<String, dynamic>> loadedPendingPayments = await _fetchPendingPaymentsFromBackend(email);

    // Load payment history
    List<Map<String, dynamic>> loadedHistory = await _fetchTransactionHistory(email);

    // Remove duplicate transactions: exclude pending transactions from history
    // since they're already shown in pending section
    final pendingTransactionIds = loadedPendingPayments
        .map((payment) => payment['transactionId'])
        .toSet();
    
    final originalHistoryCount = loadedHistory.length;
    loadedHistory = loadedHistory.where((transaction) => 
      !pendingTransactionIds.contains(transaction['transactionId'])
    ).toList();
    
    debugPrint('WalletScreen: Removed ${originalHistoryCount - loadedHistory.length} duplicate transactions from history');

    loadedPendingPayments.sort((a, b) =>
      DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));
    loadedHistory.sort((a, b) =>
      DateTime.parse(b['date'].toString()).compareTo(DateTime.parse(a['date'].toString())));

    if (!mounted) return;
      setState(() {
        balance = walletBalance;
        savedCards = loadedCards;
        pendingPayments = loadedPendingPayments;
        paymentHistory = loadedHistory;
        isLoading = false;
      });

  }

  // Fetches only pending payments from backend
  Future<List<Map<String, dynamic>>> _fetchPendingPaymentsFromBackend(String email) async {
    try {
      final uri = ApiConfig.getPendingPaymentsEndpoint(email: email);
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        // Filter to only show truly pending transactions (not completed ones)
        final filteredData = responseData.where((e) => 
          e['status']?.toString().toLowerCase() == 'pending'
        ).toList();

        return filteredData.map<Map<String, dynamic>>((e) {
          final description = e['description'] ?? '';
          final slotMatch = RegExp(r'slot (\w+)').firstMatch(description);
          final locationMatch = RegExp(r'at (.+)$').firstMatch(description);

          return {
            'transactionId': e['transaction_id'],
            'amount': (e['amount'] as num).toDouble(),
            'status': e['status'],
            'date': e['created_at'],
            'slot': slotMatch?.group(1) ?? 'Unknown',
            'location': locationMatch?.group(1) ?? 'Unknown',
            'sessionId': e['session_id'] ?? 'Unknown', // if sessionId is not in API, default
          };
        }).toList();
      } else {
        debugPrint('Failed to fetch pending payments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching pending payments: $e');
    }

    return [];
  }

  // Check for active parking session
  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();

    final storedSessionId = prefs.getString('session_id');
    final storedStartTime = prefs.getString('parking_start_time');
    final storedSlotId = prefs.getString('allocated_spot_id');

    if (storedSessionId != null && storedStartTime != null) {
      final parsedStartTime = DateTime.tryParse(storedStartTime);

      if (parsedStartTime != null) {
        // Simplify time calculation - match ActiveParking screen logic
        final now = DateTime.now();
        final duration = now.difference(parsedStartTime);

        // Debug timing values
        debugPrint('WALLET DEBUG TIMING (simplified):');
        debugPrint('  storedStartTime: $storedStartTime');
        debugPrint('  parsedStartTime: $parsedStartTime');
        debugPrint('  now: $now');
        debugPrint('  calculated duration: $duration');

        setState(() {
          hasActiveSession = true;
          sessionId = storedSessionId;
          sessionStartTime = parsedStartTime; // Store original time
          allocatedSlotId = storedSlotId;
          sessionDuration = duration;
        });
        if (kDebugMode) {
          debugPrint('WALLET: Active session detected - Slot: ${allocatedSlotId ?? "Unknown"}, Duration: ${_formatDuration(sessionDuration)}');
        }
        _startSessionTimer();
        return;
      }
    }

    // If no local session found, fallback to API
    if (storedSessionId == null || storedStartTime == null) {
      debugPrint('WALLET: No local session found, checking API...');
      await _checkActiveSessionAndStore();

      // Try again after API restore
      final updatedSessionId = prefs.getString('session_id');
      final updatedStoredStartTime = prefs.getString('parking_start_time');
      final updatedSlotId = prefs.getString('allocated_spot_id');

    if (updatedSessionId != null && updatedStoredStartTime != null) {
      final parsedStartTime = DateTime.tryParse(updatedStoredStartTime);
      if (parsedStartTime != null) {
        // Simplify time calculation - match ActiveParking screen logic
        final now = DateTime.now();
        final duration = now.difference(parsedStartTime);

        setState(() {
          hasActiveSession = true;
          sessionId = updatedSessionId;
          sessionStartTime = parsedStartTime; // Store original time
          allocatedSlotId = updatedSlotId;
          sessionDuration = duration;
        });
        _startSessionTimer();
      }
    }
    }
  }

  // Fallback to fetch session from /session/active
  Future<void> _checkActiveSessionAndStore() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final vehicleId = prefs.getString('vehicle_id');
    final updatedSlotId = prefs.getString('allocated_spot_id');

    if (username == null || vehicleId == null || updatedSlotId == null) return;

    final uri = Uri.parse('${ApiConfig.baseUrl}/session/active?username=$username&vehicle_id=$vehicleId');

    try {
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final session = jsonData['session'];

        // Parse and normalize the start_time to ensure consistent format
        final startTimeFromApi = DateTime.parse(session['start_time']);
        
        await prefs.setString('session_id', session['session_id']);
        await prefs.setString('allocated_spot_id', session['slot_id']);
        await prefs.setString('vehicle_id', session['vehicle_id']);
        await prefs.setString('parking_start_time', startTimeFromApi.toIso8601String());
        
        // debugPrint('Active session restored: '
        //  'session_id=${session['session_id']}, '
        //  'slot_id=${session['slot_id']}, '
        //  'vehicle_id=${session['vehicle_id']}, '
        //  'start_time=${session['start_time']}');
      } else {
        // debugPrint('No active session found or not 200');
        await prefs.remove('session_id');
        await prefs.remove('parking_start_time');
        await prefs.remove('allocated_spot_id');
      }
    } catch (e) {
      debugPrint('Error fetching active session: $e');
    }
  }

  Timer? _sessionTimer;
  
  // Starts a timer to update parking session duration every second
  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionStartTime != null && mounted) {
        // Simplify timer logic - match ActiveParking screen
        final now = DateTime.now();
        setState(() {
          sessionDuration = now.difference(sessionStartTime!);
        });
      }
    });
  }

  // Stops the currently active parking session by clearing any saved session data 
  Future<void> _stopActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Show confirmation dialog
    bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('End Parking Session'),
          content: const Text('Are you sure you want to end your current parking session? This will also clear the session from the server.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('End Session'),
            ),
          ],
        );
      },
    );

    if (shouldStop == true) {
      try {
        // Call backend API to delete the session
        if (sessionId != null) {
          final username = prefs.getString('username') ?? '';
          final vehicleId = prefs.getString('vehicle_id') ?? '';
          
          final uri = Uri.parse('${ApiConfig.baseUrl}/session/delete?session_id=$sessionId&username=$username&vehicle_id=$vehicleId');
          
          final response = await http.delete(uri, headers: ApiConfig.headers);
          
          if (response.statusCode == 200) {
            debugPrint('Session deleted from backend successfully');
          } else {
            debugPrint('Failed to delete session from backend: ${response.statusCode}');
            // Continue with local cleanup even if backend fails
          }
        }
        
        // Clear ALL session and navigation related data to completely reset state
        await prefs.remove('session_id');
        await prefs.remove('parking_start_time');
        await prefs.remove('allocated_spot_id');
        await prefs.remove('temp_parking_start_time');
        await prefs.remove('temp_parking_end_time');
        await prefs.remove('temp_parking_duration_seconds');
        
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
        
        // Stop the timer
        _sessionTimer?.cancel();
        
        // Update UI
        setState(() {
          hasActiveSession = false;
          sessionId = null;
          sessionStartTime = null;
          allocatedSlotId = null;
          sessionDuration = Duration.zero;
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking session ended and cleared successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error stopping session: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error ending session: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Formats Duration into HH:MM:SS string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
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
          subscriptionStatus = data['status'] ?? 'active';
          daysRemaining = data['days_remaining'];
          
          if (data['expires_at'] != null) {
            subscriptionExpiresAt = DateTime.parse(data['expires_at']);
          }
        });
      } else {
        debugPrint('Failed to load subscription status: ${response.statusCode}');
      }
      
      // Load pricing info
      final pricingResponse = await http.get(
        Uri.parse(ApiConfig.subscriptionPricingEndpoint),
        headers: ApiConfig.headers,
      );
      
      if (pricingResponse.statusCode == 200) {
        final pricingData = json.decode(pricingResponse.body);
        setState(() {
          premiumPrice = (pricingData['premium_monthly_price'] as num).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
    }
  }

  // Upgrade to premium subscription
  Future<void> _upgradeSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check sufficient balance
    if (balance < premiumPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Need \$${premiumPrice.toStringAsFixed(2)} but only have \$${balance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    bool? shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upgrade to Premium'),
          content: Text(
            'Upgrade to Premium membership for \$${premiumPrice.toStringAsFixed(2)}/month?\n\n'
            'Premium benefits:\n'
            '• Up to 3 pending payments (vs 1 for basic)\n'
            '• Choose any available parking slot\n'
            '• Custom pathfinding to selected slots'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Upgrade', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    
    if (shouldUpgrade != true) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.subscriptionUpgradeEndpoint),
        headers: ApiConfig.headers,
        body: json.encode({'email': email}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Reload wallet data and subscription status
        await _loadWalletData();
        await _loadSubscriptionStatus();
        
        if (mounted) {
          // Show success dialog with navigation options
          _showUpgradeSuccessDialog(data['message'] ?? 'Successfully upgraded to premium!');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['detail'] ?? 'Failed to upgrade subscription'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error upgrading subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error upgrading subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Show upgrade success dialog with navigation options
  void _showUpgradeSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Upgrade Successful!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'You can now enjoy Premium features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Choose any available parking slot'),
              const Text('• Custom pathfinding to selected slots'),
              const Text('• Up to 3 pending payments'),
              const SizedBox(height: 16),
              const Text(
                'Would you like to return to the parking map to use your new Premium features?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog only
              },
              child: const Text('Stay Here'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate back to parking map
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/parking-map',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Map'),
            ),
          ],
        );
      },
    );
  }

  // Attempts to complete a pending payment for a parking transaction
  Future<void> _payPendingPayment(Map<String, dynamic> payment) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    final transactionId = payment['transactionId'];

    if (balance < (payment['amount'] as num).toDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient wallet balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        ApiConfig.payPendingWithWalletEndpoint(
          email: email,
          transactionId: transactionId,
        ),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        // Update local wallet balance from backend
        await _loadWalletData();

        await prefs.remove('allocated_spot_id');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final body = json.decode(response.body);
        final error = body['detail'] ?? 'Failed to complete payment';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error paying with wallet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          backgroundColor: const Color(0xFFD4EECD),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'AutoSpot',
            style: TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4EECD),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadWalletData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Fake Card with Gradient and Balance
                Container(
                  width: double.infinity,
                  height: 180,
                  padding: const EdgeInsets.all(24),
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
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'AutoSpot Wallet',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Subscription Status Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: subscriptionPlan == 'premium' 
                        ? Colors.orange.shade50 
                        : Colors.grey.shade50,
                    border: Border.all(
                      color: subscriptionPlan == 'premium' 
                          ? Colors.orange.shade300 
                          : Colors.grey.shade300, 
                      width: 2
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (subscriptionPlan == 'premium' 
                            ? Colors.orange 
                            : Colors.grey).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            subscriptionPlan == 'premium' 
                                ? Icons.workspace_premium 
                                : Icons.person,
                            color: subscriptionPlan == 'premium' 
                                ? Colors.orange.shade700 
                                : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            subscriptionPlan == 'premium' 
                                ? 'Premium Member' 
                                : 'Basic Member',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: subscriptionPlan == 'premium' 
                                  ? Colors.orange.shade800 
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (subscriptionPlan == 'premium') ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text(
                                daysRemaining != null 
                                    ? '$daysRemaining days left'
                                    : 'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (subscriptionPlan == 'basic') ...[
                        Text(
                          'Current Benefits:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 1 pending payment allowed\n'
                          '• System-allocated parking slots',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _upgradeSubscription,
                            icon: const Icon(Icons.upgrade, color: Colors.white),
                            label: Text(
                              'Upgrade to Premium (\$${premiumPrice.toStringAsFixed(2)}/month)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Premium Benefits:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Up to 3 pending payments\n'
                          '• Choose any available parking slot\n'
                          '• Custom pathfinding to selected slots',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade600,
                          ),
                        ),
                        if (subscriptionExpiresAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Expires: ${subscriptionExpiresAt!.day}/${subscriptionExpiresAt!.month}/${subscriptionExpiresAt!.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Active Parking Session Section
                if (hasActiveSession) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade700, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Active Parking Session',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Session details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Slot: ${allocatedSlotId ?? "Unknown"}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Started: ${sessionStartTime != null ? "${sessionStartTime!.hour.toString().padLeft(2, '0')}:${sessionStartTime!.minute.toString().padLeft(2, '0')}" : "Unknown"}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Text(
                                _formatDuration(sessionDuration),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Stop session button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _stopActiveSession,
                            icon: const Icon(Icons.stop_circle, color: Colors.white),
                            label: const Text(
                              'End Parking Session',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                //Top up Wallet -> go to the Top up Page
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final shouldReload = await Navigator.pushNamed(context, '/wallet/add-money');
                      if (shouldReload == true) {
                        if (mounted) {
                          _loadWalletData();
                        }
                      }
                    },
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      'Top Up',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA3DB94),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ),

                // Pending Payments Section
                if (pendingPayments.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Payments',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${pendingPayments.length} items',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ...pendingPayments.map((payment) => _buildPendingPaymentCard(payment)),
                ],

                const SizedBox(height: 32),
                const Text(
                  'Your Cards',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Saved Cards
                if (savedCards.isNotEmpty)
                  ...savedCards.map((card) => Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.credit_card),
                          title: Text(card),
                        ),
                      )),

                // Add Card Button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      // Show add card dialog
                      _showAddCardDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Add Card',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                    ),
                  ),
                ),

                // Payment History Section
                if (paymentHistory.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaction History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${paymentHistory.length} transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ...paymentHistory.take(5).map((payment) => _buildHistoryCard(payment)),

                  if (paymentHistory.length > 5)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // View full history
                        },
                        child: const Text('View Full History'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
          ),
        ),

      // No bottom navigation bar - this is handled by the MainContainer
    );
  }

  // Fetches the user's transaction history from the backend
  Future<List<Map<String, dynamic>>> _fetchTransactionHistory(String email) async {
    try {
      final uri = ApiConfig.getTransactionHistoryEndpoint(email: email, limit: 100);
      final response = await http.get(uri, headers: ApiConfig.headers);

      if (response.statusCode == 200) {
        final List<dynamic> transactions = json.decode(response.body);

        return transactions.map<Map<String, dynamic>>((tx) {
          final description = tx['description'] ?? '';
          final slotMatch = RegExp(r'slot (\w+)').firstMatch(description);
          final locationMatch = RegExp(r'at (.+)$').firstMatch(description);

          return {
            'transactionId': tx['transaction_id'],
            'amount': (tx['amount'] as num).toDouble(),
            'type': tx['transaction_type'],
            'status': tx['status'],
            'location': locationMatch?.group(1) ?? 'Top Up',
            'slot': slotMatch?.group(1) ?? '',
            'method': tx['transaction_type'] == 'add_money' ? 'Top Up' : 'Wallet',
            'date': tx['created_at'],
            'description': description,
          };
        }).toList();
      } else {
        debugPrint('Failed to fetch transactions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching transaction history: $e');
    }

    return [];
  }

  // Builds a styled card widget to display details of a pending payment
  Widget _buildPendingPaymentCard(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num).toDouble();
    final date = DateTime.parse(payment['date'].toString());
    final location = payment['location'] as String? ?? 'Unknown';
    final slot = payment['slot'] as String? ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              location,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Slot: $slot',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to payment screen
                      Navigator.pushNamed(
                        context,
                        '/payment',
                        arguments: {
                          'amount': amount,
                          'sessionId': payment['sessionId'],
                          'parkingLocation': location,
                          'parkingSlot': slot,
                          'parkingDate': date,
                        },
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Pay with Card'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: balance >= amount
                        ? () => _payPendingPayment(payment)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('Pay from Wallet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds a styled card widget to display a single transaction history entry
  Widget _buildHistoryCard(Map<String, dynamic> tx) {
    debugPrint('Transaction entry: $tx'); // DEBUG: see actual contents

    final rawCreatedAt = tx['date'];
    final rawType = tx['type'];

    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final date = rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt.toString()) : null;
    final description = tx['description'] ?? 'No description';
    final type = rawType?.toString().toLowerCase();

    // Choose icon and color based on transaction type
      final isTopUp = type == 'add_money';
      final icon = isTopUp ? Icons.add_circle : Icons.local_parking;
      final color = isTopUp ? Colors.green : Colors.deepPurple;
      final bgColor = isTopUp ? Colors.green.shade50 : Colors.deepPurple.shade50;
      final label = isTopUp ? 'Top Up' : 'Parking Payment';


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    date != null
                      ? '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                      : 'Unknown date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardDialog() {
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    bool isDefaultCard = false;


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Card'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                maxLength: 19,
              ),
              TextFormField(
                controller: cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: expiryController,
                      decoration: const InputDecoration(
                        labelText: 'MM/YY',
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        prefixIcon: Icon(Icons.security),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Set as Default',
                    style: TextStyle(fontSize: 16),
                  ),
                  Switch(
                    value: isDefaultCard,
                    onChanged: (value) {
                      isDefaultCard = value;
                      (context as Element).markNeedsBuild(); // to rebuild the dialog
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate input
              final cardNumber = cardNumberController.text.trim();
              final cardHolder = cardHolderController.text.trim();
              final expiry = expiryController.text.trim();
              final cvv = cvvController.text.trim();

              if (cardNumber.length < 15 || cardNumber.length > 19 ||
                  cardHolder.isEmpty ||
                  expiry.isEmpty ||
                  (cvv.length != 3 && cvv.length != 4)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid card details.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final expiryParts = expiry.split('/');
              if (expiryParts.length != 2) return;

              final expiryMonthStr = expiryParts[0].padLeft(2, '0');
              final expiryMonth = int.tryParse(expiryMonthStr);
              final expiryYear = int.tryParse('20${expiryParts[1]}');

              if (expiryMonth == null || expiryYear == null || expiryMonth < 1 || expiryMonth > 12) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid expiry date.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final now = DateTime.now();
              final isExpired = (expiryYear < now.year) ||
                  (expiryYear == now.year && expiryMonth < now.month);

              if (isExpired) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Card is expired.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final prefs = await SharedPreferences.getInstance();
              final email = prefs.getString('user_email') ?? '';
              final username = prefs.getString('username') ?? '';


              final payload = {
                "email": email,
                "method_type": "credit_card",
                "username": username,
                "card_number": cardNumber,
                "expiry_month": expiryMonthStr,
                "expiry_year": expiryYear,
                "cvv": cvv,
                "cardholder_name": cardHolder,
                "is_default": isDefaultCard,
              };

              try {
                final response = await http.post(
                  Uri.parse(ApiConfig.addPaymentMethodEndpoint),
                  headers: ApiConfig.headers,
                  body: jsonEncode(payload),
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  Navigator.pop(context);
                  _loadWalletData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card added successfully')),
                  );
                } else {
                  final error = json.decode(response.body);
                  String errorMsg = 'Failed to add card';

                  if (error['detail'] is List && error['detail'].isNotEmpty) {
                    final firstDetail = error['detail'][0];
                    if (firstDetail is Map && firstDetail.containsKey('msg')) {
                      errorMsg = firstDetail['msg'];
                    }
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                  );
                }

              } catch (e) {
                debugPrint('$email $username $cardNumber $expiryMonthStr $expiryYear $cvv $cardHolder $isDefaultCard');
                debugPrint('Error adding card: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error connecting to server'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },

            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
