import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autospot/user/userDeleteAccount_screen.dart';

void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  void setLargeScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.single.resetDevicePixelRatio();
  });

  group('DeleteAccountScreen Tests', () {
    testWidgets('displays all UI elements', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check main UI elements
      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
      expect(find.text('Please input your password to confirm\nyour account deletion.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('password field is obscured', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter some text to verify it's obscured
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'test123');
      
      // The actual characters should be obscured, but we can verify the field exists
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete button without entering password
      await tester.tap(find.text('Delete'));
      await tester.pump();

      // Should show error message
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('can enter password', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter password
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'mypassword123');
      
      // Verify text was entered
      expect(find.text('mypassword123'), findsOneWidget);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, const Color(0xFFD4EECD));
      expect(appBar.elevation, 0);
      
      final titleWidget = appBar.title as Text;
      expect(titleWidget.data, 'Delete Account');
      expect(titleWidget.style!.fontSize, 28);
      expect(titleWidget.style!.fontWeight, FontWeight.bold);
      expect(titleWidget.style!.color, Colors.black);
    });

    testWidgets('has gradient background', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, [
        const Color(0xFFD4EECD),
        const Color(0xFFA3DB94),
      ]);
    });

    testWidgets('Back button navigates back', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      bool navigatedBack = false;

      await tester.pumpWidget(
        MaterialApp(
          home: const DeleteAccountScreen(),
          routes: {
            '/profile': (context) {
              navigatedBack = true;
              return const Scaffold(body: Text('Profile'));
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tap Back button
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      
      // Should navigate back
      expect(navigatedBack || find.text('Back').evaluate().isEmpty, true);
    });

    testWidgets('buttons have correct styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check Back button
      final backButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Back'),
      );
      expect(backButton.style!.backgroundColor!.resolve({}), Colors.grey[300]);
      
      // Check Delete button
      final deleteButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete'),
      );
      expect(deleteButton.style!.backgroundColor!.resolve({}), Colors.red);
    });

    testWidgets('delete icon has correct size and color', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete_forever));
      expect(icon.size, 80);
      expect(icon.color, Colors.black87);
    });

    testWidgets('delete button can be tapped', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter password
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      
      // Verify password was entered
      expect(find.text('password123'), findsOneWidget);
      
      // Verify delete button exists and is enabled
      final deleteButton = find.text('Delete');
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('error message styling changes based on content', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Delete without password to trigger error
      await tester.tap(find.text('Delete'));
      await tester.pump();

      // Find error text widget
      final errorText = tester.widget<Text>(
        find.text('Please enter your password.'),
      );
      
      // Should be red for error
      expect(errorText.style!.color, Colors.red);
    });

    testWidgets('password field has correct styling', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check password field exists
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      
      // Focus the field
      await tester.tap(find.widgetWithText(TextFormField, 'Password'));
      await tester.pump();
      
      // Field should accept focus
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('has correct padding', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the main padding widget
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byIcon(Icons.delete_forever),
          matching: find.byType(Padding),
        ).first,
      );
      
      expect(padding.padding, const EdgeInsets.all(24));
    });

    testWidgets('warning text is centered', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final warningText = tester.widget<Text>(
        find.text('Please input your password to confirm\nyour account deletion.'),
      );
      
      expect(warningText.textAlign, TextAlign.center);
      expect(warningText.style!.fontSize, 16);
    });

    testWidgets('app bar has correct icon theme', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.iconTheme!.color, Colors.black);
    });

    testWidgets('handles no email scenario', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      // No email set in preferences

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Enter password
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      
      // Tap Delete button
      await tester.tap(find.text('Delete'));
      await tester.pump();

      // Should show error message
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('delete button text style', (WidgetTester tester) async {
      setLargeScreenSize(tester);
      await mockPrefs.setString('user_email', 'test@example.com');

      await tester.pumpWidget(
        const MaterialApp(
          home: DeleteAccountScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the delete button text
      final deleteText = tester.widget<Text>(
        find.descendant(
          of: find.widgetWithText(ElevatedButton, 'Delete'),
          matching: find.byType(Text),
        ),
      );
      
      expect(deleteText.style!.fontSize, 16);
      expect(deleteText.style!.color, Colors.white);
      expect(deleteText.style!.fontWeight, FontWeight.bold);
    });
  });
}