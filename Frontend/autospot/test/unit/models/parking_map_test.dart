import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/models/parking_map.dart';

void main() {
  group('ParkingMap Model Tests', () {
    test('creates instance with all required fields', () {
      // Arrange
      final parkingMap = ParkingMap(
        building: 'Building A',
        level: 1,
        rows: 10,
        cols: 20,
        entrances: [{'x': 0, 'y': 0, 'type': 'vehicle'}],
        exits: [{'x': 19, 'y': 9, 'type': 'vehicle'}],
        slots: [
          {'x': 5, 'y': 5, 'id': 'A01', 'status': 'available'},
          {'x': 6, 'y': 5, 'id': 'A02', 'status': 'occupied'},
        ],
        corridors: [{'x': 0, 'y': 5}, {'x': 1, 'y': 5}],
        walls: [{'x': 10, 'y': 0}, {'x': 10, 'y': 1}],
        ramps: [{'x': 15, 'y': 15, 'to_level': 2}],
      );

      // Assert
      expect(parkingMap.building, 'Building A');
      expect(parkingMap.level, 1);
      expect(parkingMap.rows, 10);
      expect(parkingMap.cols, 20);
      expect(parkingMap.entrances.length, 1);
      expect(parkingMap.exits.length, 1);
      expect(parkingMap.slots.length, 2);
      expect(parkingMap.corridors.length, 2);
      expect(parkingMap.walls.length, 2);
      expect(parkingMap.ramps.length, 1);
    });

    test('creates instance from valid JSON', () {
      // Arrange
      final json = {
        'building': 'Building B',
        'level': 2,
        'size': {
          'rows': 15,
          'cols': 25,
        },
        'entrances': [
          {'x': 0, 'y': 0, 'type': 'vehicle'},
          {'x': 0, 'y': 10, 'type': 'pedestrian'},
        ],
        'exits': [
          {'x': 24, 'y': 14, 'type': 'vehicle'},
        ],
        'slots': [
          {'x': 5, 'y': 5, 'id': 'B01', 'status': 'available'},
          {'x': 6, 'y': 5, 'id': 'B02', 'status': 'occupied'},
          {'x': 7, 'y': 5, 'id': 'B03', 'status': 'reserved'},
        ],
        'corridors': [
          {'x': 0, 'y': 5},
          {'x': 1, 'y': 5},
          {'x': 2, 'y': 5},
        ],
        'walls': [
          {'x': 10, 'y': 0},
          {'x': 10, 'y': 1},
          {'x': 10, 'y': 2},
        ],
        'ramps': [
          {'x': 20, 'y': 20, 'to_level': 3},
        ],
      };

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.building, 'Building B');
      expect(parkingMap.level, 2);
      expect(parkingMap.rows, 15);
      expect(parkingMap.cols, 25);
      expect(parkingMap.entrances.length, 2);
      expect(parkingMap.exits.length, 1);
      expect(parkingMap.slots.length, 3);
      expect(parkingMap.corridors.length, 3);
      expect(parkingMap.walls.length, 3);
      expect(parkingMap.ramps.length, 1);
    });

    test('handles missing fields with defaults', () {
      // Arrange
      final json = <String, dynamic>{};

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.building, 'Unknown');
      expect(parkingMap.level, 1);
      expect(parkingMap.rows, 6);
      expect(parkingMap.cols, 6);
      expect(parkingMap.entrances, isEmpty);
      expect(parkingMap.exits, isEmpty);
      expect(parkingMap.slots, isEmpty);
      expect(parkingMap.corridors, isEmpty);
      expect(parkingMap.walls, isEmpty);
      expect(parkingMap.ramps, isEmpty);
    });

    test('handles partial size data', () {
      // Arrange
      final json = {
        'building': 'Building C',
        'level': 3,
        'size': {
          'rows': 20,
          // cols is missing
        },
      };

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.rows, 20);
      expect(parkingMap.cols, 6); // default value
    });

    test('handles null values correctly', () {
      // Arrange
      final json = {
        'building': null,
        'level': null,
        'size': null,
        'entrances': null,
        'exits': null,
        'slots': null,
        'corridors': null,
        'walls': null,
        'ramps': null,
      };

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.building, 'Unknown');
      expect(parkingMap.level, 1);
      expect(parkingMap.rows, 6);
      expect(parkingMap.cols, 6);
      expect(parkingMap.entrances, isEmpty);
      expect(parkingMap.exits, isEmpty);
      expect(parkingMap.slots, isEmpty);
      expect(parkingMap.corridors, isEmpty);
      expect(parkingMap.walls, isEmpty);
      expect(parkingMap.ramps, isEmpty);
    });

    test('preserves complex slot data', () {
      // Arrange
      final json = {
        'building': 'Complex Building',
        'level': 1,
        'size': {'rows': 10, 'cols': 10},
        'slots': [
          {
            'x': 1,
            'y': 1,
            'id': 'SPOT001',
            'status': 'available',
            'type': 'regular',
            'reserved': false,
          },
          {
            'x': 2,
            'y': 1,
            'id': 'SPOT002',
            'status': 'occupied',
            'type': 'disabled',
            'reserved': false,
            'vehicle_id': 'ABC123',
          },
        ],
      };

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.slots.length, 2);
      
      final firstSlot = parkingMap.slots[0] as Map;
      expect(firstSlot['id'], 'SPOT001');
      expect(firstSlot['status'], 'available');
      expect(firstSlot['type'], 'regular');
      
      final secondSlot = parkingMap.slots[1] as Map;
      expect(secondSlot['id'], 'SPOT002');
      expect(secondSlot['status'], 'occupied');
      expect(secondSlot['vehicle_id'], 'ABC123');
    });

    test('handles empty arrays correctly', () {
      // Arrange
      final json = {
        'building': 'Empty Building',
        'level': 1,
        'size': {'rows': 5, 'cols': 5},
        'entrances': [],
        'exits': [],
        'slots': [],
        'corridors': [],
        'walls': [],
        'ramps': [],
      };

      // Act
      final parkingMap = ParkingMap.fromJson(json);

      // Assert
      expect(parkingMap.building, 'Empty Building');
      expect(parkingMap.entrances, isEmpty);
      expect(parkingMap.exits, isEmpty);
      expect(parkingMap.slots, isEmpty);
      expect(parkingMap.corridors, isEmpty);
      expect(parkingMap.walls, isEmpty);
      expect(parkingMap.ramps, isEmpty);
    });
  });
}