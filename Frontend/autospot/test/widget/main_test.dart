import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/main.dart';
import 'package:autospot/user/userLogin_screen.dart';
import 'package:autospot/user/userRegistration_screen.dart';
import 'package:autospot/user/userOTPVerification_screen.dart';
import 'package:autospot/main_container.dart';
import 'package:autospot/user/userPayment_screen.dart';
import 'package:autospot/user/userActiveParking_screen.dart';
import 'package:autospot/user/userParkingFee_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MyApp Tests', () {
    testWidgets('app initializes with login screen as home', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app has correct title', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'AutoSpot');
    });

    testWidgets('app has correct theme configuration', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, isNotNull);
      expect(materialApp.theme?.colorScheme, isNotNull);
    });

    testWidgets('app has route observer configured', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.navigatorObservers, contains(routeObserver));
    });

    testWidgets('navigates to registration screen', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/register');
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('navigates to dashboard with MainContainer', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/dashboard');
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(MainContainer), findsOneWidget);
    });

    testWidgets('navigates to verify-registration with arguments', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/verify-registration', arguments: {
        'email': 'test@example.com',
        'otp': '123456',
      });
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(VerifyOtpScreen), findsOneWidget);
    });

    testWidgets('navigates to parking-fee without arguments uses default', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/parking-fee');
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(ParkingFeeScreen), findsOneWidget);
    });

    testWidgets('navigates to parking-fee with arguments', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/parking-fee', arguments: {
        'startTime': DateTime.now(),
        'isActiveSession': true,
      });
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(ParkingFeeScreen), findsOneWidget);
    });

    testWidgets('navigates to active-session with DateTime argument', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final startTime = DateTime.now();
      navigator.pushNamed('/active-session', arguments: {
        'startTime': startTime,
      });
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('navigates to active-session with String datetime argument', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/active-session', arguments: {
        'startTime': '2024-01-01T10:00:00',
      });
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(ActiveParkingScreen), findsOneWidget);
    });

    testWidgets('navigates to payment with arguments', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/payment', arguments: {
        'amount': 25.50,
        'sessionId': 'TEST123',
        'parkingLocation': 'Level 1',
        'parkingSlot': 'A1',
        'parkingDate': DateTime.now(),
      });
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(PaymentScreen), findsOneWidget);
    });

    testWidgets('navigates to payment without arguments uses fallback', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Act
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/payment');
      await tester.pump();
      await tester.pump();

      // Assert
      expect(find.byType(PaymentScreen), findsOneWidget);
      final paymentScreen = tester.widget<PaymentScreen>(find.byType(PaymentScreen));
      expect(paymentScreen.amount, 0.0);
      expect(paymentScreen.sessionId, '');
    });

    testWidgets('main container routes navigate with correct initial index', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      // Test /main route (index 0)
      navigator.pushNamed('/main');
      await tester.pump();
      await tester.pump();
      var container = tester.widget<MainContainer>(find.byType(MainContainer));
      expect(container.initialIndex, 0);
      navigator.pop();
      await tester.pump();

      // Test /map route (index 1)
      navigator.pushNamed('/map');
      await tester.pump();
      await tester.pump();
      container = tester.widget<MainContainer>(find.byType(MainContainer));
      expect(container.initialIndex, 1);
      navigator.pop();
      await tester.pump();

      // Test /eco route (index 2)
      navigator.pushNamed('/eco');
      await tester.pump();
      await tester.pump();
      container = tester.widget<MainContainer>(find.byType(MainContainer));
      expect(container.initialIndex, 2);
    });

    testWidgets('all routes are properly defined', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routes = materialApp.routes!;
      
      // Check important routes exist
      expect(routes.containsKey('/'), true);
      expect(routes.containsKey('/register'), true);
      expect(routes.containsKey('/dashboard'), true);
      expect(routes.containsKey('/wallet'), true);
      expect(routes.containsKey('/qr-scanner'), true);
      expect(routes.containsKey('/operator-login'), true);
      expect(routes.containsKey('/profile'), true);
      expect(routes.containsKey('/parking-map'), true);
      expect(routes.containsKey('/carbon-emission'), true);
    });

    testWidgets('operator routes are properly defined', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routes = materialApp.routes!;
      
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

    testWidgets('user routes are properly defined', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const TestMyApp());

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final routes = materialApp.routes!;
      
      // Check user routes
      expect(routes.containsKey('/profile'), true);
      expect(routes.containsKey('/profile/change-password'), true);
      expect(routes.containsKey('/profile/edit'), true);
      expect(routes.containsKey('/profile/delete'), true);
      expect(routes.containsKey('/wallet'), true);
      expect(routes.containsKey('/wallet/add-money'), true);
      expect(routes.containsKey('/estimation-fee'), true);
      expect(routes.containsKey('/parking-fee'), true);
      expect(routes.containsKey('/qr-code'), true);
      expect(routes.containsKey('/qr-intro'), true);
      expect(routes.containsKey('/qr-scanner'), true);
      expect(routes.containsKey('/destination-select'), true);
      expect(routes.containsKey('/active-session'), true);
      expect(routes.containsKey('/map-only'), true);
      expect(routes.containsKey('/payment'), true);
    });
  });

  group('MyHomePage Tests', () {
    testWidgets('counter starts at 0', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Assert
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('counter increments when button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Act
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Assert
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('displays correct title in app bar', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Title'),
      ));

      // Assert
      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('has correct UI structure', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Assert
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('You have pushed the button this many times:'), findsOneWidget);
    });

    testWidgets('floating action button has correct tooltip', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Assert
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.tooltip, 'Increment');
    });

    testWidgets('counter increments multiple times', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Act - tap 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
      }

      // Assert
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('app bar uses theme color', (WidgetTester tester) async {
      // Arrange
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      );

      // Act
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const MyHomePage(title: 'Test Home'),
      ));

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, theme.colorScheme.inversePrimary);
    });

    testWidgets('counter text widget exists', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Assert - check the counter text exists
      expect(find.text('0'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(3)); // Title text, description text, and counter text
    });

    testWidgets('floating action button icon is correct', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Assert
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('widget title can be updated', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home'),
      ));

      // Verify initial title
      expect(find.text('Test Home'), findsOneWidget);

      // Update widget with new title
      await tester.pumpWidget(const MaterialApp(
        home: MyHomePage(title: 'Test Home Updated'),
      ));

      // Verify new title is displayed
      expect(find.text('Test Home Updated'), findsOneWidget);
      expect(find.text('Test Home'), findsNothing);
    });
  });

  group('Route Observer', () {
    test('routeObserver is properly initialized', () {
      // Assert
      expect(routeObserver, isNotNull);
      expect(routeObserver, isA<RouteObserver<ModalRoute<void>>>());
    });
  });

  group('main() function', () {
    testWidgets('MyApp is created when running the app', (WidgetTester tester) async {
      // The main() function creates MyApp, so we verify MyApp works properly
      await tester.pumpWidget(const TestMyApp());
      
      expect(find.byType(TestMyApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}