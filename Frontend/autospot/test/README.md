# Frontend Testing Strategy

## Testing Framework: Flutter Test

AutoSpot frontend uses Flutter's built-in testing framework to ensure UI reliability, correct user interactions, and proper state management.

## Coverage Reporting

### Current Coverage
Coverage reports are automatically generated in CI/CD pipeline and displayed in:
- Pull Request comments
- GitHub Actions artifacts
- Local HTML reports in `coverage/html/`

### Generate Coverage Locally

#### Linux/Mac
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# View HTML report
open coverage/html/index.html      # Mac
xdg-open coverage/html/index.html  # Linux
```

#### Windows PowerShell
```powershell
# Run tests with coverage
flutter test --coverage

# View coverage summary (if batch file exists)
.\coverage_summary.bat

# View HTML report (if batch file exists)
.\view_coverage.bat

# Or directly open the HTML report
start coverage/html/index.html

# Note: genhtml needs to be installed separately on Windows
# Alternative: Use lcov-viewer or other coverage visualization tools
```

#### WSL (Windows Subsystem for Linux)
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# View HTML report
xdg-open coverage/html/index.html
```

## Test Categories

### 1. Widget Tests 🎨
**Location**: `test/widget/`
- **Purpose**: Test individual UI components
- **Coverage**: 
  - Component rendering
  - User interactions (taps, swipes, input)
  - State changes
  - Navigation flows

#### User Screens
- Login/Registration screens
- Dashboard and profile screens
- Parking selection and payment screens
- QR code scanning and generation
- Wallet and transaction management
- Carbon emission tracking

#### Operator Screens
- Operator dashboard
- Parking lot management
- Fee configuration
- Map upload functionality

### 2. Unit Tests 🔧
**Location**: `test/unit/`
- **Purpose**: Test business logic and utilities
- **Coverage**:
  - Service classes (auth, parking, wallet)
  - Data models and parsing
  - Utility functions
  - API configuration

### 3. Integration Tests 🔄
**Location**: `test/integration/` (if needed)
- **Purpose**: Test complete user flows
- **Coverage**:
  - End-to-end scenarios
  - Multi-screen workflows
  - API integration (mocked)

## Mocking Strategy

### API Calls
- **Tool**: `http.MockClient`
- **Approach**: All network requests mocked with predefined responses
- **Benefits**: No dependency on backend, deterministic results

### SharedPreferences
- **Tool**: `SharedPreferences.setMockInitialValues`
- **Approach**: Mock local storage for user preferences and session data
- **Benefits**: Consistent test environment

### Navigation
- **Tool**: Custom test helpers
- **Approach**: Mock navigation to test screen transitions
- **Benefits**: Isolated widget testing

### Platform-Specific Features
- **QR Scanner**: Mocked for both mobile and web platforms
- **Camera**: Mocked image capture responses
- **Location Services**: Mocked GPS coordinates

## Test Structure

### Widget Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ScreenName Tests', () {
    setUp(() async {
      // Setup mock data
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
      });
    });

    testWidgets('should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ScreenName()),
      );
      
      expect(find.text('Expected Text'), findsOneWidget);
    });

    testWidgets('should handle user interaction', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ScreenName()),
      );
      
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      
      expect(find.text('Result'), findsOneWidget);
    });
  });
}
```

## Test Files Organization

### User Features
- `user_login_screen_test.dart` - Authentication flow
- `user_dashboard_screen_test.dart` - Main user interface
- `user_payment_screen_test.dart` - Payment processing
- `user_wallet_screen_test.dart` - Wallet management
- `user_qr_scanner_screen_test.dart` - QR code scanning
- `user_carbon_emission_screen_test.dart` - Emission tracking

### Operator Features
- `operator_dashboard_screen_test.dart` - Operator main interface
- `operator_edit_parking_fee_test.dart` - Fee management
- `operator_upload_map_screen_test.dart` - Map management

### Shared Components
- `render_map_test.dart` - Parking map rendering
- `legend_test.dart` - Map legend component

## Test Coverage Requirements

### Component Behavior ✅
- Widget initialization and disposal
- State management and updates
- Props and configuration handling
- Lifecycle methods

### User Interactions 👆
- Button clicks and form submissions
- Text input and validation
- Navigation and routing
- Gesture recognition

### Rendering Logic 🖼️
- Conditional rendering based on state
- List and grid rendering
- Error state display
- Loading indicators
- Responsive layout

## Running Tests

### All Platforms (Linux/Mac/Windows/WSL)
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget/user/user_login_screen_test.dart

# Run with coverage
flutter test --coverage

# Watch mode (during development)
flutter test --watch
```

### View Coverage Reports

#### Linux/Mac
```bash
# Generate and open HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html      # Mac
xdg-open coverage/html/index.html  # Linux
```

#### Windows PowerShell
```powershell
# Open HTML report (if already generated)
start coverage/html/index.html

# Note: genhtml is not available by default on Windows
# Consider using online lcov viewers or VS Code extensions
```

## CI/CD Integration

Tests run automatically on:
- Every push to main/develop branches
- All pull requests
- Coverage reports generated and displayed
- HTML coverage artifacts uploaded

## Best Practices

### Do's ✅
- Write tests for every new feature
- Test both success and error scenarios
- Mock all external dependencies
- Keep tests independent and isolated
- Use descriptive test names
- Group related tests together

### Don'ts ❌
- Don't test Flutter framework functionality
- Don't make real API calls in tests
- Don't rely on test execution order
- Don't use hard-coded delays (use `pumpAndSettle`)
- Don't skip error case testing

## Known Issues

### Platform-Specific Tests
- QR scanner tests require platform-specific mocking
- Some tests may behave differently on web vs mobile

### Async Operations
- Use `tester.pumpAndSettle()` for animations
- Mock timers for time-dependent operations

## Contributing

When adding new UI features:
1. Create corresponding test file
2. Cover happy path first
3. Add error scenarios
4. Test edge cases
5. Ensure no decrease in coverage
6. Run tests locally before pushing

## Test Metrics

- **Total Test Files**: 40+
- **Widget Tests**: 35+
- **Unit Tests**: 10+
- **Average Execution Time**: ~2 minutes
- **Current Coverage**: 70%
- **Target Coverage**: 70% - Achieved

## Test Documentation

For comprehensive test failure explanations and mocking strategies:
- [Test Failures Documentation](./test_failures.md) - Common Flutter test failures and resolutions
- [Testing Guide](../../../docs/TESTING_GUIDE.md) - Complete testing strategy
- [Mocking Strategy](../../../docs/MOCKING_STRATEGY.md) - Detailed mocking patterns

## Future Improvements

1. [ ] Add golden tests for visual regression
2. [ ] Implement integration tests for critical flows
3. [ ] Add performance testing for list rendering
4. [ ] Create test data factories
5. [ ] Add accessibility testing