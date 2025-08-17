import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'qr_scanner_stub.dart'
    if (dart.library.io) 'qr_scanner_mobile.dart'
    if (dart.library.html) 'qr_scanner_web.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  dynamic controller;
  String? result;
  bool isProcessing = false;
  bool permissionGranted = false;
  bool flashEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      permissionGranted = status.isGranted;
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  void _onQRViewCreated(dynamic controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!isProcessing && scanData.code != null) {
        // debugPrint('QR code scanned: ${scanData.code}');
        
        setState(() {
          isProcessing = true;
          result = scanData.code;
        });

        // Pause camera while processing
        controller.pauseCamera();

        // IMPORTANT: Force accept ANY QR code for testing
        // Skip validation temporarily to debug the flow
        bool forceAccept = true;
        
        if (forceAccept || _isValidEntranceQRCode(scanData.code!)) {

          // Store the entrance ID
          await _saveEntranceId(scanData.code!);

          // Navigate to destination selection page
          if (mounted) {
            // debugPrint('Navigating to destination selection page...');
            Navigator.pushNamed(
              context, 
              '/destination-select',
              arguments: scanData.code
            );
          }
        } else {
          // Invalid QR code, show error
          // debugPrint('QR code validation failed. Showing error message.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid parking entrance QR code. Please scan a valid code.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          // Resume camera after delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                isProcessing = false;
                result = null;
              });
              controller.resumeCamera();
            }
          });
        }
      }
    });
  }

  // Check if the QR code is a valid entrance QR code
  bool _isValidEntranceQRCode(String code) {
    // add debug output to see the actual scanned content
    // debugPrint('scanned QR code content: $code');
    
    // if QR code is empty, return false
    if (code.isEmpty) {
      // debugPrint('QR code content is empty');
      return false;
    }
    
    // handle possible URL content
    if (code.startsWith('http://') || code.startsWith('https://')) {
      // debugPrint('detected URL format QR code');
      // consider extracting parameters from URL
      return true;
    }
    
    // Check for valid formats:
    // 1. Simple format: ENTRANCE_ID or any string containing ENTRANCE
    if (code.contains('ENTRANCE') || code.contains('entrance')) {
      // debugPrint('detected QR code containing ENTRANCE keyword');
      return true;
    }
    
    // 2. Parameter format: entrance=ID
    if (code.contains('entrance=')) {
      // debugPrint('detected entrance= parameter format QR code');
      return true;
    }
    
    // 3. Building and entrance format: building=X&entrance=Y
    if (code.contains('building=') || code.contains('level=')) {
      // debugPrint('detected building or level parameter QR code');
      return true;
    }
    
    // 4. backend JSON format
    try {
      final jsonData = json.decode(code);
      // debugPrint('successfully parsed as JSON: $jsonData');
      
      // accept any JSON format
      if (jsonData is Map) {
        return true;
      }
    } catch (e) {
      // debugPrint('not valid JSON format: $e');
      // Not valid JSON, continue with other checks
    }
    
    // 5. last resort: if it's a simple text and length is reasonable, also try to accept
    if (code.length < 100) {
      // debugPrint('accept simple text QR code');
      return true;
    }
    
    // debugPrint('QR code format does not match any known pattern');
    return false;
  }

  // Save the entrance ID to SharedPreferences
  Future<void> _saveEntranceId(String entranceQRCode) async {
    final prefs = await SharedPreferences.getInstance();
    
    String entranceId = "";
    String building = "";
    String level = "1";
    int x = 0;
    int y = 0;
    

    
    // Try to parse as JSON first (backend format)
    try {
      final jsonData = json.decode(entranceQRCode);
      if (jsonData is Map) {

        
        // new format: handle entrance QR code JSON format
        if (jsonData.containsKey('entrance_id')) {
          entranceId = jsonData['entrance_id'].toString();
          
          // parse building information
          if (jsonData.containsKey('building')) {
            building = jsonData['building'].toString();
          }
          
          // parse level information
          if (jsonData.containsKey('level')) {
            level = jsonData['level'].toString();
          }
          
          // parse coordinates information
          if (jsonData.containsKey('coordinates') && jsonData['coordinates'] is Map) {
            final coordinates = jsonData['coordinates'] as Map;
            if (coordinates.containsKey('x')) {
              x = int.tryParse(coordinates['x'].toString()) ?? 0;
            }
            if (coordinates.containsKey('y')) {
              y = int.tryParse(coordinates['y'].toString()) ?? 0;
            }
          }
          
          // debugPrint('parsed entrance QR code: entrance ID=$entranceId, building=$building, level=$level, coordinates=($x,$y)');
        }
        // old format: handle old format
        else if (jsonData.containsKey('entrances') && 
            jsonData['entrances'] is List && 
            (jsonData['entrances'] as List).isNotEmpty) {
          
          final entrances = jsonData['entrances'] as List;
          if (entrances[0] is Map && 
              entrances[0].containsKey('entrance_id')) {
            entranceId = entrances[0]['entrance_id'].toString();
          }
        }
        
        // Extract destination/building
        if (jsonData.containsKey('destination')) {
          building = jsonData['destination'].toString();
        }
        
        // if no valid entranceId found, try using any available key as ID
        if (entranceId.isEmpty && jsonData.isNotEmpty) {
          entranceId = jsonData.keys.first.toString();
          // debugPrint('no valid entrance_id, using first key as ID: $entranceId');
        }
        

        
        // Save username if available
        if (jsonData.containsKey('username')) {
          await prefs.setString('qr_username', jsonData['username'].toString());
        }
        
        // Save expiration if available
        if (jsonData.containsKey('expire_at')) {
          await prefs.setString('qr_expire_at', jsonData['expire_at'].toString());
        }
      }
    } catch (e) {
      // Not valid JSON, try other formats
      // debugPrint('QR code is not valid JSON: $e');
      
      // Extract information from QR code based on format
      if (entranceQRCode.startsWith('ENTRANCE_') || entranceQRCode.contains('ENTRANCE')) {
        // new format: ENTRANCE_BUILDINGID_ENTRANCEID_LEVEL_X_Y
        final parts = entranceQRCode.split('_');
        entranceId = entranceQRCode; // use the entire string as ID
        
        if (parts.length >= 3) {
          building = parts[1];
          entranceId = parts[2];
          
          // if format contains more information
          if (parts.length >= 4) {
            level = parts[3];
          }
          
          // if format contains coordinates information
          if (parts.length >= 6) {
            x = int.tryParse(parts[4]) ?? 0;
            y = int.tryParse(parts[5]) ?? 0;
          }
        }
      } else if (entranceQRCode.contains('entrance=')) {
        // Extract entrance ID from parameter format
        final entrancePattern = RegExp(r'entrance=([^&]+)');
        final entranceMatch = entrancePattern.firstMatch(entranceQRCode);
        entranceId = entranceMatch?.group(1) ?? entranceQRCode;
        
        // Extract building if available
        final buildingPattern = RegExp(r'building=([^&]+)');
        final buildingMatch = buildingPattern.firstMatch(entranceQRCode);
        if (buildingMatch != null) {
          building = buildingMatch.group(1) ?? "";
        }
        
        // Extract level if available
        final levelPattern = RegExp(r'level=([^&]+)');
        final levelMatch = levelPattern.firstMatch(entranceQRCode);
        if (levelMatch != null) {
          level = levelMatch.group(1) ?? "1";
        }
        
        // Extract x coordinate
        final xPattern = RegExp(r'x=([^&]+)');
        final xMatch = xPattern.firstMatch(entranceQRCode);
        if (xMatch != null) {
          x = int.tryParse(xMatch.group(1) ?? "0") ?? 0;
        }
        
        // Extract y coordinate
        final yPattern = RegExp(r'y=([^&]+)');
        final yMatch = yPattern.firstMatch(entranceQRCode);
        if (yMatch != null) {
          y = int.tryParse(yMatch.group(1) ?? "0") ?? 0;
        }
      } else {
        // if all parsing methods fail, use the original QR code content as entranceId
        entranceId = entranceQRCode.substring(0, min(entranceQRCode.length, 50)); // limit length
        // debugPrint('use original QR code content as entranceId (truncated): $entranceId');
      }
    }
    
    // Save all extracted data to SharedPreferences
    if (entranceId.isNotEmpty) {
      await prefs.setString('entrance_id', entranceId);
      // debugPrint('save entrance_id: $entranceId');
    } else {
      // If no specific entrance ID found, use a default with timestamp
      entranceId = "ENTRANCE_${DateTime.now().millisecondsSinceEpoch}";
      await prefs.setString('entrance_id', entranceId);
      // debugPrint('use default generated entrance_id: $entranceId');
    }
    
    await prefs.setString('entrance_scan_time', DateTime.now().toIso8601String());
    
    // Save additional information if available
    if (building.isNotEmpty) {
      await prefs.setString('building_id', building);
      // debugPrint('Successfully saved building_id: $building');
    } else {
        // set default building ID
      building = "DEFAULT_BUILDING";
      await prefs.setString('building_id', building);
      // debugPrint('No building found in QR code, using default: $building');
    }
    
    await prefs.setString('level', level);
    
    // save coordinates information
    await prefs.setInt('entrance_x', x);
    await prefs.setInt('entrance_y', y);
    
    // Save raw QR content for debugging
    await prefs.setString('raw_qr_content', entranceQRCode);
    
    // debugPrint('save entrance information: ID=$entranceId, building=$building, level=$level, coordinates=($x,$y)');
  }

  void _toggleFlash() async {
    if (controller != null) {
      await controller!.toggleFlash();
      setState(() {
        flashEnabled = !flashEnabled;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!permissionGranted) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4EECD),
        appBar: AppBar(
          title: const Text('QR Scanner', style: TextStyle(color: Colors.black)),
          backgroundColor: const Color(0xFFA3DB94),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Camera permission is required to scan QR codes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA3DB94),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Entrance QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(flashEnabled ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                buildQRScanner(
                  qrKey: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  cutOutSize: MediaQuery.of(context).size.width * 0.8,
                ),
                // Scanning indicator
                if (isProcessing)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA3DB94)),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Position QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (result != null && result!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Scanned: ${result!.length > 20 ? '${result!.substring(0, 20)}...' : result}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
} 