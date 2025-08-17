import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Mock HTTP Client for testing API calls
class TestMockClient extends MockClient {
  TestMockClient(super.fn);
}

/// Common test helpers
class TestHelpers {
  /// Create a MaterialApp wrapper for testing widgets
  static Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
      onGenerateRoute: (settings) {
        // Mock route generation for navigation testing
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Navigated to: ${settings.name}')),
          ),
        );
      },
    );
  }

  /// Set up mock SharedPreferences with common test data
  static Future<void> setupMockSharedPreferences({
    String? userEmail,
    String? authToken,
    String? userName,
    String? userId,
    Map<String, Object>? additionalData,
  }) async {
    final Map<String, Object> values = {
      if (userEmail != null) 'user_email': userEmail,
      if (authToken != null) 'auth_token': authToken,
      if (userName != null) 'user_name': userName,
      if (userId != null) 'user_id': userId,
    };

    if (additionalData != null) {
      values.addAll(additionalData);
    }

    SharedPreferences.setMockInitialValues(values);
  }

  /// Create a mock successful HTTP response
  static http.Response createSuccessResponse(
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Create a mock error HTTP response
  static http.Response createErrorResponse(
    String message, {
    int statusCode = 400,
  }) {
    return http.Response(
      jsonEncode({'detail': message}),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Set up a mock HTTP client for testing
  static MockClient setupMockHttpClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return MockClient(handler);
  }

  /// Pump widget and settle with timeout handling
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  }

  /// Find and tap a widget with text
  static Future<void> tapByText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Find and enter text in a TextFormField
  static Future<void> enterText(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final finder = find.widgetWithText(TextFormField, label);
    expect(finder, findsOneWidget);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Verify navigation occurred
  static void expectNavigation(String? navigatedRoute, String expectedRoute) {
    expect(navigatedRoute, expectedRoute);
  }

  /// Create a test navigator observer
  static TestNavigatorObserver createNavigatorObserver() {
    return TestNavigatorObserver();
  }

  /// Set up test viewport size
  static void setUpTestViewport({
    Size size = const Size(800, 1200),
    double pixelRatio = 1.0,
  }) {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = size;
    binding.window.devicePixelRatioTestValue = pixelRatio;
  }

  /// Tear down test viewport
  static void tearDownTestViewport() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  }
}

/// Test Navigator Observer for tracking navigation
class TestNavigatorObserver extends NavigatorObserver {
  String? lastPushedRoute;
  String? lastPoppedRoute;
  String? lastReplacedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPoppedRoute = route.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    lastReplacedRoute = newRoute?.settings.name;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Track removed routes if needed
  }
}

/// Common test data factory
class TestDataFactory {
  static Map<String, dynamic> createUserData({
    String email = 'test@example.com',
    String name = 'Test User',
    String phone = '+1234567890',
  }) {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> createLoginResponse({
    String token = 'test_token_123',
    String email = 'test@example.com',
    String name = 'Test User',
  }) {
    return {
      'access_token': token,
      'user': {'email': email, 'name': name},
    };
  }

  static Map<String, dynamic> createWalletData({
    double balance = 100.0,
    String currency = 'USD',
  }) {
    return {
      'balance': balance,
      'currency': currency,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> createParkingSessionData({
    String spotId = 'A01',
    String startTime = '',
    double rate = 5.0,
    String building = 'Building A',
  }) {
    final start = startTime.isEmpty
        ? DateTime.now().toIso8601String()
        : startTime;
    return {
      'spot_id': spotId,
      'start_time': start,
      'hourly_rate': rate,
      'building': building,
      'status': 'active',
    };
  }
}
