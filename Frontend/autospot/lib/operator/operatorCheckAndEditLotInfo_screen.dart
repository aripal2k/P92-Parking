import 'package:flutter/material.dart';

// Displays detailed information about a parking lot slot
class LotInfoDialog extends StatefulWidget {
  final String slotId;
  final String status;
  final String allocatedUser;
  final String fullName;
  final String plateNumber;
  final String phoneNumber;

  const LotInfoDialog({
    super.key,
    required this.slotId,
    required this.status,
    required this.allocatedUser,
    required this.fullName,
    required this.plateNumber,
    required this.phoneNumber,
  });

  @override
  State<LotInfoDialog> createState() => _LotInfoDialogState();
}

class _LotInfoDialogState extends State<LotInfoDialog> {
  bool isEditing = false;

  late String _status;
  late TextEditingController _allocatedUserController;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _allocatedUserController = TextEditingController(text: widget.allocatedUser);
  }

  @override
  void dispose() {
    _allocatedUserController.dispose();
    super.dispose();
  }

  TextStyle get infoTextStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFD4EECD),
      title: const Text(
        'Lot Information',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Slot ID: ${widget.slotId}', style: infoTextStyle),

          const SizedBox(height: 12),
          isEditing
              ? DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['available', 'allocated', 'occupied']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status, style: infoTextStyle),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _status = value;
                      });
                    }
                  },
                )
              : Text('Status: $_status', style: infoTextStyle),

          const SizedBox(height: 12),
          isEditing
              ? TextField(
                  controller: _allocatedUserController,
                  decoration: const InputDecoration(labelText: 'Allocated User'),
                  style: infoTextStyle,
                )
              : Text('User Name: ${_allocatedUserController.text}', style: infoTextStyle),

          const SizedBox(height: 12),
          Text('Full Name: ${widget.fullName}', style: infoTextStyle),
          const SizedBox(height: 12),
          Text('Plate Number: ${widget.plateNumber}', style: infoTextStyle),
          const SizedBox(height: 12),
          Text('Phone Number: ${widget.phoneNumber}', style: infoTextStyle),
        ],
      ),
      actions: isEditing
          ? [
              TextButton(
                onPressed: () {
                  setState(() {
                    isEditing = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'status': _status,
                    'allocatedUser': _allocatedUserController.text,
                  });
                },
                child: const Text('Save'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300]!,
                ),
                onPressed: () {
                  setState(() {
                    isEditing = true;
                  });
                },
                child: const Text('Edit'),
              ),
            ],
    );
  }
}
