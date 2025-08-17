# Comprehensive Testing Guide for AutoSpot

## Overview
This guide provides comprehensive testing strategies for the AutoSpot parking management system, covering both backend (FastAPI) and frontend (Flutter) components.

## Testing Philosophy

### Core Principles
1. **Test in Isolation**: Each test should be independent
2. **Mock External Dependencies**: No real database, API, or service calls
3. **Deterministic Results**: Tests should produce consistent results
4. **Fast Execution**: Tests should complete quickly
5. **Comprehensive Coverage**: Aim for >70% code coverage

## Backend Testing (Python/FastAPI)

### Test Structure
```
Backend/tests/
├── conftest.py              # Shared fixtures and configuration
├── test_auth_*.py          # Authentication tests
├── test_admin_*.py         # Admin functionality tests
├── test_parking_*.py       # Parking management tests
├── test_session_*.py       # Session management tests
├── test_wallet.py          # Payment system tests
├── test_emissions_*.py     # Carbon emission tests
├── test_pathfinding.py     # Route calculation tests
├── test_cache.py           # Redis cache tests
└── test_qrcode.py          # QR code generation tests
```

### Running Backend Tests

#### Basic Commands
```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=term-missing

# Run specific test file
pytest tests/test_auth_login.py

# Run specific test function
pytest tests/test_auth_login.py::TestUserLogin::test_login_success

# Run tests matching pattern
pytest -k "login"

# Run with verbose output
pytest -v

# Run with minimal output
pytest -q
```

#### Coverage Reports
```bash
# Terminal report
pytest --cov=app --cov-report=term

# HTML report
pytest --cov=app --cov-report=html
# View at: htmlcov/index.html

# XML report (for CI)
pytest --cov=app --cov-report=xml

# JSON report
pytest --cov=app --cov-report=json
```

### Backend Testing Patterns

#### 1. Database Mocking
```python
from unittest.mock import patch, MagicMock

@patch("app.auth.router.users_collection")
def test_user_login(mock_collection):
    # Mock MongoDB response
    mock_collection.find_one.return_value = {
        "email": "test@example.com",
        "password": "hashed_password",
        "failed_attempts": 0
    }
    
    # Test logic here
    response = client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "password123"
    })
    
    assert response.status_code == 200
```

#### 2. Redis Cache Mocking
```python
@patch("app.cache.redis.Redis")
def test_cache_operation(mock_redis):
    mock_instance = MagicMock()
    mock_redis.return_value = mock_instance
    
    # Mock cache get
    mock_instance.get.return_value = b'{"key": "value"}'
    
    # Mock cache set
    mock_instance.setex.return_value = True
```

#### 3. External API Mocking
```python
@patch("app.parking.router.openai.ChatCompletion.create")
def test_gpt4_vision(mock_openai):
    mock_openai.return_value = {
        "choices": [{
            "message": {
                "content": '{"analysis": "parking_map_data"}'
            }
        }]
    }
```

#### 4. Time-based Testing
```python
from freezegun import freeze_time

@freeze_time("2024-01-01 12:00:00")
def test_time_dependent_operation():
    # All datetime.now() calls return frozen time
    result = calculate_parking_duration()
    assert result == expected_duration
```

### Backend Test Categories

#### Unit Tests
- Test individual functions and methods
- Mock all dependencies
- Focus on business logic

#### Integration Tests
- Test API endpoints
- Mock external services (DB, cache, APIs)
- Verify request/response flow

#### Edge Case Tests
- Boundary values
- Invalid inputs
- Error conditions
- Concurrent operations

## Frontend Testing (Flutter)

### Test Structure
```
Frontend/autospot/test/
├── helpers/
│   ├── test_app.dart       # App without splash screen
│   ├── test_utils.dart     # Common test utilities
│   └── mock_data.dart      # Test data fixtures
├── widget/
│   ├── user/               # User screen tests
│   ├── operator/           # Operator screen tests
│   └── shared/             # Shared component tests
└── unit/                   # Business logic tests
```

### Running Frontend Tests

#### Basic Commands
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget/user/user_login_screen_test.dart

# Run with coverage
flutter test --coverage

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html

# Run in watch mode
flutter test --watch

# Run with specific platform
flutter test --platform chrome
```

### Frontend Testing Patterns

#### 1. Widget Testing
```dart
testWidgets('should display login form', (WidgetTester tester) async {
  // Build widget
  await tester.pumpWidget(
    MaterialApp(
      home: UserLoginScreen(),
    ),
  );
  
  // Verify UI elements
  expect(find.text('Login'), findsOneWidget);
  expect(find.byType(TextField), findsNWidgets(2));
  expect(find.byType(ElevatedButton), findsOneWidget);
  
  // Interact with widget
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Verify result
  expect(find.text('Welcome'), findsOneWidget);
});
```

#### 2. Mock SharedPreferences
```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({
    'user_email': 'test@example.com',
    'session_id': 'test_session_123',
    'wallet_balance': '100.00',
  });
});
```

#### 3. Mock HTTP Calls
```dart
class MockClient extends Mock implements http.Client {}

test('should fetch user data', () async {
  final client = MockClient();
  
  when(client.get(Uri.parse('https://api.example.com/user')))
    .thenAnswer((_) async => http.Response('{"name": "Test User"}', 200));
  
  final result = await fetchUser(client);
  expect(result.name, 'Test User');
});
```

#### 4. Navigation Testing
```dart
testWidgets('should navigate to dashboard', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(),
      routes: {
        '/dashboard': (context) => DashboardScreen(),
      },
    ),
  );
  
  // Trigger navigation
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
  
  // Verify navigation
  expect(find.byType(DashboardScreen), findsOneWidget);
});
```

## Test Data Management

### Backend Test Fixtures
```python
# conftest.py
import pytest

@pytest.fixture
def sample_user():
    return {
        "email": "test@example.com",
        "username": "testuser",
        "full_name": "Test User",
        "password": "hashed_password"
    }

@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test_token"}
```

### Frontend Test Data
```dart
// test/helpers/mock_data.dart
class MockData {
  static Map<String, dynamic> get user => {
    'email': 'test@example.com',
    'username': 'testuser',
    'full_name': 'Test User',
  };
  
  static List<Map<String, dynamic>> get parkingSlots => [
    {'id': 'A1', 'status': 'available'},
    {'id': 'A2', 'status': 'occupied'},
  ];
}
```

## Continuous Integration Testing

### GitHub Actions Workflow
```yaml
name: Tests

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      - run: |
          cd Backend
          pip install -r requirements.txt
          pytest --cov=app --cov-report=xml
      
  frontend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: |
          cd Frontend/autospot
          flutter test --coverage
```

## Testing Best Practices

### Do's
1. Write tests before or alongside code (TDD/BDD)
2. Keep tests simple and focused
3. Use descriptive test names
4. Test both success and failure paths
5. Mock all external dependencies
6. Use fixtures for common test data
7. Run tests locally before pushing
8. Maintain test coverage above 70%

### Don'ts
1. Don't test framework functionality
2. Don't make real API/database calls
3. Don't use hard-coded delays
4. Don't share state between tests
5. Don't ignore flaky tests
6. Don't test implementation details
7. Don't duplicate test logic

## Test Coverage Goals

### Backend Coverage Targets
| Module | Target | Priority |
|--------|--------|----------|
| Authentication | 90% | Critical |
| Payment/Wallet | 85% | Critical |
| Session Management | 80% | High |
| Parking Operations | 75% | High |
| Admin Functions | 75% | Medium |
| Utilities | 70% | Low |

### Frontend Coverage Targets
| Component | Target | Priority |
|-----------|--------|----------|
| User Screens | 80% | Critical |
| Payment Flow | 85% | Critical |
| Navigation | 75% | High |
| Forms/Validation | 80% | High |
| Operator Screens | 70% | Medium |
| Utilities | 65% | Low |

## Debugging Tests

### Backend Debugging
```bash
# Run with debugger
pytest --pdb

# Stop on first failure
pytest -x

# Show local variables on failure
pytest -l

# Show print statements
pytest -s

# Verbose traceback
pytest --tb=long
```

### Frontend Debugging
```dart
// Add debug output
debugPrint('Current state: $state');

// Use flutter inspector
flutter test --track-widget-creation

// Add breakpoints in IDE
// VS Code: Click left of line number
// Android Studio: Click left of line number
```

## Performance Testing

### Backend Load Testing
```python
import pytest
import asyncio
from concurrent.futures import ThreadPoolExecutor

@pytest.mark.performance
def test_concurrent_requests():
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [
            executor.submit(make_request) 
            for _ in range(100)
        ]
        results = [f.result() for f in futures]
        
    assert all(r.status_code == 200 for r in results)
```

### Frontend Performance Testing
```dart
testWidgets('should render large list efficiently', (tester) async {
  final items = List.generate(1000, (i) => 'Item $i');
  
  await tester.pumpWidget(
    MaterialApp(
      home: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => Text(items[index]),
      ),
    ),
  );
  
  // Measure frame rendering time
  final renderTime = tester.binding.window.onReportTimings;
  expect(renderTime, lessThan(Duration(milliseconds: 16)));
});
```

## Test Maintenance

### Regular Tasks
1. Review and update failing tests weekly
2. Remove obsolete tests
3. Refactor duplicate test code
4. Update mocks when APIs change
5. Monitor coverage trends
6. Optimize slow tests
7. Document complex test scenarios

### Test Review Checklist
- [ ] Test covers the requirement
- [ ] Test is independent
- [ ] Test is deterministic
- [ ] Test has clear assertions
- [ ] Test follows naming conventions
- [ ] Test includes edge cases
- [ ] Test runs quickly
- [ ] Test is properly documented

## Troubleshooting Common Issues

### Backend Issues
| Issue | Solution |
|-------|----------|
| Import errors | Check PYTHONPATH and __init__.py files |
| Fixture not found | Ensure conftest.py is in test directory |
| Mock not working | Verify patch path matches import |
| Async test fails | Use pytest-asyncio and async fixtures |

### Frontend Issues
| Issue | Solution |
|-------|----------|
| Widget not found | Use pumpAndSettle() after actions |
| Timer pending | Use test helpers to skip timers |
| Navigation fails | Define routes in MaterialApp |
| Platform errors | Mock platform-specific features |

## Resources

### Documentation
- [Pytest Documentation](https://docs.pytest.org/)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [FastAPI Testing](https://fastapi.tiangolo.com/tutorial/testing/)

### Tools
- Coverage.py - Python coverage tool
- lcov - Flutter coverage visualization
- pytest-cov - Pytest coverage plugin
- mockito - Dart mocking framework

### Learning Resources
- Test-Driven Development (TDD)
- Behavior-Driven Development (BDD)
- Property-based Testing
- Mutation Testing