import 'package:autospot/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String sessionId;
  final String parkingLocation;
  final String parkingSlot;
  final DateTime parkingDate;
  
  const PaymentScreen({
    super.key,
    required this.amount,
    required this.sessionId,
    required this.parkingLocation,
    required this.parkingSlot,
    required this.parkingDate,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedPaymentMethod = 0; // 0 = wallet, 1 = card
  double walletBalance = 0.0;
  bool isProcessing = false;
  String? errorMessage;

  List<Map<String, dynamic>> savedCards = [];
  String? selectedCardId;

  
  // Card info controllers
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
          return {
            'success': true, 
            'message': data['message'],
            'transaction_id': data['transaction_id'], // Include transaction ID
          };
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
  
  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadWalletBalance();
    await _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getPaymentMethodsEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> cardList = json.decode(response.body);
        final List<Map<String, dynamic>> cards = cardList.cast<Map<String, dynamic>>();

        setState(() {
          savedCards = cards;
          if (cards.isNotEmpty) {
            selectedCardId = cards.firstWhere(
              (card) => card['is_default'] == true,
              orElse: () => cards.first,
            )['payment_method_id'];
          }
        });
      } else {
        // debugPrint('Failed to load cards: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Error fetching cards: $e');
    }
  }

  Future<void> _loadWalletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    
    if (email.isEmpty) {
      setState(() {
        walletBalance = 0.0;
      });
      return;
    }
    
    try {
      // Get real-time balance from backend API (same as main wallet screen)
      final balanceResponse = await http.get(
        Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (balanceResponse.statusCode == 200) {
        final balanceData = json.decode(balanceResponse.body);
        final realTimeBalance = (balanceData['balance'] as num).toDouble();
        
        // Update both local state and SharedPreferences cache
        setState(() {
          walletBalance = realTimeBalance;
        });
        
        // Update cache for consistency
        await prefs.setDouble('wallet_balance', realTimeBalance);
        
        // debugPrint('PaymentScreen: Loaded real-time balance: \$$realTimeBalance');
      } else {
        // debugPrint('Failed to fetch wallet balance: ${balanceResponse.statusCode}');
        // Fallback to cached balance
        setState(() {
          walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;
        });
      }
    } catch (e) {
      // debugPrint('Error fetching wallet balance: $e');
      // Fallback to cached balance
      setState(() {
        walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;
      });
    }
  }

  Future<void> _processPayment() async {
    // Start processing animation
    setState(() {
      isProcessing = true;
      errorMessage = null;
    });
    
    // Simulate network request
    await Future.delayed(const Duration(seconds: 2));
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if wallet has enough balance if using wallet
    if (_selectedPaymentMethod == 0) {
      if (walletBalance < widget.amount) {
        setState(() {
          isProcessing = false;
          errorMessage = 'Insufficient balance in wallet';
        });
        return;
      }
      
      // debugPrint('PaymentScreen: Wallet payment selected - using direct payment API');
      
      // For wallet payments, use direct payment API
      final email = prefs.getString('user_email') ?? '';
      
      if (email.isNotEmpty) {
        try {
          // debugPrint('PaymentScreen: Making direct wallet payment with real account deduction');
          
          // Call the payment API that will actually deduct money from user's wallet
          final paymentResponse = await http.post(
            ApiConfig.payForParkingWithWalletEndpoint(
              email: email,
              amount: widget.amount,
              slotId: widget.parkingSlot,
              sessionId: widget.sessionId,
              buildingName: widget.parkingLocation,
            ),
            headers: ApiConfig.headers,
          );
          
          // Check if the payment was actually successful (money deducted from account)
          if (paymentResponse.statusCode == 200) {
            // debugPrint('PaymentScreen: Payment successful - account was debited');
            
            // Refresh wallet balance from backend after successful payment
            try {
              final balanceResponse = await http.get(
                Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
                headers: ApiConfig.headers,
              );
              
              if (balanceResponse.statusCode == 200) {
                final balanceData = json.decode(balanceResponse.body);
                final updatedBalance = (balanceData['balance'] as num).toDouble();
                await prefs.setDouble('wallet_balance', updatedBalance);
                // debugPrint('PaymentScreen: Updated wallet balance from backend: \$$updatedBalance');
              }
            } catch (e) {
              // debugPrint('PaymentScreen: Balance refresh failed, but payment was successful: $e');
            }

            setState(() {
              isProcessing = false;
            });
            
            _showPaymentSuccessDialog(null);
            return;
            
          } else {
            // Payment failed - account was NOT debited
            final errorData = json.decode(paymentResponse.body);
            final errorMessage = errorData['detail'] ?? 'Payment failed - account was not charged';
            // debugPrint('PaymentScreen: Payment failed - no money deducted: ${paymentResponse.statusCode} - $errorMessage');
            
            setState(() {
              isProcessing = false;
              this.errorMessage = errorMessage;
            });
            return;
          }
          
        } catch (e) {
          // debugPrint('PaymentScreen: Exception during payment - account was not charged: $e');
          
          setState(() {
            isProcessing = false;
            errorMessage = 'Payment failed - account was not charged. Please try again.';
          });
          return;
        }
      }
    } else {
      // Card payment: make sure user selected a card
      if (selectedCardId == null) {
        setState(() {
          isProcessing = false;
          errorMessage = 'Please select a card to continue';
        });
        return;
      }
    }
    
    // For card payments, use the pay-later flow
    // Note: Transaction history is now handled entirely by the backend
    // No need to save local payment history as it causes duplicates
    
    // Call backend API to save transaction to database
    // debugPrint('PaymentScreen: Card payment - saving to backend - slot: ${widget.parkingSlot}, building: ${widget.parkingLocation}');
    
    // Calculate duration from parkingDate to now
    final now = DateTime.now();
    final parkingStartTime = widget.parkingDate;
    final duration = now.difference(parkingStartTime);
    
    final result = await _sendPayLaterToBackend(
      amount: widget.amount,
      slotId: widget.parkingSlot,
      sessionId: widget.sessionId,
      buildingName: widget.parkingLocation,
      startTime: parkingStartTime,
      endTime: now,
      duration: duration,
    );
    
    // Get transaction ID for display in success dialog
    String? transactionId;
    
    if (result['success'] == true) {
      // debugPrint('PaymentScreen: Successfully saved pending payment to backend for card payment');
      
      // Get the transaction ID for later use
      transactionId = result['transaction_id'];
      
      // For card payments, the payment is saved as pending and will be processed later
      // Show success dialog for card payment
      _showPaymentSuccessDialog(transactionId);
      
    } else {
      // debugPrint('PaymentScreen: Failed to save to backend: ${result['message']}');
      // Show error message and stop processing
      setState(() {
        isProcessing = false;
        errorMessage = result['message'] ?? 'Payment failed. Please try again.';
      });
      return;
    }
  }

  Widget _buildWalletOption() {
    final bool hasSufficientBalance = walletBalance >= widget.amount;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: _selectedPaymentMethod == 0 ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _selectedPaymentMethod == 0
              ? Colors.green
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = 0;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio(
                    value: 0,
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value as int;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                  const Text(
                    'Wallet Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.account_balance_wallet,
                    color: hasSufficientBalance 
                      ? Colors.green.shade700
                      : Colors.red.shade400,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48.0),
                child: Text(
                  '\$${walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: hasSufficientBalance
                      ? Colors.green.shade700
                      : Colors.red.shade400,
                  ),
                ),
              ),
              if (!hasSufficientBalance)
                Padding(
                  padding: const EdgeInsets.only(left: 48.0, top: 4),
                  child: Text(
                    'Insufficient balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardOption() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: _selectedPaymentMethod == 1 ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _selectedPaymentMethod == 1 ? Colors.green : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = 1;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio(
                    value: 1,
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value as int;
                      });
                    },
                    activeColor: Colors.green,
                  ),
                  const Text(
                    'Credit/Debit Card',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.credit_card, color: Colors.blue),
                ],
              ),
              if (_selectedPaymentMethod == 1)
                Column(
                  children: savedCards.isNotEmpty
                    ? savedCards.map((card) {
                        final id = card['payment_method_id'];
                        final lastFour = card['last_four_digits'] ?? '0000';
                        final holder = card['cardholder_name'] ?? 'Unnamed';
                        final isSelected = id == selectedCardId;

                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedCardId = id);
                          },
                          child: Card(
                            color: isSelected ? Colors.white : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: isSelected ? 4 : 1,
                            child: ListTile(
                              leading: const Icon(Icons.credit_card),
                              title: Text('**** **** **** $lastFour - $holder'),
                            ),
                          ),
                        );
                      }).toList()
                    : [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'No saved cards found.',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                        )
                      ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD4EECD),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFFA3DB94),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Summary Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Location:'),
                          Text(
                            widget.parkingLocation,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Parking Slot:'),
                          Text(
                            widget.parkingSlot,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Date:'),
                          Text(
                            '${widget.parkingDate.day}/${widget.parkingDate.month}/${widget.parkingDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${widget.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              const Text(
                'Select Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Payment Options
              _buildWalletOption(),
              _buildCardOption(),
              
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Pay Button
              Center(
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    minimumSize: const Size(200, 50),
                  ),
                  child: isProcessing
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Processing...'),
                          ],
                        )
                      : const Text(
                          'Pay Now',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentSuccessDialog(String? transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear any pending payments for this session (only if payment was successful)
    final List<String> pendingPayments = prefs.getStringList('pending_payments') ?? [];
    final updatedPendingPayments = pendingPayments
        .where((payment) {
          final data = jsonDecode(payment);
          return data['sessionId'] != widget.sessionId;
        })
        .toList();
    await prefs.setStringList('pending_payments', updatedPendingPayments);
    
    // Clear all session and temporary data after successful payment
    // debugPrint('PaymentScreen: Clearing all session data after payment');
    await prefs.remove('temp_parking_start_time');
    await prefs.remove('temp_parking_end_time');
    await prefs.remove('temp_parking_duration_seconds');
    await prefs.remove('temp_allocated_spot_id');
    await prefs.remove('temp_building_id');
    await prefs.remove('temp_selected_destination');
    await prefs.remove('parking_start_time');
    await prefs.remove('session_id');
    await prefs.remove('allocated_spot_id');
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
    await prefs.remove('building_id');
    await prefs.remove('selected_date');
    await prefs.remove('selected_time');
    await prefs.remove('selected_hours');
    await prefs.remove('selected_minutes');
    await prefs.remove('selected_duration_in_hours');
    
    // Payment completed successfully, update state and show success dialog
    setState(() {
      isProcessing = false;
    });
    
    // Show success and navigate back
    if (mounted) {
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Center(child: Text('Payment Successful')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline, 
                color: Colors.green, 
                size: 80
              ),
              const SizedBox(height: 16),
              Text(
                'Payment of \$${widget.amount.toStringAsFixed(2)} completed',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Transaction ID: ${transactionId != null ? transactionId.substring(0, 8) : 'Processed'}...',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/dashboard', 
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }
  }
} 