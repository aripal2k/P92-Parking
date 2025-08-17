# Mocking Strategy for AutoSpot Testing

## Overview
This document details the mocking strategies used throughout the AutoSpot application to ensure reliable, fast, and isolated testing without external dependencies.

## Why Mock?

### Benefits
1. **Isolation**: Tests run independently of external services
2. **Speed**: No network latency or database queries
3. **Reliability**: Consistent results every time
4. **Cost**: No API usage charges
5. **Safety**: No risk of modifying production data
6. **Control**: Simulate any scenario including errors

## Backend Mocking (Python/FastAPI)

### MongoDB Mocking

#### Strategy
All MongoDB operations are mocked using `unittest.mock.patch` to simulate database responses without requiring a running MongoDB instance.

#### Implementation
```python
from unittest.mock import patch, MagicMock
from bson import ObjectId

@patch("app.auth.router.users_collection")
def test_user_operations(mock_collection):
    # Mock find_one operation
    mock_collection.find_one.return_value = {
        "_id": ObjectId(),
        "email": "user@example.com",
        "username": "testuser",
        "password": "hashed_password"
    }
    
    # Mock insert_one operation
    mock_collection.insert_one.return_value.inserted_id = ObjectId()
    
    # Mock update_one operation
    mock_collection.update_one.return_value.modified_count = 1
    
    # Mock delete_one operation
    mock_collection.delete_one.return_value.deleted_count = 1
    
    # Mock find with cursor
    mock_cursor = MagicMock()
    mock_collection.find.return_value = mock_cursor
    mock_cursor.limit.return_value = [{"_id": ObjectId()}]
```

#### Common Patterns
```python
# Mock aggregation pipeline
mock_collection.aggregate.return_value = [
    {"total": 100, "average": 25}
]

# Mock bulk operations
mock_collection.bulk_write.return_value.modified_count = 5

# Mock index creation
mock_collection.create_index.return_value = "index_name"
```

### Redis Cache Mocking

#### Strategy
Redis operations are mocked to simulate caching without requiring a Redis server.

#### Implementation
```python
@patch("app.cache.redis.Redis")
def test_cache_operations(mock_redis_class):
    mock_redis = MagicMock()
    mock_redis_class.return_value = mock_redis
    
    # Mock get operation
    mock_redis.get.return_value = b'{"cached": "data"}'
    
    # Mock set operation
    mock_redis.setex.return_value = True
    
    # Mock delete operation
    mock_redis.delete.return_value = 1
    
    # Mock pipeline operations
    mock_pipeline = MagicMock()
    mock_redis.pipeline.return_value = mock_pipeline
    mock_pipeline.execute.return_value = [True, True]
```

#### TTL and Expiration
```python
# Mock with TTL
mock_redis.ttl.return_value = 3600  # 1 hour

# Mock expired key
mock_redis.get.return_value = None  # Key doesn't exist

# Mock key existence
mock_redis.exists.return_value = 1  # Key exists
```

### External API Mocking

#### OpenAI GPT-4 Vision
```python
@patch("openai.ChatCompletion.create")
def test_gpt4_vision(mock_create):
    mock_create.return_value = {
        "id": "chatcmpl-123",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": json.dumps({
                    "parking_slots": [
                        {"id": "A1", "x": 10, "y": 20, "status": "available"},
                        {"id": "A2", "x": 30, "y": 20, "status": "occupied"}
                    ],
                    "entrances": [{"id": "E1", "x": 0, "y": 10}],
                    "exits": [{"id": "X1", "x": 100, "y": 10}]
                })
            },
            "finish_reason": "stop"
        }],
        "usage": {
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "total_tokens": 150
        }
    }
```

#### Email Service
```python
@patch("smtplib.SMTP")
def test_email_sending(mock_smtp_class):
    mock_smtp = MagicMock()
    mock_smtp_class.return_value.__enter__.return_value = mock_smtp
    
    # Mock successful send
    mock_smtp.send_message.return_value = {}
    
    # Mock email failure
    mock_smtp.send_message.side_effect = Exception("SMTP error")
```

#### AWS CloudWatch
```python
@patch("boto3.client")
def test_cloudwatch_metrics(mock_boto_client):
    mock_cloudwatch = MagicMock()
    mock_boto_client.return_value = mock_cloudwatch
    
    # Mock put_metric_data
    mock_cloudwatch.put_metric_data.return_value = {
        'ResponseMetadata': {'HTTPStatusCode': 200}
    }
```

### Time and Date Mocking

#### Using freezegun
```python
from freezegun import freeze_time

@freeze_time("2024-01-01 12:00:00")
def test_time_dependent():
    # All datetime.now() calls return frozen time
    from datetime import datetime
    assert datetime.now().hour == 12
    
    # Move time forward
    with freeze_time("2024-01-01 13:00:00"):
        assert datetime.now().hour == 13
```

#### Mock datetime directly
```python
from unittest.mock import patch
from datetime import datetime

@patch("app.session.router.datetime")
def test_session_timing(mock_datetime):
    mock_datetime.now.return_value = datetime(2024, 1, 1, 12, 0, 0)
    mock_datetime.side_effect = lambda *args, **kw: datetime(*args, **kw)
```

### File System Mocking

```python
from unittest.mock import mock_open, patch

@patch("builtins.open", new_callable=mock_open, read_data="file content")
def test_file_operations(mock_file):
    # Test file reading
    with open("test.txt", "r") as f:
        content = f.read()
    assert content == "file content"
    
    # Test file writing
    with open("output.txt", "w") as f:
        f.write("new content")
    mock_file().write.assert_called_with("new content")
```

## Frontend Mocking (Flutter/Dart)

### SharedPreferences Mocking

#### Setup
```dart
import 'package:shared_preferences/shared_preferences.dart';

setUp(() async {
  // Initialize with mock values
  SharedPreferences.setMockInitialValues({
    'user_email': 'test@example.com',
    'session_id': 'session_123',
    'wallet_balance': '150.00',
    'selected_destination': 'Building A',
    'parking_start_time': '2024-01-01T12:00:00',
  });
});
```

#### Dynamic Updates
```dart
test('should update preferences', () async {
  final prefs = await SharedPreferences.getInstance();
  
  // Read value
  expect(prefs.getString('user_email'), 'test@example.com');
  
  // Update value
  await prefs.setString('user_email', 'new@example.com');
  expect(prefs.getString('user_email'), 'new@example.com');
  
  // Remove value
  await prefs.remove('session_id');
  expect(prefs.getString('session_id'), isNull);
});
```

### HTTP Client Mocking

#### Using mockito
```dart
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockClient extends Mock implements http.Client {}

test('should fetch data', () async {
  final client = MockClient();
  
  // Mock successful response
  when(client.get(Uri.parse('https://api.example.com/data')))
    .thenAnswer((_) async => http.Response(
      '{"status": "success", "data": [1, 2, 3]}',
      200,
    ));
  
  // Mock error response
  when(client.post(
    Uri.parse('https://api.example.com/login'),
    body: anyNamed('body'),
    headers: anyNamed('headers'),
  )).thenAnswer((_) async => http.Response(
    '{"error": "Invalid credentials"}',
    401,
  ));
});
```

#### Using dio
```dart
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';

class MockDio extends Mock implements Dio {}

test('should handle dio requests', () async {
  final dio = MockDio();
  
  when(dio.get('/user')).thenAnswer(
    (_) async => Response(
      data: {'name': 'Test User'},
      statusCode: 200,
      requestOptions: RequestOptions(path: '/user'),
    ),
  );
});
```

### Platform Channel Mocking

#### Camera/Image Picker
```dart
import 'package:flutter_test/flutter_test.dart';

setUpAll(() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock camera channel
  const MethodChannel channel = MethodChannel('plugins.flutter.io/camera');
  channel.setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'availableCameras') {
      return [
        {'name': 'Camera 0', 'lensFacing': 'back'},
        {'name': 'Camera 1', 'lensFacing': 'front'},
      ];
    }
    return null;
  });
});
```

#### QR Code Scanner
```dart
class MockQRScanner {
  Future<String?> scan() async {
    // Return mock QR data
    return 'ENTRANCE:E1:BUILDING:A';
  }
  
  Future<String?> scanWithError() async {
    throw Exception('Camera permission denied');
  }
}
```

### Navigation Mocking

```dart
import 'package:mocktail/mocktail.dart';

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

testWidgets('should navigate correctly', (tester) async {
  final mockObserver = MockNavigatorObserver();
  
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(),
      navigatorObservers: [mockObserver],
      routes: {
        '/dashboard': (_) => DashboardScreen(),
      },
    ),
  );
  
  // Trigger navigation
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Verify navigation was called
  verify(() => mockObserver.didPush(any(), any())).called(1);
});
```

### Timer and Animation Mocking

```dart
testWidgets('should handle timers', (tester) async {
  await tester.pumpWidget(MyTimerWidget());
  
  // Fast-forward time
  await tester.pump(Duration(seconds: 5));
  
  // Complete all animations
  await tester.pumpAndSettle();
  
  // Use fake async
  await tester.runAsync(() async {
    // Code that uses real async operations
    await Future.delayed(Duration(seconds: 1));
  });
});
```

## Advanced Mocking Patterns

### Partial Mocking
```python
# Python - Mock only specific methods
with patch.object(ParkingManager, 'calculate_fare', return_value=25.0):
    manager = ParkingManager()
    # Other methods work normally, only calculate_fare is mocked
```

```dart
// Dart - Partial mocking with spy
class SpyService extends Service {
  final Service _real;
  SpyService(this._real);
  
  @override
  Future<Data> getData() {
    // Can intercept and modify behavior
    return _real.getData();
  }
}
```

### Conditional Mocking
```python
# Python - Different responses based on input
def side_effect_function(email):
    if email == "admin@example.com":
        return {"role": "admin"}
    elif email == "user@example.com":
        return {"role": "user"}
    else:
        return None

mock_collection.find_one.side_effect = side_effect_function
```

```dart
// Dart - Conditional responses
when(mockClient.get(any)).thenAnswer((invocation) {
  final url = invocation.positionalArguments[0] as Uri;
  if (url.path.contains('user')) {
    return http.Response('{"type": "user"}', 200);
  } else {
    return http.Response('{"type": "other"}', 200);
  }
});
```

### Sequential Mocking
```python
# Python - Different responses on each call
mock_func.side_effect = [
    ValueError("First call fails"),
    {"success": True},  # Second call succeeds
    {"success": True},  # Third call succeeds
]
```

```dart
// Dart - Sequential responses
var callCount = 0;
when(mockService.getData()).thenAnswer((_) {
  callCount++;
  if (callCount == 1) {
    throw Exception('First call fails');
  }
  return 'Success';
});
```

## Mock Data Generators

### Backend Test Data
```python
# factories.py
from faker import Faker
from datetime import datetime, timedelta

fake = Faker()

class TestDataFactory:
    @staticmethod
    def create_user():
        return {
            "email": fake.email(),
            "username": fake.user_name(),
            "full_name": fake.name(),
            "created_at": datetime.now()
        }
    
    @staticmethod
    def create_parking_session():
        start = datetime.now() - timedelta(hours=2)
        return {
            "session_id": fake.uuid4(),
            "user_email": fake.email(),
            "slot_id": f"{fake.random_letter()}{fake.random_number(2)}",
            "start_time": start,
            "end_time": start + timedelta(hours=1),
            "fare": fake.random_number(2)
        }
```

### Frontend Test Data
```dart
// test_data_factory.dart
import 'package:faker/faker.dart';

class TestDataFactory {
  static final faker = Faker();
  
  static Map<String, dynamic> createUser() {
    return {
      'email': faker.internet.email(),
      'username': faker.internet.userName(),
      'full_name': faker.person.name(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  static List<Map<String, dynamic>> createParkingSlots(int count) {
    return List.generate(count, (index) => {
      'slot_id': '${faker.randomGenerator.string(1, min: 65, max: 90)}$index',
      'status': faker.randomGenerator.element(['available', 'occupied', 'reserved']),
      'x': faker.randomGenerator.integer(100),
      'y': faker.randomGenerator.integer(100),
    });
  }
}
```

## Mock Verification

### Backend Assertions
```python
# Verify mock was called
mock_collection.find_one.assert_called_once()
mock_collection.find_one.assert_called_with({"email": "test@example.com"})

# Verify call count
assert mock_collection.update_one.call_count == 2

# Verify not called
mock_collection.delete_one.assert_not_called()

# Verify any call with partial match
mock_collection.insert_one.assert_called()
args, kwargs = mock_collection.insert_one.call_args
assert "email" in args[0]
```

### Frontend Assertions
```dart
// Verify mock was called
verify(() => mockClient.get(any)).called(1);

// Verify with specific arguments
verify(() => mockClient.post(
  Uri.parse('https://api.example.com/login'),
  body: {'email': 'test@example.com'},
)).called(1);

// Verify never called
verifyNever(() => mockClient.delete(any));

// Capture arguments
final captured = verify(() => mockService.process(captureAny)).captured;
expect(captured.first, 'expected_value');
```

## Testing Error Scenarios

### Backend Error Simulation
```python
# Simulate database connection error
mock_collection.find_one.side_effect = ConnectionError("Database unavailable")

# Simulate timeout
mock_collection.find_one.side_effect = TimeoutError("Query timeout")

# Simulate validation error
mock_collection.insert_one.side_effect = ValueError("Invalid document")
```

### Frontend Error Simulation
```dart
// Simulate network error
when(mockClient.get(any)).thenThrow(
  SocketException('No internet connection'),
);

// Simulate timeout
when(mockClient.get(any)).thenAnswer(
  (_) async => Future.delayed(
    Duration(seconds: 30),
    () => throw TimeoutException('Request timeout'),
  ),
);

// Simulate parse error
when(mockClient.get(any)).thenAnswer(
  (_) async => http.Response('Invalid JSON', 200),
);
```

## Best Practices

### Do's
1. **Mock at boundaries**: Mock external dependencies, not internal logic
2. **Keep mocks simple**: Don't overcomplicate mock behavior
3. **Use realistic data**: Mock data should resemble production data
4. **Mock errors too**: Test error handling paths
5. **Verify interactions**: Check that mocks were called correctly
6. **Document complex mocks**: Explain non-obvious mock behavior
7. **Reuse mock setups**: Create helper functions for common mocks

### Don'ts
1. **Don't mock everything**: Some integration is valuable
2. **Don't mock types you don't own**: Wrap external libraries instead
3. **Don't share mock state**: Each test should set up its own mocks
4. **Don't ignore mock warnings**: Address or suppress intentionally
5. **Don't mock simple objects**: Use real objects when possible
6. **Don't forget to reset**: Clean up mocks between tests

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Mock not working | Check patch path matches actual import |
| Mock called but test fails | Verify return value and side effects |
| Unexpected mock behavior | Check for multiple patches on same target |
| Mock verification fails | Use print/debug to see actual calls |
| Performance issues | Reduce mock complexity, use simpler returns |

### Debug Techniques

```python
# Python - Print all mock calls
print(mock_object.mock_calls)
print(mock_object.call_args_list)

# See mock configuration
print(dir(mock_object))
print(mock_object._mock_methods)
```

```dart
// Dart - Debug mock interactions
mockClient.calls.forEach((call) {
  print('Method: ${call.method}');
  print('Arguments: ${call.positionalArguments}');
});
```

## Resources

### Libraries
- **Python**: unittest.mock, pytest-mock, responses, freezegun
- **Dart**: mockito, mocktail, faker, shared_preferences (test mode)

### Documentation
- [Python Mock Documentation](https://docs.python.org/3/library/unittest.mock.html)
- [Mockito for Dart](https://pub.dev/packages/mockito)
- [Flutter Testing Cookbook](https://flutter.dev/docs/cookbook/testing)

### Tools
- Mock generators for complex objects
- API response recorders
- Mock servers for integration testing