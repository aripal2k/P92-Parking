# Backend Testing Strategy

This directory contains comprehensive tests for the AutoSpot backend system.

## Coverage Metrics
**Current Coverage: 75%** | **Target Coverage: 75%** - Achieved

| Module | Current | Target | Status |
|--------|---------|--------|--------|
| `app/cache.py` | 95% | 80% | Exceeded |
| `app/pathfinding/` | 88% | 70% | Exceeded |
| `app/emissions/storage.py` | 93% | 70% | Exceeded |
| `app/parking/storage.py` | 85% | 70% | Exceeded |
| `app/session/` | 78% | 70% | Exceeded |
| `app/wallet/` | 82% | 75% | Exceeded |
| `app/auth/` | 87% | 90% | Near target |
| `app/admin/` | 86% | 90% | Near target |
| `app/QRcode/` | 91% | 80% | Exceeded |

## Test Structure

The tests are organized into separate files based on functionality:

### Test Files

1. **`conftest.py`** - Pytest configuration and shared fixtures
2. **`test_auth_utils.py`** - Unit tests for authentication utility functions
3. **`test_auth_registration.py`** - Tests for user registration and verification
4. **`test_auth_login.py`** - Tests for user login and session management
5. **`test_auth_password.py`** - Tests for password management operations including change, forget and resetting
6. **`test_auth_account.py`** - Tests for account management operations including deleting, editing profile and get profile
7. **`test_auth_integration.py`** - Integration tests and edge cases

## Testing Approach

### Test Categories
- **Unit Tests**: Individual functions with mocked dependencies
- **Integration Tests**: API endpoints with database interactions
- **Happy Path Tests**: Normal operation scenarios
- **Edge Cases**: Boundary conditions and limits
- **Error Handling**: Invalid inputs and failure scenarios
- **Concurrency Tests**: Race conditions in parking slot booking

### External Dependencies Mocking
- **MongoDB**: Mocked using `unittest.mock` and `pytest-mock`
- **Redis Cache**: Fully mocked to avoid external service dependency
- **GPT-4 Vision API**: Complete mocking to avoid API costs
- **CloudWatch Metrics**: Mocked for metrics recording

## Prerequisites

Before running the tests, you MUST install all dependencies from requirements.txt:

### Linux/Mac/WSL
```bash
cd Backend
pip install -r requirements.txt
```

### Windows PowerShell
```powershell
cd Backend

# Method 1: Install with --user flag (simplest)
python -m pip install -r requirements.txt --user

# Method 2: Use virtual environment (recommended)
python -m venv venv
.\venv\Scripts\Activate
pip install -r requirements.txt
```

### Critical Test Dependencies
The following test dependencies MUST be installed (all included in requirements.txt):
- `pytest>=7.0.0` - Testing framework
- `pytest-cov` - Coverage reporting tool
- `mongomock>=4.1.0` - MongoDB mocking for database tests (REQUIRED!)
- `pytest-asyncio>=0.21.0` - Async testing support
- `pytest-mock>=3.10.0` - Enhanced mocking capabilities
- `httpx>=0.24.0` - HTTP client for API testing

**Common Error:** If you see `ModuleNotFoundError: No module named 'mongomock'`, you haven't installed the dependencies yet!

## Running Tests

### Linux/Mac/WSL
```bash
cd Backend

# Run all tests
pytest

# Or specify tests directory
pytest tests/
```

### Windows PowerShell
```powershell
cd Backend

# MUST use python -m to run pytest
python -m pytest

# Or specify tests directory
python -m pytest tests/
```

**Windows Note:** Always use `python -m pytest` instead of just `pytest` in PowerShell!

### Run Specific Test Files

#### Linux/Mac/WSL
```bash
# Run only registration tests
pytest tests/test_auth_registration.py

# Run only wallet tests
pytest tests/test_wallet.py
```

#### Windows PowerShell
```powershell
# Run only registration tests
python -m pytest tests/test_auth_registration.py

# Run only wallet tests
python -m pytest tests/test_wallet.py
```

#### All Available Test Files
```bash
# User Authentication Tests
test_auth_utils.py           # Utility function tests
test_auth_registration.py    # User registration tests
test_auth_login.py           # User login tests
test_auth_password.py        # Password management tests
test_auth_account.py         # Account management tests
test_auth_integration.py     # User auth integration tests

# Admin Tests
test_admin_registration.py   # Admin registration tests
test_admin_login.py          # Admin login tests
test_admin_profile.py        # Admin profile tests
test_admin_parking.py        # Parking slot management tests
test_admin_integration.py    # Admin integration tests
test_admin_operations.py     # Admin operations tests

# Feature Tests
test_carbon_emissions.py     # Carbon emissions tests
test_wallet.py              # Wallet-related tests
test_parking_router.py      # Parking management tests
test_session_router.py      # Session management tests
test_pathfinding_router.py  # Pathfinding tests
test_emissions_router.py    # Emissions API tests
test_qrcode.py             # QR code generation tests
test_cache.py              # Redis cache tests
```

## Test Coverage

### `test_auth_utils.py`
- Password hashing and verification
- Edge cases with special characters and unicode
- Error handling for invalid inputs

### `test_auth_registration.py`
- User registration request validation
- OTP generation and email sending
- Registration verification process
- Password strength validation
- Email and username uniqueness checks
- Email case-(in)sensitivity

### `test_auth_login.py`
- Successful login scenarios
- Failed login attempt tracking
- Account suspension mechanism
- Login with unregistered emails
- Case-insensitive email handling
- Backward compatibility with missing fields

### `test_auth_password.py`
- Password change functionality
- Forgot password flow
- OTP verification for password reset
- Password reset completion
- Password validation consistency
- Security checks (same password, common passwords)

### `test_auth_account.py`
- Account deletion with password verification
- Profile editing (full and partial updates)
- Profile retrieval with proper data exclusion
- Username availability checking
- Email normalization

### `test_auth_integration.py`
- Complete registration → verification → login flow
- Full password reset workflow
- Profile management lifecycle
- Edge cases and error scenarios
- Database error handling
- Concurrent operation testing

## Admin Test Coverage

### `test_admin_registration.py`
- Admin registration with generated username and password
- Email normalization and uniqueness
- KeyID uniqueness and collision handling
- Metrics and logging for registration events

### `test_admin_login.py`
- Admin login with plain and hashed passwords
- Case-insensitive keyID and email matching
- Multiple admins per keyID
- Error handling for invalid credentials, username mismatch, and email mismatch
- Metrics for login success/failure

### `test_admin_profile.py`
- Admin profile editing (username change)
- Password change (with strength validation)
- Authentication and authorization checks (keyID+username+password)
- Username uniqueness across admins
- Error handling for invalid credentials, username taken, and weak passwords
- Metrics for profile and password changes

### `test_admin_parking.py`
- Parking slot info retrieval
- Parking slot status updates (available, occupied, allocated)
- Validation of `reserved_by` for occupied/allocated status (user existence)
- Example data conversion to database on update
- Error handling: slot not found, context mismatch, missing fields
- Metrics for slot updates

### `test_admin_operations.py`
- Data statistics retrieval (user/map counts, storage usage)
- Data clearing (admin password required)
- Parking rate editing (destination authorization, flexible matching)
- Utility function coverage (authorization, normalization)
- Error handling for invalid credentials, unauthorized access

### `test_admin_integration.py`
- Full admin workflow: registration, login, profile management, parking management, data management
- Multiple admins per keyID

### `test_carbon_emissions.py`
- calculation utilities for emissions
- static/dynamic calculation methods
- all API endpoints, error handling and response structure match

### `test_wallet.py`
- get wallet balance (0 balance)
- add payment method
- add money to wallet
- make a parking payment
- get transaction history

## Test Features

### Mocking Strategy
- **Database Mocking**: Uses `mongomock` to simulate MongoDB operations
- **Email Mocking**: Mocks email sending functionality
- **Time Mocking**: Controls time-dependent operations (OTP expiration, suspensions)
- **External Service Mocking**: Mocks CloudWatch metrics and other external dependencies

### Test Data
- **Fixtures**: Predefined test data for consistent testing
- **Edge Cases**: Tests with various invalid inputs and boundary conditions
- **Security Testing**: Validates password policies and security measures

### Error Testing
- **HTTP Exception Testing**: Validates proper error codes and messages
- **Validation Testing**: Tests input validation and sanitization
- **Edge Case Testing**: Handles missing fields, expired tokens, etc.

## Running Tests with Coverage

### Linux/Mac/WSL
```bash
# Terminal coverage report
pytest --cov=app --cov-report=term-missing

# HTML coverage report
pytest --cov=app --cov-report=html

# View HTML report
open htmlcov/index.html      # Mac
xdg-open htmlcov/index.html  # Linux

# XML coverage report (for CI)
pytest --cov=app --cov-report=xml
```

### Windows PowerShell
```powershell
# Terminal coverage report
python -m pytest --cov=app --cov-report=term-missing

# HTML coverage report
python -m pytest --cov=app --cov-report=html

# View HTML report
start htmlcov/index.html

# XML coverage report (for CI)
python -m pytest --cov=app --cov-report=xml
```

**Windows Troubleshooting:**
- If `pytest-cov` not found: `python -m pip install pytest-cov --user`
- HTML report location: `Backend\htmlcov\index.html`

### Coverage Goals
- Maintain minimum 75% overall coverage
- 100% coverage for critical business logic
- All API endpoints must have integration tests
- All error paths must be tested

## Comprehensive Mocking Strategy

All tests are designed to run without external dependencies. For detailed mocking patterns and strategies, see:
- [Test Failures Documentation](./test_failures.md) - Explains expected failures and resolutions
- [Mocking Strategy Guide](../../docs/MOCKING_STRATEGY.md) - Comprehensive mocking patterns

### Key Mocking Approaches
1. **MongoDB**: All database operations use `unittest.mock.patch`
2. **Redis**: Cache operations fully mocked with `MagicMock`
3. **External APIs**: GPT-4, email, CloudWatch all mocked
4. **Time Operations**: Using `freezegun` for deterministic time testing
5. **File System**: Mocked with `mock_open` for file operations

## Contributing
When adding new features:
1. Write tests FIRST (TDD approach)
2. Cover both happy and sad paths
3. Mock all external dependencies
4. Run tests locally before pushing
5. Maintain or improve coverage percentage
6. Document any external dependency failures in test_failures.md
