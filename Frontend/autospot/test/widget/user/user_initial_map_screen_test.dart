import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:autospot/user/userInitialMap_screen.dart';

void main() {
  group('InitialMapScreen Widget Tests', () {
    testWidgets('displays all UI elements correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert - Check app bar
      expect(find.text('AutoSpot'), findsOneWidget);
      
      // Assert - Check main content
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
      expect(find.text('No parking map loaded'), findsOneWidget);
      expect(find.text('Please select a destination on the dashboard or scan a QR code to view the parking map'), findsOneWidget);
      
      // Assert - Check buttons
      expect(find.text('Select Destination'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('has correct gradient background', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
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

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFD4EECD));
      expect(appBar.elevation, 0);
      expect(appBar.centerTitle, true);
      expect(appBar.automaticallyImplyLeading, false);
    });

    testWidgets('map icon has correct color and size', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final icon = tester.widget<Icon>(find.byIcon(Icons.map_outlined));
      expect(icon.size, 80);
      expect(icon.color, const Color(0xFF68B245));
    });

    testWidgets('select destination button navigates to dashboard', (WidgetTester tester) async {
      // Arrange
      String? navigatedRoute;
      
      await tester.pumpWidget(
        MaterialApp(
          home: const InitialMapScreen(),
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Dashboard')),
            );
          },
        ),
      );

      // Act
      await tester.tap(find.text('Select Destination'));
      await tester.pumpAndSettle();

      // Assert
      expect(navigatedRoute, '/dashboard');
    });

    testWidgets('scan QR code button navigates to QR intro', (WidgetTester tester) async {
      // Arrange
      String? navigatedRoute;
      
      await tester.pumpWidget(
        MaterialApp(
          home: const InitialMapScreen(),
          onGenerateRoute: (settings) {
            navigatedRoute = settings.name;
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('QR Intro')),
            );
          },
        ),
      );

      // Act
      await tester.tap(find.text('Scan QR Code'));
      await tester.pumpAndSettle();

      // Assert
      expect(navigatedRoute, '/qr-intro');
    });

    testWidgets('select destination button has correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Select Destination'),
          matching: find.byType(ElevatedButton),
        ),
      );
      final buttonStyle = button.style!;
      
      final backgroundColor = buttonStyle.backgroundColor!.resolve({});
      expect(backgroundColor, const Color(0xFFA3DB94));
    });

    testWidgets('scan QR code button has icon and text', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert - Check that both the text and icon exist
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      
      // The button is created with TextButton.icon, so let's just verify
      // that the text and icon are present and can be tapped
      final scanQRText = find.text('Scan QR Code');
      expect(scanQRText, findsOneWidget);
      
      // Verify the text is styled correctly
      final textWidget = tester.widget<Text>(scanQRText);
      expect(textWidget.style?.color, Colors.black87);
    });

    testWidgets('text content is centered', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final instructionText = tester.widget<Text>(
        find.text('Please select a destination on the dashboard or scan a QR code to view the parking map')
      );
      expect(instructionText.textAlign, TextAlign.center);
    });

    testWidgets('main content is vertically centered', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(Column),
        ).first,
      );
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets('scaffold background color is correct', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('padding is applied to instruction text', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: InitialMapScreen(),
        ),
      );

      // Assert
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('Please select a destination on the dashboard or scan a QR code to view the parking map'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 32.0));
    });
  });
}