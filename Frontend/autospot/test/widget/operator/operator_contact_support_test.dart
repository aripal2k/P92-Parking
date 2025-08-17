import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/operator/operatorContactSupport_screen.dart';

void main() {
  group('OperatorContactSupportScreen Widget Tests', () {
    // Set up consistent test viewport
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.physicalSizeTestValue = const Size(800, 1200);
      binding.window.devicePixelRatioTestValue = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('displays all UI elements correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Assert - Check app bar
      expect(find.text('Contact Support'), findsOneWidget);

      // Assert - Check header texts
      expect(find.text('Need Help?'), findsOneWidget);
      expect(find.text('If you have issues with your account or login,\nplease reach out to us via the following methods:'), findsOneWidget);

      // Assert - Check support tiles
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('support@autospot.com'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);

      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('+61 xxx xxx xxx'), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsOneWidget);

      expect(find.text('Website'), findsOneWidget);
      expect(find.text('www.website.com'), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets('has correct gradient background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Assert - Find the Container with gradient
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors[0], const Color(0xFFD4EECD));
      expect(gradient.colors[1], const Color(0xFFA3DB94));
    });

    testWidgets('app bar has transparent background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, true);
    });

    testWidgets('support tiles have correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Find containers that are support tiles
      final supportTiles = find.byWidgetPredicate((widget) {
        if (widget is Container) {
          final decoration = widget.decoration as BoxDecoration?;
          return decoration != null && 
                 decoration.color == const Color(0xFFE9F8E4) &&
                 decoration.borderRadius == BorderRadius.circular(12);
        }
        return false;
      });

      // Assert - Should have 3 support tiles
      expect(supportTiles, findsNWidgets(3));

      // Check first support tile decoration
      final firstTile = tester.widget<Container>(supportTiles.first);
      final decoration = firstTile.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE9F8E4));
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotNull);
    });

    testWidgets('icons have correct color and size', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Find icons in support tiles (excluding back arrow)
      final emailIcon = tester.widget<Icon>(find.byIcon(Icons.email));
      final phoneIcon = tester.widget<Icon>(find.byIcon(Icons.phone));
      final websiteIcon = tester.widget<Icon>(find.byIcon(Icons.language));

      // Assert
      expect(emailIcon.size, 28);
      expect(emailIcon.color, Colors.green[800]);

      expect(phoneIcon.size, 28);
      expect(phoneIcon.color, Colors.green[800]);

      expect(websiteIcon.size, 28);
      expect(websiteIcon.color, Colors.green[800]);
    });

    testWidgets('text styles are correct', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Find specific text widgets and check their styles
      final needHelpText = tester.widget<Text>(find.text('Need Help?'));
      expect(needHelpText.style?.fontSize, 22);
      expect(needHelpText.style?.fontWeight, FontWeight.bold);

      final emailTitleText = tester.widget<Text>(find.text('Email'));
      expect(emailTitleText.style?.fontSize, 16);
      expect(emailTitleText.style?.fontWeight, FontWeight.bold);

      final emailSubtitleText = tester.widget<Text>(find.text('support@autospot.com'));
      expect(emailSubtitleText.style?.fontSize, 15);
      expect(emailSubtitleText.style?.color, Colors.black87);
    });

    testWidgets('layout is properly structured', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Assert - Check main column structure
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Row), findsWidgets);
      expect(find.byType(Expanded), findsWidgets);

      // Check that padding exists around the content
      final paddingWidgets = find.ancestor(
        of: find.text('Need Help?'),
        matching: find.byType(Padding),
      );
      expect(paddingWidgets, findsWidgets); // Just check that padding exists, not the exact count
    });

    testWidgets('app bar has back button when pushed to navigator', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OperatorContactSupportScreen(),
                      ),
                    );
                  },
                  child: const Text('Go to support'),
                );
              },
            ),
          ),
        ),
      );

      // Navigate to the screen
      await tester.tap(find.text('Go to support'));
      await tester.pumpAndSettle();

      // Assert - Now the back button should be present
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      
      // Act - Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      
      // Assert - Should be back to original screen
      expect(find.text('Go to support'), findsOneWidget);
    });

    testWidgets('scaffold extends body behind app bar', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, true);
    });

    testWidgets('all text content is centered properly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: OperatorContactSupportScreen(),
        ),
      );

      // Find the header text
      final headerText = tester.widget<Text>(
        find.text('If you have issues with your account or login,\nplease reach out to us via the following methods:')
      );
      
      // Assert
      expect(headerText.textAlign, TextAlign.center);
    });
  });
}

// Helper class for navigation testing
class _TestNavigatorObserver extends NavigatorObserver {
  final VoidCallback? onPop;

  _TestNavigatorObserver({this.onPop});

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop?.call();
  }
}