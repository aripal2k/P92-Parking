import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:autospot/config/api_config.dart';

// Screen for adding balance (top-up) to the user's wallet
class AddBalanceScreen extends StatefulWidget {
  const AddBalanceScreen({super.key});

  @override
  State<AddBalanceScreen> createState() => _AddBalanceScreenState();
}

class _AddBalanceScreenState extends State<AddBalanceScreen> {
  List<Map<String, dynamic>> paymentMethods = [];
  String? selectedMethodId;
  bool isLoading = true;
  double amount = 0.0;
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fetch wallet balance from local storage and payment methods from backend
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';
    walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getPaymentMethodsEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> cardList = json.decode(response.body);
        final List<Map<String, dynamic>> cards = cardList.cast<Map<String, dynamic>>();

        setState(() {
          paymentMethods = cards;
          // Only set selectedMethodId if there are cards available
          if (cards.isNotEmpty) {
            selectedMethodId = cards.firstWhere(
              (card) => card['is_default'] == true,
              orElse: () => cards.first,
            )['payment_method_id'];
          } else {
            selectedMethodId = null;
          }
          isLoading = false;
        });
      } else {
        // debugPrint('Failed to fetch cards: ${response.statusCode}');
        setState(() {
          paymentMethods = [];
          selectedMethodId = null;
          isLoading = false;
        });
      }
    } catch (e) {
      // debugPrint('Error fetching cards: $e');
      setState(() {
        paymentMethods = [];
        selectedMethodId = null;
        isLoading = false;
      });
    }
  }

  // Submit top-up request to backend
  Future<void> _submitTopUp() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    final payload = {
      'email': email,
      'amount': amount,
      'payment_method_id': selectedMethodId,
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/wallet/add-money'),
        headers: ApiConfig.headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Set flag to refresh wallet when returning
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('wallet_refresh_needed', true);
        
        Navigator.pop(context, true); // Indicate success
      } else {
        // debugPrint('Top-up failed: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to top up balance')),
        );
      }
    } catch (e) {
      // debugPrint('Error adding balance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to server')),
      );
    }
  }
  
  // Development-only function: Add test balance instantly without payment method
  Future<void> _testAddMoney(double testAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/wallet/test-add-money?email=${Uri.encodeComponent(email)}&amount=$testAmount&description=Test%20balance%20addition'),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          walletBalance += testAmount;
        });
        await prefs.setDouble('wallet_balance', walletBalance);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test: Added \$${testAmount.toStringAsFixed(2)} to wallet'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Set flag to refresh wallet when returning
        await prefs.setBool('wallet_refresh_needed', true);
        
        // Automatically return to wallet page to trigger refresh
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        // debugPrint('Test add money failed: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test add money failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // debugPrint('Error in test add money: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error connecting to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper: build test top-up buttons
  Widget _buildTestButton(String label, double testAmount) {
    return ElevatedButton(
      onPressed: () => _testAddMoney(testAmount),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Show popup to add new card
  void _showAddCardDialog() {
    final cardNumberController = TextEditingController();
    final cardHolderController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    bool isDefaultCard = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                        setDialogState(() {
                          isDefaultCard = value;
                        });
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
              onPressed: () => _submitCard(
                cardNumberController,
                cardHolderController,
                expiryController,
                cvvController,
                isDefaultCard,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Submit new card to backend
  Future<void> _submitCard(
    TextEditingController cardNumberController,
    TextEditingController cardHolderController,
    TextEditingController expiryController,
    TextEditingController cvvController,
    bool isDefaultCard,
  ) async {
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

    // Parse expiry date
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

    // Check if expired
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

    // Prepare payload for API
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
        Navigator.pop(context); // Close dialog
        _loadData(); // Refresh payment methods
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card added successfully')),
        );
      } else {
        // Extract API error message if available
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
      // debugPrint('Error adding card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error connecting to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Balance'),
        backgroundColor: const Color(0xFFD4EECD),
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text(
                      'Top Up Your Wallet',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Wallet Balance Card
                    Container(
                      width: double.infinity,
                      height: 150,
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
                            'Current Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
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
                                '\$${walletBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      onChanged: (value) {
                        setState(() {
                          amount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    // Show payment methods if available, otherwise show add card prompt
                    if (paymentMethods.isNotEmpty) ...[
                      ...paymentMethods.map((card) {
                        final lastFour = card['last_four_digits'].toString().padLeft(4, '0');
                        final holder = card['cardholder_name'] ?? 'Unnamed';
                        final id = card['payment_method_id'];
                        final isSelected = id == selectedMethodId;

                        return GestureDetector(
                          onTap: () {
                            setState(() => selectedMethodId = id);
                          },
                          child: Card(
                            color: isSelected ? Colors.white : Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isSelected ? 4 : 1,
                            child: ListTile(
                              leading: const Icon(Icons.credit_card),
                              title: Text('**** **** **** $lastFour - $holder'),
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // Show message when no payment methods are available
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.credit_card_off, 
                                size: 48, 
                                color: Colors.orange.shade600),
                            const SizedBox(height: 12),
                            Text(
                              'No Payment Methods Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You need to add a payment card to top up your wallet. Please go back to the Wallet page and add a card first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    
                    // Test Section for Development
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.science, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Test Mode - Quick Add Balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'For testing purposes - Add money instantly without payment method',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildTestButton('\$10', 10.0),
                              _buildTestButton('\$25', 25.0),
                              _buildTestButton('\$50', 50.0),
                              _buildTestButton('\$100', 100.0),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: paymentMethods.isEmpty 
                            ? _showAddCardDialog
                            : (amount > 0 && selectedMethodId != null ? _submitTopUp : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: paymentMethods.isEmpty ? Colors.orange : Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          paymentMethods.isEmpty 
                              ? 'Add Payment Method First' 
                              : 'Pay Now',
                          style: const TextStyle(fontSize: 18, color: Colors.white)
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
