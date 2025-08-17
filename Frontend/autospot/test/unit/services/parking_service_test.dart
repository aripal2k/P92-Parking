import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:autospot/config/api_config.dart';
import 'dart:convert';

// Manual Mock class for http.Client
class MockClient extends Mock implements http.Client {
  @override
  Future<http.Response> get(
    Uri? url, {
    Map<String, String>? headers,
  }) => super.noSuchMethod(
    Invocation.method(
      #get,
      [url],
      {#headers: headers},
    ),
    returnValue: Future.value(http.Response('', 200)),
    returnValueForMissingStub: Future.value(http.Response('', 200)),
  );

  @override
  Future<http.Response> post(
    Uri? url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => super.noSuchMethod(
    Invocation.method(
      #post,
      [url],
      {#headers: headers, #body: body, #encoding: encoding},
    ),
    returnValue: Future.value(http.Response('', 200)),
    returnValueForMissingStub: Future.value(http.Response('', 200)),
  );
}

// ParkingService class to encapsulate parking operations
class ParkingService {
  final http.Client client;

  ParkingService({required this.client});

  Future<Map<String, dynamic>> startSession({
    required String username,
    required String vehicleId,
    required String spotId,
  }) async {
    if (username.isEmpty || vehicleId.isEmpty || spotId.isEmpty) {
      throw ArgumentError('All parameters are required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.startSessionEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'username': username,
          'vehicle_id': vehicleId,
          'spot_id': spotId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to start session: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> endSession({
    required String sessionId,
    required String username,
  }) async {
    if (sessionId.isEmpty || username.isEmpty) {
      throw ArgumentError('Session ID and username are required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.endSessionEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'session_id': sessionId,
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to end session: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<double> predictFare({
    required String buildingName,
    required int hours,
    required int minutes,
  }) async {
    if (buildingName.isEmpty || (hours == 0 && minutes == 0)) {
      throw ArgumentError('Invalid parameters');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.predictFareEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'building_name': buildingName,
          'hours': hours,
          'minutes': minutes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['predicted_fare'] as num).toDouble();
      } else {
        throw Exception('Failed to predict fare: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDestinations() async {
    try {
      final response = await client.get(
        Uri.parse(ApiConfig.getAvailableDestinationsEndpoint),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['destinations']);
      } else {
        throw Exception('Failed to get destinations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

void main() {
  group('ParkingService Tests', () {
    late ParkingService parkingService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      parkingService = ParkingService(client: mockClient);
    });

    group('startSession', () {
      test('should return session data when successful', () async {
        // Arrange
        final username = 'testuser';
        final vehicleId = 'ABC123';
        final spotId = 'A01';
        final expectedResponse = {
          'session_id': 'session123',
          'start_time': '2024-01-01T10:00:00Z',
          'spot_id': spotId,
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.startSessionEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'username': username,
              'vehicle_id': vehicleId,
              'spot_id': spotId,
            }),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(expectedResponse), 200),
        );

        // Act
        final result = await parkingService.startSession(
          username: username,
          vehicleId: vehicleId,
          spotId: spotId,
        );

        // Assert
        expect(result, expectedResponse);
      });

      test('should throw ArgumentError for empty parameters', () {
        // Assert
        expect(
          () => parkingService.startSession(
            username: '',
            vehicleId: 'ABC123',
            spotId: 'A01',
          ),
          throwsArgumentError,
        );

        expect(
          () => parkingService.startSession(
            username: 'testuser',
            vehicleId: '',
            spotId: 'A01',
          ),
          throwsArgumentError,
        );

        expect(
          () => parkingService.startSession(
            username: 'testuser',
            vehicleId: 'ABC123',
            spotId: '',
          ),
          throwsArgumentError,
        );
      });

      test('should throw Exception when session already exists', () async {
        // Arrange
        final username = 'testuser';
        final vehicleId = 'ABC123';
        final spotId = 'A01';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.startSessionEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'username': username,
              'vehicle_id': vehicleId,
              'spot_id': spotId,
            }),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            '{"error": "User already has active parking session"}',
            400,
          ),
        );

        // Act & Assert
        expect(
          () => parkingService.startSession(
            username: username,
            vehicleId: vehicleId,
            spotId: spotId,
          ),
          throwsException,
        );
      });
    });

    group('endSession', () {
      test('should return session summary when successful', () async {
        // Arrange
        final sessionId = 'session123';
        final username = 'testuser';
        final expectedResponse = {
          'session_id': sessionId,
          'duration_minutes': 120,
          'total_fee': 25.50,
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.endSessionEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'session_id': sessionId,
              'username': username,
            }),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode(expectedResponse), 200),
        );

        // Act
        final result = await parkingService.endSession(
          sessionId: sessionId,
          username: username,
        );

        // Assert
        expect(result, expectedResponse);
      });

      test('should throw ArgumentError for empty parameters', () {
        // Assert
        expect(
          () => parkingService.endSession(
            sessionId: '',
            username: 'testuser',
          ),
          throwsArgumentError,
        );

        expect(
          () => parkingService.endSession(
            sessionId: 'session123',
            username: '',
          ),
          throwsArgumentError,
        );
      });
    });

    group('predictFare', () {
      test('should return predicted fare when successful', () async {
        // Arrange
        final buildingName = 'Building A';
        final hours = 2;
        final minutes = 30;
        final expectedFare = 35.75;

        when(
          mockClient.post(
            Uri.parse(ApiConfig.predictFareEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'building_name': buildingName,
              'hours': hours,
              'minutes': minutes,
            }),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'predicted_fare': expectedFare}),
            200,
          ),
        );

        // Act
        final result = await parkingService.predictFare(
          buildingName: buildingName,
          hours: hours,
          minutes: minutes,
        );

        // Assert
        expect(result, expectedFare);
      });

      test('should throw ArgumentError for invalid parameters', () {
        // Assert
        expect(
          () => parkingService.predictFare(
            buildingName: '',
            hours: 1,
            minutes: 0,
          ),
          throwsArgumentError,
        );

        expect(
          () => parkingService.predictFare(
            buildingName: 'Building A',
            hours: 0,
            minutes: 0,
          ),
          throwsArgumentError,
        );
      });
    });

    group('getAvailableDestinations', () {
      test('should return destinations list when successful', () async {
        // Arrange
        final expectedDestinations = [
          {'id': '1', 'name': 'Building A', 'available_spots': 10},
          {'id': '2', 'name': 'Building B', 'available_spots': 5},
        ];

        when(
          mockClient.get(
            Uri.parse(ApiConfig.getAvailableDestinationsEndpoint),
            headers: ApiConfig.headers,
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'destinations': expectedDestinations}),
            200,
          ),
        );

        // Act
        final result = await parkingService.getAvailableDestinations();

        // Assert
        expect(result, expectedDestinations);
      });

      test('should throw Exception when request fails', () async {
        // Arrange
        when(
          mockClient.get(
            Uri.parse(ApiConfig.getAvailableDestinationsEndpoint),
            headers: ApiConfig.headers,
          ),
        ).thenAnswer(
          (_) async => http.Response('{"error": "Service unavailable"}', 503),
        );

        // Act & Assert
        expect(
          () => parkingService.getAvailableDestinations(),
          throwsException,
        );
      });
    });
  });
}