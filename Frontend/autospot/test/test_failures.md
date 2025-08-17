# Frontend Test Failures Documentation

## Overview
This document explains common test failures in the Flutter frontend application and their resolutions. These failures typically occur due to widget dependencies, async operations, or platform-specific features.

## Common Test Failures

### 1. Timer and Animation Failures
**Affected Widgets:**
- SplashScreen (timer-based navigation)
- Loading animations
- Countdown timers

**Failure Symptoms:**
```dart
Timer was pending at the end of the test.
Consider using FakeAsync or pump/pumpAndSettle.
```

**Resolution:**
- Use test helper classes that bypass timers
- Use `TestMyApp` instead of `MyApp` to avoid SplashScreen timer
- Call `tester.pumpAndSettle()` after animations

**Test Helper Pattern:**
```dart
class TestMyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: UserLoginScreen(), // Skip splash screen
    );
  }
}
```

### 2. API Call Failures
**Affected Screens:**
- Login/Registration screens
- Payment screens
- Wallet screens
- Parking session screens

**Failure Symptoms:**
```dart
Exception: Failed to load data
HTTP 400: Bad Request
Connection timeout
```

**Resolution:**
- Create test versions of screens that bypass API calls
- Mock SharedPreferences for user data
- Use test helpers to avoid real network requests

**Mocking Strategy:**
```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({
    'user_email': 'test@example.com',
    'wallet_balance': '100.00',
    'session_id': 'test_session_123',
  });
});
```

### 3. SharedPreferences Failures
**Affected Tests:**
- User authentication tests
- Session management tests
- Wallet balance tests

**Failure Symptoms:**
```dart
Null check operator used on a null value
SharedPreferences not initialized
```

**Resolution:**
Always initialize mock SharedPreferences in setUp:

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({
    'user_email': 'test@example.com',
    'selected_destination': 'Building A',
  });
});
```

### 4. Navigation Failures
**Affected Tests:**
- Screen transition tests
- Bottom navigation tests
- Route parameter passing

**Failure Symptoms:**
```dart
Could not find a generator for route
Navigator operation requested with a context that does not include a Navigator
```

**Resolution:**
Wrap widgets with MaterialApp and define routes:

```dart
await tester.pumpWidget(
  MaterialApp(
    home: ScreenToTest(),
    routes: {
      '/next-screen': (context) => NextScreen(),
    },
  ),
);
```

### 5. Platform-Specific Features
**Affected Features:**
- QR code scanning (camera access)
- Image picker
- Location services
- Platform.isWeb checks

**Failure Symptoms:**
```dart
MissingPluginException
Platform channel not available
Camera permission denied
```

**Resolution:**
Mock platform-specific plugins:

```dart
// Mock QR scanner result
when(mockQrScanner.scan()).thenAnswer(
  (_) async => 'mocked_qr_data'
);

// Mock platform check
TestWidgetsFlutterBinding.ensureInitialized();
```

### 6. Async Operation Failures
**Affected Operations:**
- Future builders
- Stream builders
- API responses
- Database queries

**Failure Symptoms:**
```dart
Test failed: Expected one widget, found none
CircularProgressIndicator still visible
```

**Resolution:**
Use proper async handling:

```dart
// Wait for async operations
await tester.pumpAndSettle();

// For specific durations
await tester.pump(Duration(seconds: 2));

// For streams
await tester.pumpAndSettle(
  Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
);
```

## Test Structure Best Practices

### Widget Test Template
```dart
void main() {
  group('WidgetName Tests', () {
    setUp(() async {
      // Initialize mocks
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WidgetToTest()),
      );
      
      // Verify initial state
      expect(find.text('Expected Text'), findsOneWidget);
    });

    testWidgets('should handle user interaction', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: WidgetToTest()),
      );
      
      // Perform action
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      
      // Verify result
      expect(find.text('Result'), findsOneWidget);
    });
  });
}
```

## Platform-Specific Test Issues

### Web Platform Tests
- File upload widgets behave differently
- Camera/QR scanner unavailable
- Different navigation behavior

### Mobile Platform Tests
- Permission dialogs may appear
- Platform channels must be mocked
- Device-specific features need stubs

## Test Execution

### Running All Tests
```bash
flutter test
```

### Running Specific Test File
```bash
flutter test test/widget/user/user_login_screen_test.dart
```

### Running with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Coverage Metrics

### Current Coverage by Feature
| Feature | Files | Coverage | Target |
|---------|-------|----------|--------|
| User Authentication | 5 | 85% | 80% |
| Payment System | 3 | 78% | 80% |
| Parking Maps | 4 | 72% | 70% |
| Operator Dashboard | 3 | 65% | 70% |
| QR Scanner | 2 | 60% | 60% |
| Carbon Emissions | 2 | 55% | 60% |

## Known Limitations

### Cannot Test
1. Actual camera functionality
2. Real GPS location updates
3. Native platform dialogs
4. Push notifications
5. Background services

### Partial Testing
1. Complex animations (simplified)
2. WebSocket connections (mocked)
3. File system operations (mocked)
4. Device sensors (stubbed)

## Troubleshooting Guide

### Problem: Tests pass locally but fail in CI
**Solution:** Check for timezone differences, locale settings, or missing mock data

### Problem: Flaky tests (intermittent failures)
**Solution:** Add explicit waits, increase timeout durations, ensure proper mock setup

### Problem: Widget not found errors
**Solution:** Use `pumpAndSettle()` or add key properties to widgets

### Problem: Test hangs indefinitely
**Solution:** Check for infinite loops, unresolved futures, or missing stream closes

## Test Helpers Location

Test helper files are located in `test/helpers/`:
- `test_app.dart` - TestMyApp without SplashScreen
- `test_wallet_screen.dart` - WalletScreen without API calls
- `mock_data.dart` - Common test data
- `test_utils.dart` - Utility functions for tests

## Continuous Improvement

### Adding New Tests
1. Check existing test patterns
2. Use appropriate test helpers
3. Mock all external dependencies
4. Test both success and failure paths
5. Document any special requirements

### Maintaining Tests
- Update mocks when UI changes
- Keep test data realistic
- Review flaky tests regularly
- Monitor coverage trends