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

// WalletService class to encapsulate wallet operations
class WalletService {
  final http.Client client;

  WalletService({required this.client});

  Future<double> getBalance(String email) async {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    try {
      final response = await client.get(
        Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['balance'] as num).toDouble();
      } else {
        throw Exception('Failed to get balance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> addMoney(String email, double amount, String paymentMethod) async {
    if (email.isEmpty || amount <= 0) {
      throw ArgumentError('Invalid parameters');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.addMoneyEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'amount': amount,
          'payment_method': paymentMethod,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods(String email) async {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    try {
      final response = await client.get(
        Uri.parse(ApiConfig.getPaymentMethodsEndpoint(email)),
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['payment_methods']);
      } else {
        throw Exception('Failed to get payment methods: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

void main() {
  group('WalletService Tests', () {
    late WalletService walletService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      walletService = WalletService(client: mockClient);
    });

    group('getBalance', () {
      test('should return balance when request is successful', () async {
        // Arrange
        final email = 'test@example.com';
        final expectedBalance = 100.50;

        when(
          mockClient.get(
            Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
            headers: ApiConfig.headers,
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'balance': expectedBalance}),
            200,
          ),
        );

        // Act
        final result = await walletService.getBalance(email);

        // Assert
        expect(result, expectedBalance);
        verify(
          mockClient.get(
            Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
            headers: ApiConfig.headers,
          ),
        ).called(1);
      });

      test('should throw ArgumentError when email is empty', () {
        // Assert
        expect(
          () => walletService.getBalance(''),
          throwsArgumentError,
        );
      });

      test('should throw Exception when request fails', () async {
        // Arrange
        final email = 'test@example.com';

        when(
          mockClient.get(
            Uri.parse(ApiConfig.getWalletBalanceEndpoint(email)),
            headers: ApiConfig.headers,
          ),
        ).thenAnswer(
          (_) async => http.Response('{"error": "Not found"}', 404),
        );

        // Act & Assert
        expect(
          () => walletService.getBalance(email),
          throwsException,
        );
      });
    });

    group('addMoney', () {
      test('should return true when money is added successfully', () async {
        // Arrange
        final email = 'test@example.com';
        final amount = 50.0;
        final paymentMethod = 'credit_card';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.addMoneyEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'amount': amount,
              'payment_method': paymentMethod,
            }),
          ),
        ).thenAnswer(
          (_) async => http.Response('{"success": true}', 200),
        );

        // Act
        final result = await walletService.addMoney(email, amount, paymentMethod);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError for invalid parameters', () {
        // Assert
        expect(
          () => walletService.addMoney('', 50.0, 'credit_card'),
          throwsArgumentError,
        );

        expect(
          () => walletService.addMoney('test@example.com', 0, 'credit_card'),
          throwsArgumentError,
        );

        expect(
          () => walletService.addMoney('test@example.com', -10, 'credit_card'),
          throwsArgumentError,
        );
      });
    });

    group('getPaymentMethods', () {
      test('should return payment methods list when successful', () async {
        // Arrange
        final email = 'test@example.com';
        final expectedMethods = [
          {'id': '1', 'type': 'credit_card', 'last_four': '1234'},
          {'id': '2', 'type': 'debit_card', 'last_four': '5678'},
        ];

        when(
          mockClient.get(
            Uri.parse(ApiConfig.getPaymentMethodsEndpoint(email)),
            headers: ApiConfig.headers,
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'payment_methods': expectedMethods}),
            200,
          ),
        );

        // Act
        final result = await walletService.getPaymentMethods(email);

        // Assert
        expect(result, expectedMethods);
      });

      test('should throw ArgumentError when email is empty', () {
        // Assert
        expect(
          () => walletService.getPaymentMethods(''),
          throwsArgumentError,
        );
      });
    });
  });
}