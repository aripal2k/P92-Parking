import 'package:flutter/material.dart';
import 'package:autospot/user/userWallet_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Test version of WalletScreen that can be used with mocked data
/// 
/// Since the real WalletScreen makes direct HTTP calls in initState,
/// we need a test-friendly version that works with pre-populated data
class TestWalletScreen extends StatefulWidget {
  final double initialBalance;
  final List<Map<String, dynamic>> savedCards;
  final List<Map<String, dynamic>> pendingPayments;
  final List<Map<String, dynamic>> paymentHistory;
  final bool showLoading;
  final bool hasActiveSession;
  final String? sessionSlot;
  final DateTime? sessionStartTime;

  const TestWalletScreen({
    super.key,
    this.initialBalance = 0.0,
    this.savedCards = const [],
    this.pendingPayments = const [],
    this.paymentHistory = const [],
    this.showLoading = true,  // Default to showing loading initially
    this.hasActiveSession = false,
    this.sessionSlot,
    this.sessionStartTime,
  });

  @override
  State<TestWalletScreen> createState() => _TestWalletScreenState();
}

class _TestWalletScreenState extends State<TestWalletScreen> {
  late double balance;
  late List<Map<String, dynamic>> savedCards;
  late List<Map<String, dynamic>> pendingPayments;
  late List<Map<String, dynamic>> paymentHistory;
  late bool isLoading;
  
  // Active session data
  String? sessionId;
  String? parkingStartTime;
  String? allocatedSpotId;

  @override
  void initState() {
    super.initState();
    balance = widget.initialBalance;
    savedCards = widget.savedCards;
    pendingPayments = widget.pendingPayments;
    paymentHistory = widget.paymentHistory;
    isLoading = widget.showLoading;
    
    // Load data from SharedPreferences like the real WalletScreen
    _loadFromPreferences();
    
    // Simulate async loading if needed
    if (widget.showLoading) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    }
  }
  
  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load balance
    final storedBalance = prefs.getDouble('wallet_balance');
    if (storedBalance != null) {
      balance = storedBalance;
    }
    
    // Load active session data
    sessionId = prefs.getString('session_id');
    parkingStartTime = prefs.getString('parking_start_time');
    allocatedSpotId = prefs.getString('allocated_spot_id');
    
    // Load pending payments
    final pendingPaymentsJson = prefs.getStringList('pending_payments') ?? [];
    if (pendingPaymentsJson.isNotEmpty) {
      pendingPayments = pendingPaymentsJson
          .map((json) {
            try {
              return jsonDecode(json) as Map<String, dynamic>;
            } catch (e) {
              return null;
            }
          })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();
    }
    
    // Load payment history
    final historyJson = prefs.getStringList('payment_history') ?? [];
    if (historyJson.isNotEmpty) {
      paymentHistory = historyJson
          .map((json) {
            try {
              return jsonDecode(json) as Map<String, dynamic>;
            } catch (e) {
              return null;
            }
          })
          .where((item) => item != null)
          .cast<Map<String, dynamic>>()
          .toList();
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // For testing, we'll create a simplified version of the WalletScreen UI
    // that doesn't make real API calls
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFACE1AF),
              Color(0xFFFFF5E1),
            ],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text('AutoSpot', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // Balance Card
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Card(
                      color: Colors.transparent,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Balance', style: TextStyle(fontSize: 16, color: Colors.white)),
                                const SizedBox(height: 4),
                                const Text('AutoSpot Wallet', style: TextStyle(fontSize: 14, color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text('\$${balance.toStringAsFixed(2)}', 
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/wallet/add-money');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                minimumSize: const Size(100, 36),
                              ),
                              child: const Text('Top Up'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Active Parking Session
                  if (sessionId != null && parkingStartTime != null) ...[
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final startTime = DateTime.parse(parkingStartTime!);
                        final duration = DateTime.now().difference(startTime);
                        final hours = duration.inHours;
                        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
                        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
                        
                        return Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.timer, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Active Parking Session', 
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Slot: ${allocatedSpotId ?? 'Unknown'}'),
                                Text('Started: ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'),
                                Text('Duration: ${hours.toString().padLeft(2, '0')}:$minutes:$seconds'),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    // Show end session dialog
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('End Parking Session'),
                                        content: const Text('Are you sure you want to end your current parking session? This will also clear the session from the server.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('End Session'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('End Parking Session'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // Cards Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          _showAddCardDialog(context);
                        },
                        child: const Text('Add Card'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Saved Cards List
                  ...savedCards.map((card) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.credit_card),
                      title: Text('**** **** **** ${card['lastFour']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card['cardHolder'] ?? 'Card Holder'),
                          Text('Exp: ${card['expiryDate']}'),
                        ],
                      ),
                      trailing: card['isDefault'] == true 
                        ? const Chip(label: Text('Default'))
                        : null,
                    ),
                  )).toList(),
                  
                  const SizedBox(height: 20),
                  
                  // Pending Payments Section
                  if (pendingPayments.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${pendingPayments.length} items', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...pendingPayments.map((payment) => Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(payment['location'] ?? 'Payment', 
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('\$${(payment['amount'] ?? 0.0).toStringAsFixed(2)}', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (payment['slot'] != null)
                              Text('Slot: ${payment['slot']}'),
                            if (payment['date'] != null)
                              Text('Date: ${_formatDate(payment['date'])}'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: balance >= (payment['amount'] ?? 0.0) ? () {
                                      Navigator.pushNamed(
                                        context,
                                        '/payment',
                                        arguments: {
                                          'amount': payment['amount'],
                                          'sessionId': payment['sessionId'],
                                          'parkingLocation': payment['location'],
                                          'parkingSlot': payment['slot'],
                                        },
                                      );
                                    } : null,
                                    child: const Text('Pay from Wallet'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/payment',
                                        arguments: {
                                          'amount': payment['amount'],
                                          'sessionId': payment['sessionId'],
                                          'parkingLocation': payment['location'],
                                          'parkingSlot': payment['slot'],
                                        },
                                      );
                                    },
                                    child: const Text('Pay with Card'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                    const SizedBox(height: 20),
                  ],
                  
                  // Payment History Section
                  if (paymentHistory.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${paymentHistory.length} transactions', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...paymentHistory.take(5).map((transaction) {
                      // Determine icon based on payment method
                      IconData icon;
                      Color iconColor;
                      if (transaction['method'] == 'Wallet') {
                        icon = Icons.account_balance_wallet;
                        iconColor = Colors.blue;
                      } else if (transaction['method'] == 'Card') {
                        icon = Icons.credit_card;
                        iconColor = Colors.purple;
                      } else if (transaction['type'] == 'topup') {
                        icon = Icons.add_circle;
                        iconColor = Colors.green;
                      } else {
                        icon = Icons.remove_circle;
                        iconColor = Colors.red;
                      }
                      
                      return Card(
                        child: ListTile(
                          leading: Icon(icon, color: iconColor),
                          title: Text(transaction['location'] ?? transaction['description'] ?? 'Transaction'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (transaction['method'] != null)
                                Text(transaction['method']),
                              if (transaction['date'] != null)
                                Text('Date: ${_formatDate(transaction['date'])}'),
                              if (transaction['paymentId'] != null)
                                Text('ID: ${transaction['paymentId']}'),
                            ],
                          ),
                          trailing: Text(
                            '\$${(transaction['amount'] ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: transaction['type'] == 'topup' ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    if (paymentHistory.length > 5) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('View Full History'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showAddCardDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String cardNumber = '';
    String cardholderName = '';
    String expiry = '';
    String cvv = '';
    bool isDefault = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Payment Card'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Card Number'),
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  onChanged: (value) => cardNumber = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Card number is required';
                    }
                    if (value.length != 16) {
                      return 'Card number must be 16 digits';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                      return 'Card number must contain only digits';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Cardholder Name'),
                  onChanged: (value) => cardholderName = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Cardholder name is required';
                    }
                    return null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'MM/YY'),
                        keyboardType: TextInputType.datetime,
                        maxLength: 5,
                        onChanged: (value) => expiry = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          // Check format MM/YY
                          if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                            return 'Format: MM/YY';
                          }
                          // Check valid month
                          final parts = value.split('/');
                          final month = int.tryParse(parts[0]) ?? 0;
                          if (month < 1 || month > 12) {
                            return 'Invalid expiry date.';
                          }
                          // Check if expired
                          final year = int.tryParse(parts[1]) ?? 0;
                          final currentYear = DateTime.now().year % 100;
                          final currentMonth = DateTime.now().month;
                          if (year < currentYear || (year == currentYear && month < currentMonth)) {
                            return 'Card is expired.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'CVV'),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        onChanged: (value) => cvv = value,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (value.length < 3 || value.length > 4) {
                            return 'Invalid';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(value)) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: isDefault,
                      onChanged: (value) {
                        setState(() {
                          isDefault = value;
                        });
                      },
                    ),
                    const Text('Set as Default'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context);
                } else {
                  // Show error snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid card details.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}