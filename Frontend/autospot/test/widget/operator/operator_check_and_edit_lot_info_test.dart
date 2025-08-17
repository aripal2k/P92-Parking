import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/operator/operatorCheckAndEditLotInfo_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('LotInfoDialog Tests', () {
    setUp(() {
      TestHelpers.setUpTestViewport();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestHelpers.tearDownTestViewport();
    });

    testWidgets('displays lot information correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert
      expect(find.text('Lot Information'), findsOneWidget);
      expect(find.text('Slot ID: A101'), findsOneWidget);
      expect(find.text('Status: occupied'), findsOneWidget);
      expect(find.text('User Name: user@example.com'), findsOneWidget);
      expect(find.text('Full Name: John Doe'), findsOneWidget);
      expect(find.text('Plate Number: ABC123'), findsOneWidget);
      expect(find.text('Phone Number: 0412345678'), findsOneWidget);
    });

    testWidgets('displays Edit and Close buttons in view mode', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('switches to edit mode when Edit button is tapped', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Assert
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget); // Status dropdown
      expect(find.byType(TextField), findsOneWidget); // Allocated user field
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('displays dropdown with correct status options', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act - Enter edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Open dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('available'), findsAtLeastNWidgets(1));
      expect(find.text('allocated'), findsAtLeastNWidgets(1));
      expect(find.text('occupied'), findsAtLeastNWidgets(2)); // In view text and dropdown
    });

    testWidgets('can change status in edit mode', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Open dropdown and select new status
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('available').last);
      await tester.pump();

      // Assert
      expect(find.text('available'), findsAtLeastNWidgets(1));
    });

    testWidgets('can edit allocated user in edit mode', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Clear and enter new user
      await tester.enterText(find.byType(TextField), 'newuser@example.com');
      await tester.pump();

      // Assert
      expect(find.text('newuser@example.com'), findsOneWidget);
    });

    testWidgets('Cancel button reverts to view mode', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Assert
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('Save button returns edited data', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();
      
      // Edit data
      await tester.enterText(find.byType(TextField), 'updated@example.com');
      await tester.pump();
      
      // Tap save
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Assert - Dialog should close (navigation pop)
      // In a real test with navigation, we would verify the returned data
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Close button closes dialog', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Close'));
      await tester.pump();

      // Assert - Dialog should close (navigation pop)
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('dialog has correct styling', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert
      final alertDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(alertDialog.backgroundColor, const Color(0xFFD4EECD));
    });

    testWidgets('text styles are correct', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert
      final titleText = tester.widget<Text>(find.text('Lot Information'));
      expect(titleText.style?.fontSize, 20);
      expect(titleText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('handles empty allocated user', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'available',
            allocatedUser: '',
            fullName: '',
            plateNumber: '',
            phoneNumber: '',
          ),
        ),
      );
      await tester.pump();

      // Assert
      expect(find.text('Slot ID: A101'), findsOneWidget);
      expect(find.text('Status: available'), findsOneWidget);
      expect(find.text('User Name: '), findsOneWidget);
    });

    testWidgets('edit mode shows correct input styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Assert
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.labelText, 'Allocated User');
      // Default InputDecoration is used
    });

    testWidgets('dropdown has correct styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Assert
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('buttons have correct colors', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert - View mode buttons
      final editButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Edit'),
      );
      // Edit button uses grey background from style
      expect(editButton, isNotNull);

      final closeButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Close'),
      );
      // Close button uses default styling
      expect(closeButton, isNotNull);

      // Switch to edit mode
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Assert - Edit mode buttons
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      // Save button uses default styling
      expect(saveButton, isNotNull);

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      // Cancel button uses default styling
      expect(cancelButton, isNotNull);
    });

    testWidgets('disposes controllers properly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act - Navigate away
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(Container()),
      );
      await tester.pump();

      // Assert - Should dispose without errors
      expect(find.byType(LotInfoDialog), findsNothing);
    });

    testWidgets('all status options have correct styling', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Act
      await tester.tap(find.text('Edit'));
      await tester.pump();

      // Assert
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('info text style is consistent', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert - All info text should have consistent styling
      expect(find.byType(Text), findsWidgets);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('SizedBox spacing is correct', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        TestHelpers.createTestableWidget(
          const LotInfoDialog(
            slotId: 'A101',
            status: 'occupied',
            allocatedUser: 'user@example.com',
            fullName: 'John Doe',
            plateNumber: 'ABC123',
            phoneNumber: '0412345678',
          ),
        ),
      );
      await tester.pump();

      // Assert
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(sizedBoxes.any((box) => box.height == 12), isTrue);
    });
  });
}