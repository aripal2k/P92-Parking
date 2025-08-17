import 'package:flutter/material.dart';

class OperatorContactSupportScreen extends StatelessWidget {
  const OperatorContactSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
              centerTitle: true,
              title: const Text(
                'Contact Support',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Need Help?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If you have issues with your account or login,\nplease reach out to us via the following methods:',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildSupportTile(
                      icon: Icons.email,
                      title: 'Email',
                      subtitle: 'support@autospot.com',
                    ),
                    const SizedBox(height: 12),
                    _buildSupportTile(
                      icon: Icons.phone,
                      title: 'Phone',
                      subtitle: '+61 xxx xxx xxx',
                    ),
                    const SizedBox(height: 12),
                    _buildSupportTile(
                      icon: Icons.language,
                      title: 'Website',
                      subtitle: 'www.website.com',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a reusable support contact tile with an icon, title, and subtitle
  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8E4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFA3DB94)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.green[800]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
