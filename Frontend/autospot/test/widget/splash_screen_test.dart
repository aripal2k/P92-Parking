import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/screens/splash_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('SplashScreen Basic Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('SplashScreen is a StatefulWidget', (WidgetTester tester) async {
      // Assert
      expect(const SplashScreen(), isA<StatefulWidget>());
    });

    testWidgets('SplashScreen can be constructed with key', (WidgetTester tester) async {
      // Arrange
      const key = Key('splash_key');
      
      // Act
      const widget = SplashScreen(key: key);
      
      // Assert
      expect(widget.key, equals(key));
    });

    testWidgets('SplashScreen createState returns correct type', (WidgetTester tester) async {
      // Arrange
      const widget = SplashScreen();
      
      // Act
      final state = widget.createState();
      
      // Assert
      expect(state, isNotNull);
      expect(state.runtimeType.toString(), contains('SplashScreenState'));
    });

    testWidgets('SplashScreen widget type verification', (WidgetTester tester) async {
      // Assert - Verify widget is correct type
      expect(SplashScreen, isNotNull);
      expect(const SplashScreen().runtimeType, equals(SplashScreen));
    });

    testWidgets('SplashScreen properties are correctly initialized', (WidgetTester tester) async {
      // Arrange
      const widget = SplashScreen();
      
      // Assert
      expect(widget.key, isNull); // Default key is null
      expect(widget.hashCode, isNotNull);
      expect(widget.toString(), contains('SplashScreen'));
    });

    testWidgets('Multiple SplashScreen instances can be created', (WidgetTester tester) async {
      // Arrange
      const widget1 = SplashScreen(key: Key('splash1'));
      const widget2 = SplashScreen(key: Key('splash2'));
      
      // Assert
      expect(widget1, isNot(equals(widget2)));
      expect(widget1.key, isNot(equals(widget2.key)));
    });

    testWidgets('SplashScreen State can be created', (WidgetTester tester) async {
      // Arrange
      const widget = SplashScreen();
      
      // Act
      final state1 = widget.createState();
      final state2 = widget.createState();
      
      // Assert - Each call creates a new state instance
      expect(state1, isNot(equals(state2)));
      expect(state1, isNotNull);
      expect(state2, isNotNull);
    });

    testWidgets('SplashScreen equality test', (WidgetTester tester) async {
      // Arrange
      const widget1 = SplashScreen();
      const widget2 = SplashScreen();
      const widget3 = SplashScreen(key: Key('different'));
      
      // Assert
      expect(widget1.runtimeType, equals(widget2.runtimeType)); // Same type
      expect(widget1.key, equals(widget2.key)); // Both have null keys
      expect(widget1.key, isNot(equals(widget3.key))); // Different keys
    });
  });
}