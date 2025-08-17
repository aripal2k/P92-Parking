import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
// Re-export the original QrScannerOverlayShape
export 'package:qr_code_scanner/qr_code_scanner.dart' show QrScannerOverlayShape;

// Re-export the original QrScannerOverlayShape
export 'package:qr_code_scanner/qr_code_scanner.dart' show QrScannerOverlayShape;

// Widget function to build a QR code scanner view
Widget buildQRScanner({
  required GlobalKey qrKey,
  required Function(QRViewController) onQRViewCreated,
  required double cutOutSize,
}) {
  return QRView(
    key: qrKey,
    onQRViewCreated: onQRViewCreated,
    overlay: QrScannerOverlayShape(
      borderColor: const Color(0xFFA3DB94),
      borderRadius: 10,
      borderLength: 30,
      borderWidth: 10,
      cutOutSize: cutOutSize,
    ),
  );
}
