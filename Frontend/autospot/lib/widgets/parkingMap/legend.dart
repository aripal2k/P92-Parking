import 'package:flutter/material.dart';

class ParkingMapLegend extends StatelessWidget {
  final Function()? onTriggerPressed; // Callback for trigger button click
  final bool showTrigger; // Whether to show trigger button
  final bool showEndButton; // Whether to show end button
  final Function()? onEndPressed; // Callback for end button
  final String? timerText; // Text for timer display
 
  const ParkingMapLegend({
    super.key,
    this.onTriggerPressed, // Callback function for trigger button
    this.showTrigger = true, // Default to showing trigger button
    this.showEndButton = false, // Default to not showing end button
    this.onEndPressed,
    this.timerText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title with divider
              const Center(
                child: Text(
                  'Map Legend',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(thickness: 1, height: 16),
              
                // Compact legend display with Wrap instead of GridView
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                children: [
                    _buildCompactLegendItem(Colors.green, 'Available'),
                    _buildCompactLegendItem(Colors.yellow, 'Allocated'),
                    _buildCompactLegendItem(Colors.red, 'Occupied'),
                    _buildCompactLegendItem(Colors.orange, 'Vehicle Entrance'),
                    _buildCompactLegendItem(Colors.purple, 'Building Entrance'),
                    _buildCompactLegendItem(Colors.brown, 'Exit'),
                    _buildCompactLegendItem(Colors.pinkAccent, 'Ramp'),
                    _buildCompactLegendItem(Colors.grey, 'Wall'),
                    _buildCompactLegendItem(Colors.transparent, 'Corridor'),
                    _buildCompactLegendItem(const Color(0xFF3498DB), 'Navigation Path'),
                    _buildCompactLegendItem(const Color(0xFF2ECC71), 'To Destination'),
                ],
              ),
              
              // Display timer if available
              if (timerText != null) 
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.amber),
                      const SizedBox(width: 8),
                        Flexible(
                        child: Text(
                          timerText!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              
                // Action buttons with appropriate spacing
              const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      // Trigger button
                      if (showTrigger)
                        ElevatedButton.icon(
                    onPressed: onTriggerPressed,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Trigger Parking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF68B245),
                      foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              
                      // End button
              if (showEndButton)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: onEndPressed,
                    icon: const Icon(Icons.stop),
                    label: const Text('End Parking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // More compact legend item implementation
  Widget _buildCompactLegendItem(Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
          decoration: BoxDecoration(
            color: color,
            border: color == Colors.transparent
                ? Border.all(color: Colors.black, width: 1)
                : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10),
          ),
        ],
        ),
    );
  }

  // Keep the original method for backwards compatibility
  Widget _buildLegendItem(Color color, String label) {
    return _buildCompactLegendItem(color, label);
  }
}
