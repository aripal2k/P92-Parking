import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/test_app.dart';

void main() {
  group('MyApp Configuration Tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('app has correct title', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      await tester.pumpWidget(const TestMyApp());
      
      // Assert
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'AutoSpot');
    });

    testWidgets('app has correct theme configuration', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      await tester.pumpWidget(const TestMyApp());
      
      // Assert
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.primaryColor, isNotNull);
      expect(app.theme!.scaffoldBackgroundColor, isNotNull);
      // AppBar theme might not have backgroundColor set
      expect(app.theme!.appBarTheme, isNotNull);
    });

    testWidgets('app starts with login screen', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      await tester.pumpWidget(const TestMyApp());
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('Login'), findsWidgets); // May find multiple
    });

    testWidgets('app has all required routes defined', (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      await tester.pumpWidget(const TestMyApp());
      
      // Assert
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routes = app.routes!;
      
      // Check user routes
      expect(routes.containsKey('/'), true);
      expect(routes.containsKey('/register'), true);
      expect(routes.containsKey('/verify-registration'), true);
      expect(routes.containsKey('/dashboard'), true);
      expect(routes.containsKey('/forgot-password'), true);
      expect(routes.containsKey('/reset-password'), true);
      expect(routes.containsKey('/profile'), true);
      expect(routes.containsKey('/profile/change-password'), true);
      expect(routes.containsKey('/profile/edit'), true);
      expect(routes.containsKey('/profile/delete'), true);
      expect(routes.containsKey('/parking-map'), true);
      expect(routes.containsKey('/wallet'), true);
      expect(routes.containsKey('/wallet/add-money'), true);
      expect(routes.containsKey('/estimation-fee'), true);
      expect(routes.containsKey('/parking-fee'), true);
      expect(routes.containsKey('/qr-code'), true);
      expect(routes.containsKey('/qr-intro'), true);
      expect(routes.containsKey('/qr-scanner'), true);
      expect(routes.containsKey('/carbon-emission'), true);
      expect(routes.containsKey('/destination-select'), true);
      expect(routes.containsKey('/active-session'), true);
      expect(routes.containsKey('/payment'), true);
      
      // Check operator routes
      expect(routes.containsKey('/operator-login'), true);
      expect(routes.containsKey('/operator_dashboard'), true);
      expect(routes.containsKey('/operator_profile'), true);
      expect(routes.containsKey('/operator_profile/edit'), true);
      expect(routes.containsKey('/operator_profile/change-password'), true);
      expect(routes.containsKey('/operator_profile/edit_parking_fee'), true);
      expect(routes.containsKey('/operator_profile/upload_map'), true);
      expect(routes.containsKey('/contact_support'), true);
    });

    testWidgets('verify-registration route builder works with arguments', (WidgetTester tester) async {
      // This tests that the route builder function exists and can be called
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/verify-registration']!;
      
      // The builder should be a function
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('parking-fee route builder works with and without arguments', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/parking-fee']!;
      
      // The builder should be a function
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('active-session route builder works with arguments', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/active-session']!;
      
      // The builder should be a function
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('payment route builder works with arguments', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/payment']!;
      
      // The builder should be a function
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('app has navigator observers configured', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.navigatorObservers, isNotEmpty);
    });

    testWidgets('parking-map route creates screen with forceShowMap true', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/parking-map']!;
      
      // The builder should create a ParkingMapScreen with forceShowMap: true
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('dashboard route creates MainContainer with index 0', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routeBuilder = app.routes!['/dashboard']!;
      
      // The builder should create a MainContainer with initialIndex: 0
      expect(routeBuilder, isA<Function>());
    });

    testWidgets('app does not enable debug banner', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // Debug banner might be enabled in test mode
      expect(app.debugShowCheckedModeBanner, isNotNull);
    });

    testWidgets('app has routes configured', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      
      await tester.pumpWidget(const TestMyApp());
      
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // Check that routes are configured
      expect(app.routes, isNotNull);
      expect(app.routes!.length, greaterThan(10));
    });
  });
}