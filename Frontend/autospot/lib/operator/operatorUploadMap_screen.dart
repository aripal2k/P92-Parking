import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class OperatorUploadMapScreen extends StatefulWidget {
  const OperatorUploadMapScreen({super.key});

  @override
  State<OperatorUploadMapScreen> createState() => _OperatorUploadMapScreenState();
}

class _OperatorUploadMapScreenState extends State<OperatorUploadMapScreen> {
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _levelController = TextEditingController(text: '1');
  final TextEditingController _gridRowsController = TextEditingController(text: '10');
  final TextEditingController _gridColsController = TextEditingController(text: '10');

  File? _selectedImage;
  String _errorMessage = '';
  bool _isLoading = false;
  String email = '';
  String keyID = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  // Loads stored email and keyID from SharedPreferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '';
      keyID = prefs.getString('keyID') ?? '';
      _buildingNameController.text = keyID;
    });
  }

  // Opens the device gallery for the operator to pick an image
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Uploads the selected map image and form data to the backend
  Future<void> _uploadMap() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select a parking lot image.';
        _isLoading = false;
      });
      return;
    }

    final uri = Uri.parse(ApiConfig.uploadParkingMapEndpoint);
    final request = http.MultipartRequest('POST', uri)
      ..fields['building_name'] = _buildingNameController.text
      ..fields['level'] = _levelController.text
      ..fields['grid_rows'] = _gridRowsController.text
      ..fields['grid_cols'] = _gridColsController.text
      ..files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = jsonDecode(respStr);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map uploaded and analyzed successfully!')),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = data['detail'] ?? 'Upload failed.';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Creates a consistent input decoration style for form fields
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 16),
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA3DB94), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4EECD), Color(0xFFA3DB94)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Upload Parking Map',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),

                TextFormField(controller: _buildingNameController, decoration: _inputDecoration('Building Name'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 16),
                TextFormField(controller: _levelController, keyboardType: TextInputType.number, decoration: _inputDecoration('Parking Lot Level'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 16),
                TextFormField(controller: _gridRowsController, keyboardType: TextInputType.number, decoration: _inputDecoration('Grid Rows'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 16),
                TextFormField(controller: _gridColsController, keyboardType: TextInputType.number, decoration: _inputDecoration('Grid Columns'), style: const TextStyle(fontSize: 18, color: Colors.black)),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFA3DB94), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedImage != null ? 'Selected: ${_selectedImage!.path.split('/').last}' : 'Select Image',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.upload_file, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty)
                  Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),

                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.black, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _uploadMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA3DB94),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Upload', style: TextStyle(fontSize: 16, color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
