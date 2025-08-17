import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:autospot/config/api_config.dart';
import 'dart:convert';

// Manual Mock class for http.Client
class MockClient extends Mock implements http.Client {
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

// AuthService class to encapsulate authentication logic
class AuthService {
  final http.Client client;

  AuthService({required this.client});

  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password cannot be empty');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> register(Map<String, String> userData) async {
    try {
      final response = await client.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> forgotPassword(String email) async {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.forgotPasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    if (email.isEmpty || otp.isEmpty) {
      throw ArgumentError('Email and OTP cannot be empty');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.verifyOtpEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    if (email.isEmpty || otp.isEmpty || newPassword.isEmpty) {
      throw ArgumentError('All fields are required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.resetPasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> changePassword(String email, String oldPassword, String newPassword) async {
    if (email.isEmpty || oldPassword.isEmpty || newPassword.isEmpty) {
      throw ArgumentError('All fields are required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.changePasswordEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> editProfile(Map<String, dynamic> profileData) async {
    if (!profileData.containsKey('email') || profileData['email'].isEmpty) {
      throw ArgumentError('Email is required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.editProfileEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> deleteAccount(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required');
    }

    try {
      final response = await client.post(
        Uri.parse(ApiConfig.deleteAccountEndpoint),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      authService = AuthService(client: mockClient);
    });

    group('login', () {
      test('should return true when credentials are valid', () async {
        // Arrange
        final email = 'test@example.com';
        final password = 'password123';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.loginEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email, 'password': password}),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.login(email, password);

        // Assert
        expect(result, true);
        verify(
          mockClient.post(
            Uri.parse(ApiConfig.loginEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email, 'password': password}),
          ),
        ).called(1);
      });

      test('should return false when credentials are invalid', () async {
        // Arrange
        final email = 'test@example.com';
        final password = 'wrongpassword';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.loginEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email, 'password': password}),
          ),
        ).thenAnswer(
          (_) async => http.Response('{"error": "Invalid credentials"}', 401),
        );

        // Act
        final result = await authService.login(email, password);

        // Assert
        expect(result, false);
      });

      test('should throw ArgumentError when email or password is empty', () {
        // Assert
        expect(() => authService.login('', 'password'), throwsArgumentError);

        expect(
          () => authService.login('email@test.com', ''),
          throwsArgumentError,
        );
      });

      test('should throw Exception on network error', () async {
        // Arrange
        final testUri = Uri.parse(ApiConfig.loginEndpoint);
        final testBody = jsonEncode({
          'email': 'test@example.com',
          'password': 'password',
        });

        when(
          mockClient.post(testUri, headers: ApiConfig.headers, body: testBody),
        ).thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => authService.login('test@example.com', 'password'),
          throwsException,
        );
      });
    });

    group('register', () {
      test('should return user data on successful registration', () async {
        // Arrange
        final userData = {
          'email': 'newuser@example.com',
          'password': 'password123',
          'username': 'newuser',
        };

        final responseData = {
          'id': '123',
          'email': 'newuser@example.com',
          'username': 'newuser',
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.registerEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode(userData),
          ),
        ).thenAnswer((_) async => http.Response(jsonEncode(responseData), 200));

        // Act
        final result = await authService.register(userData);

        // Assert
        expect(result, responseData);
      });

      test('should throw Exception on registration failure', () async {
        // Arrange
        final userData = {
          'email': 'existing@example.com',
          'password': 'password123',
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.registerEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode(userData),
          ),
        ).thenAnswer(
          (_) async => http.Response('{"error": "Email already exists"}', 400),
        );

        // Act & Assert
        expect(() => authService.register(userData), throwsException);
      });
    });

    group('forgotPassword', () {
      test('should return true when request is successful', () async {
        // Arrange
        final email = 'test@example.com';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.forgotPasswordEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email}),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.forgotPassword(email);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError when email is empty', () {
        // Assert
        expect(
          () => authService.forgotPassword(''),
          throwsArgumentError,
        );
      });

      test('should return false when email not found', () async {
        // Arrange
        final email = 'notfound@example.com';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.forgotPasswordEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email}),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "Email not found"}', 404));

        // Act
        final result = await authService.forgotPassword(email);

        // Assert
        expect(result, false);
      });
    });

    group('verifyOtp', () {
      test('should return true when OTP is valid', () async {
        // Arrange
        final email = 'test@example.com';
        final otp = '123456';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.verifyOtpEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email, 'otp': otp}),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.verifyOtp(email, otp);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError when email or OTP is empty', () {
        // Assert
        expect(
          () => authService.verifyOtp('', '123456'),
          throwsArgumentError,
        );

        expect(
          () => authService.verifyOtp('test@example.com', ''),
          throwsArgumentError,
        );
      });

      test('should return false when OTP is invalid', () async {
        // Arrange
        final email = 'test@example.com';
        final otp = 'wrong';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.verifyOtpEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({'email': email, 'otp': otp}),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "Invalid OTP"}', 400));

        // Act
        final result = await authService.verifyOtp(email, otp);

        // Assert
        expect(result, false);
      });
    });

    group('resetPassword', () {
      test('should return true when password reset is successful', () async {
        // Arrange
        final email = 'test@example.com';
        final otp = '123456';
        final newPassword = 'newPassword123';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.resetPasswordEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'new_password': newPassword,
            }),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.resetPassword(email, otp, newPassword);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError when any field is empty', () {
        // Assert
        expect(
          () => authService.resetPassword('', '123456', 'newPass'),
          throwsArgumentError,
        );

        expect(
          () => authService.resetPassword('test@example.com', '', 'newPass'),
          throwsArgumentError,
        );

        expect(
          () => authService.resetPassword('test@example.com', '123456', ''),
          throwsArgumentError,
        );
      });
    });

    group('changePassword', () {
      test('should return true when password change is successful', () async {
        // Arrange
        final email = 'test@example.com';
        final oldPassword = 'oldPass123';
        final newPassword = 'newPass123';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.changePasswordEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.changePassword(email, oldPassword, newPassword);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError when any field is empty', () {
        // Assert
        expect(
          () => authService.changePassword('', 'oldPass', 'newPass'),
          throwsArgumentError,
        );

        expect(
          () => authService.changePassword('test@example.com', '', 'newPass'),
          throwsArgumentError,
        );

        expect(
          () => authService.changePassword('test@example.com', 'oldPass', ''),
          throwsArgumentError,
        );
      });

      test('should return false when old password is incorrect', () async {
        // Arrange
        final email = 'test@example.com';
        final oldPassword = 'wrongPass';
        final newPassword = 'newPass123';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.changePasswordEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "Invalid old password"}', 401));

        // Act
        final result = await authService.changePassword(email, oldPassword, newPassword);

        // Assert
        expect(result, false);
      });
    });

    group('editProfile', () {
      test('should return updated profile data when successful', () async {
        // Arrange
        final profileData = {
          'email': 'test@example.com',
          'username': 'newusername',
          'phone': '+1234567890',
        };

        final expectedResponse = {
          'email': 'test@example.com',
          'username': 'newusername',
          'phone': '+1234567890',
          'updated_at': '2024-01-01T12:00:00Z',
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.editProfileEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode(profileData),
          ),
        ).thenAnswer((_) async => http.Response(jsonEncode(expectedResponse), 200));

        // Act
        final result = await authService.editProfile(profileData);

        // Assert
        expect(result, expectedResponse);
      });

      test('should throw ArgumentError when email is missing', () {
        // Assert
        expect(
          () => authService.editProfile({'username': 'test'}),
          throwsArgumentError,
        );

        expect(
          () => authService.editProfile({'email': ''}),
          throwsArgumentError,
        );
      });

      test('should throw Exception when update fails', () async {
        // Arrange
        final profileData = {
          'email': 'test@example.com',
          'username': 'taken_username',
        };

        when(
          mockClient.post(
            Uri.parse(ApiConfig.editProfileEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode(profileData),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "Username already taken"}', 400));

        // Act & Assert
        expect(
          () => authService.editProfile(profileData),
          throwsException,
        );
      });
    });

    group('deleteAccount', () {
      test('should return true when account deletion is successful', () async {
        // Arrange
        final email = 'test@example.com';
        final password = 'password123';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.deleteAccountEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          ),
        ).thenAnswer((_) async => http.Response('{"success": true}', 200));

        // Act
        final result = await authService.deleteAccount(email, password);

        // Assert
        expect(result, true);
      });

      test('should throw ArgumentError when email or password is empty', () {
        // Assert
        expect(
          () => authService.deleteAccount('', 'password'),
          throwsArgumentError,
        );

        expect(
          () => authService.deleteAccount('test@example.com', ''),
          throwsArgumentError,
        );
      });

      test('should return false when password is incorrect', () async {
        // Arrange
        final email = 'test@example.com';
        final password = 'wrongpassword';

        when(
          mockClient.post(
            Uri.parse(ApiConfig.deleteAccountEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "Invalid password"}', 401));

        // Act
        final result = await authService.deleteAccount(email, password);

        // Assert
        expect(result, false);
      });
    });
  });
}
