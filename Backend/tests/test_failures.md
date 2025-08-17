# Backend Test Failures Documentation

## Overview
This document explains test failures that occur due to external dependencies and infrastructure requirements. These failures are expected when the testing environment lacks certain services or configurations.

## External Dependency Failures

### 1. MongoDB Connection Failures
**Affected Modules:**
- All authentication tests (`test_auth_*.py`)
- Admin tests (`test_admin_*.py`)
- Session management (`test_session*.py`)
- Parking storage (`test_parking_storage.py`)
- Emissions storage (`test_emissions_storage.py`)

**Failure Symptoms:**
```python
pymongo.errors.ServerSelectionTimeoutError: localhost:27017: [Errno 111] Connection refused
```

**Resolution:**
- Tests use mocked MongoDB connections via `unittest.mock`
- All database operations are fully mocked
- No actual MongoDB instance required for tests to pass

**Mocking Strategy:**
```python
@patch("app.auth.router.users_collection")
def test_function(mock_collection):
    mock_collection.find_one.return_value = {"email": "test@example.com"}
```

### 2. Redis Cache Failures
**Affected Modules:**
- `test_cache.py` - All cache operations
- Session management (when caching enabled)
- Rate limiting tests

**Failure Symptoms:**
```python
redis.exceptions.ConnectionError: Error 111 connecting to localhost:6379. Connection refused.
```

**Resolution:**
- Cache operations fully mocked with `@patch("app.cache.redis.Redis")`
- Mock client simulates all Redis operations
- Tests pass without Redis server

**Mocking Strategy:**
```python
@patch("app.cache.redis.Redis")
def test_cache_operation(mock_redis):
    mock_instance = MagicMock()
    mock_redis.return_value = mock_instance
    mock_instance.get.return_value = b'{"key": "value"}'
```

### 3. Email Service Failures
**Affected Modules:**
- User registration (`test_auth_registration.py`)
- Password reset (`test_auth_password.py`)

**Failure Symptoms:**
- SMTP connection errors
- Email sending timeouts

**Resolution:**
- Email sending completely mocked
- No actual emails sent during tests

**Mocking Strategy:**
```python
@patch("app.auth.router.send_email")
def test_registration(mock_send_email):
    mock_send_email.return_value = True
```

### 4. GPT-4 Vision API Failures
**Affected Modules:**
- Parking map upload (`test_parking_router.py`)
- Image analysis tests

**Failure Symptoms:**
- OpenAI API key errors
- Rate limiting errors
- Network timeouts

**Resolution:**
- GPT-4 responses fully mocked
- Predefined analysis results used
- No API calls made during tests

**Mocking Strategy:**
```python
@patch("app.parking.router.openai.ChatCompletion.create")
def test_upload_map(mock_openai):
    mock_openai.return_value = {
        "choices": [{
            "message": {"content": '{"slots": [...]}'}
        }]
    }
```

### 5. CloudWatch Metrics Failures
**Affected Modules:**
- All routers with metrics recording
- Performance monitoring tests

**Failure Symptoms:**
- AWS credentials errors
- CloudWatch connection failures

**Resolution:**
- Metrics recording mocked
- No actual metrics sent to AWS

**Mocking Strategy:**
```python
@patch("app.middleware.metrics_middleware.cloudwatch_client")
def test_with_metrics(mock_cloudwatch):
    mock_cloudwatch.put_metric_data.return_value = None
```

## Test Execution Requirements

### Running Tests Successfully
All tests are designed to run without external dependencies:

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific module tests
pytest tests/test_cache.py
pytest tests/test_pathfinding.py
```

### CI/CD Environment
Tests run successfully in GitHub Actions with:
- No MongoDB instance
- No Redis instance
- No email server
- No GPT-4 API key
- No AWS credentials

## Coverage Goals

| Module | Current Coverage | Target | Status |
|--------|-----------------|--------|--------|
| app/cache.py | 95% | 80% | Exceeded |
| app/pathfinding/ | 88% | 70% | Exceeded |
| app/emissions/storage.py | 93% | 70% | Exceeded |
| app/parking/storage.py | 85% | 70% | Exceeded |
| app/auth/ | 87% | 90% | Near target |
| app/admin/ | 86% | 90% | Near target |

## Test Reliability

### Deterministic Testing
- All time-dependent operations use `freezegun` or mocked datetime
- Random values use fixed seeds
- Database IDs use predictable ObjectIds

### Isolation
- Each test is completely isolated
- No shared state between tests
- Database collections cleared between tests (mocked)
- Cache cleared between tests (mocked)

## Common Troubleshooting

### Issue: Tests hang or timeout
**Solution:** Ensure all async operations are properly mocked

### Issue: Intermittent failures
**Solution:** Check for unmocked external calls or race conditions

### Issue: Coverage not updating
**Solution:** Clear pytest cache: `pytest --cache-clear`

## Continuous Improvement

### Adding New Tests
1. Always mock external dependencies
2. Use existing mock patterns from similar tests
3. Ensure tests are deterministic
4. Add both success and failure scenarios

### Maintaining Test Quality
- Regular review of mock accuracy
- Update mocks when API contracts change
- Keep test data realistic
- Document any special test requirements