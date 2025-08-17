import 'package:flutter/material.dart';

// Builds a placeholder QR scanner widget for unsupported platforms
Widget buildQRScanner({
  required GlobalKey qrKey,
  required Function(dynamic) onQRViewCreated,
  required double cutOutSize,
}) {
  return Container(
    key: qrKey,
    decoration: BoxDecoration(
      color: Colors.black,
      border: Border.all(
        color: const Color(0xFFA3DB94),
        width: 3,
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon representing a QR code scanner
          const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),

          const SizedBox(height: 20),

          // Message indicating scanner is not available on web
          const Text(
            'QR Scanner not available on Web',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),

          const SizedBox(height: 10),

          // Additional instruction for user
          const Text(
            'Please use the mobile app',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

// Class representing overlay shape configuration for the QR scanner
// (This is a data holder only; no painting logic implemented)
class QrScannerOverlayShape {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.borderRadius = 0,
    this.borderLength = 40,
    required this.cutOutSize,
  });
}
