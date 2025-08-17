# AutoSpot API Documentation

## Overview

The AutoSpot API is a comprehensive RESTful service built with FastAPI, providing intelligent parking management capabilities. This documentation covers all endpoints, authentication mechanisms, and integration guidelines.

## Base URLs

- **Production**: `https://api.autospot.it.com`
- **Development**: `http://localhost:8000`
- **Interactive Documentation**: `https://api.autospot.it.com/docs`
- **Alternative Documentation**: `https://api.autospot.it.com/redoc`

## Authentication

### JWT Token-based Authentication

The API uses JSON Web Tokens (JWT) for authentication. Include the token in the Authorization header:

```http
Authorization: Bearer <your_jwt_token>
```

### Token Lifecycle

- **Access Token Expiration**: 1 hour
- **Refresh Token Expiration**: 24 hours
- **Token Format**: `Bearer <token>`

## API Endpoints

### Authentication Module

#### User Registration
```http
POST /auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "johndoe",
  "password": "SecurePass123!",
  "fullname": "John Doe",
  "address": "123 Main St, Sydney, NSW 2000"
}
```

**Response (200 OK):**
```json
{
  "msg": "OTP sent to email for verification",
  "otp_expires_in": 300
}
```

**Validation Rules:**
- Email: Valid email format, case-insensitive
- Username: 3-30 characters, alphanumeric and underscore only
- Password: Minimum 8 characters, must include uppercase, lowercase, number, special character
- Full name: 2-100 characters

#### Email Verification
```http
POST /auth/verify-registration
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

**Response (200 OK):**
```json
{
  "msg": "Registration successful!"
}
```

#### User Login
```http
POST /auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user_data": {
    "email": "user@example.com",
    "username": "johndoe",
    "fullname": "John Doe",
    "role": "user"
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
- `403 Forbidden`: Account suspended due to multiple failed attempts
- `404 Not Found`: Email not registered

#### Password Management
```http
POST /auth/forgot-password
```

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

```http
POST /auth/reset-password
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "otp": "123456",
  "new_password": "NewSecurePass123!"
}
```

### Parking Management

#### Get Parking Slots
```http
GET /parking/slots?building_name={building}&level={level}
```

**Query Parameters:**
- `building_name` (optional): Filter by building
- `level` (optional): Filter by parking level
- `status` (optional): Filter by slot status (available, occupied, reserved)

**Response (200 OK):**
```json
{
  "building_name": "Building A",
  "total_slots": 150,
  "available_slots": 45,
  "levels": [
    {
      "level": 1,
      "slots": [
        {
          "slot_id": "A1-01",
          "x": 10,
          "y": 20,
          "status": "available",
          "type": "regular",
          "accessibility": false
        },
        {
          "slot_id": "A1-02",
          "x": 30,
          "y": 20,
          "status": "occupied",
          "type": "regular",
          "reserved_by": "user@example.com",
          "occupied_since": "2024-01-15T10:30:00Z"
        }
      ]
    }
  ]
}
```

#### Upload Parking Map
```http
POST /parking/upload-map
```

**Content-Type**: `multipart/form-data`

**Form Data:**
- `file`: Image file (JPG, PNG, GIF, max 10MB)
- `building_name`: Building identifier
- `level`: Parking level number (1-10)
- `grid_rows`: Grid rows for processing (4-20)
- `grid_cols`: Grid columns for processing (4-20)

**Response (200 OK):**
```json
{
  "success": true,
  "building_name": "Building A",
  "level": 1,
  "processing_results": {
    "total_slots": 50,
    "entrances": 2,
    "exits": 2,
    "corridors": 25
  },
  "map_data": [...],
  "processing_time": 2.5
}
```

#### Calculate Parking Fare
```http
GET /parking/fare?duration={minutes}&destination={dest}&user_email={email}
```

**Query Parameters:**
- `duration`: Parking duration in minutes
- `destination`: Destination name for pricing
- `user_email`: User email for subscription discounts

**Response (200 OK):**
```json
{
  "base_fare": 15.00,
  "duration_hours": 2.5,
  "destination": "University",
  "pricing_factors": {
    "base_rate": 6.00,
    "peak_hour_multiplier": 1.2,
    "weekend_discount": 0.9,
    "subscription_discount": 0.8
  },
  "final_fare": 12.96,
  "currency": "AUD"
}
```

### Session Management

#### Start Parking Session
```http
POST /session/start
```

**Request Body:**
```json
{
  "user_email": "user@example.com",
  "slot_id": "A1-01",
  "building_name": "Building A",
  "level": 1,
  "estimated_duration": 120,
  "destination": "University"
}
```

**Response (200 OK):**
```json
{
  "session_id": "sess_1234567890",
  "slot_id": "A1-01",
  "start_time": "2024-01-15T10:30:00Z",
  "estimated_end_time": "2024-01-15T12:30:00Z",
  "initial_fare_estimate": 12.00
}
```

#### End Parking Session
```http
POST /session/end
```

**Request Body:**
```json
{
  "user_email": "user@example.com",
  "session_id": "sess_1234567890"
}
```

**Response (200 OK):**
```json
{
  "session_id": "sess_1234567890",
  "end_time": "2024-01-15T12:45:00Z",
  "total_duration": 135,
  "final_fare": 13.50,
  "payment_status": "completed",
  "receipt_id": "rcpt_9876543210"
}
```

#### Get Active Session
```http
GET /session/active?user_email={email}
```

**Response (200 OK):**
```json
{
  "session_id": "sess_1234567890",
  "slot_id": "A1-01",
  "building_name": "Building A",
  "start_time": "2024-01-15T10:30:00Z",
  "elapsed_time": 75,
  "current_fare_estimate": 9.38,
  "status": "active"
}
```

### Wallet and Payments

#### Get Wallet Balance
```http
GET /wallet/balance?user_email={email}
```

**Response (200 OK):**
```json
{
  "user_email": "user@example.com",
  "balance": 85.50,
  "currency": "AUD",
  "last_updated": "2024-01-15T09:15:00Z"
}
```

#### Add Funds to Wallet
```http
POST /wallet/add-funds
```

**Request Body:**
```json
{
  "user_email": "user@example.com",
  "amount": 50.00,
  "payment_method_id": "pm_card_1234",
  "payment_source": "credit_card"
}
```

**Response (200 OK):**
```json
{
  "transaction_id": "txn_add_funds_5678",
  "new_balance": 135.50,
  "amount_added": 50.00,
  "transaction_fee": 0.00,
  "timestamp": "2024-01-15T11:00:00Z"
}
```

#### Process Payment
```http
POST /wallet/payment
```

**Request Body:**
```json
{
  "user_email": "user@example.com",
  "amount": 13.50,
  "description": "Parking fee - Session sess_1234567890",
  "session_id": "sess_1234567890"
}
```

### Pathfinding and Navigation

#### Get Shortest Path
```http
GET /pathfinding/shortest-path?start={start}&end={end}&building_name={building}
```

**Query Parameters:**
- `start`: Start coordinates in format "level,x,y" (e.g., "1,0,0")
- `end`: End coordinates in format "level,x,y" (e.g., "1,5,5")
- `building_name`: Building identifier
- `map_id` (optional): Specific map ID

**Response (200 OK):**
```json
{
  "start_point": [1, 0, 0],
  "end_point": [1, 5, 5],
  "path": [
    [1, 0, 0],
    [1, 1, 0],
    [1, 2, 0],
    [1, 3, 1],
    [1, 4, 2],
    [1, 5, 5]
  ],
  "total_distance": 8.45,
  "path_length": 6,
  "estimated_walk_time": 102
}
```

#### Find Nearest Slot
```http
GET /pathfinding/nearest-slot?entrance_id={id}&building_name={building}
```

**Response (200 OK):**
```json
{
  "entrance": {
    "id": "E1",
    "x": 0,
    "y": 10,
    "level": 1
  },
  "nearest_slot": {
    "slot_id": "A1-03",
    "x": 15,
    "y": 12,
    "level": 1,
    "status": "available",
    "type": "regular"
  },
  "path_info": {
    "distance": 18.03,
    "estimated_walk_time": 216,
    "path": [[1, 0, 10], [1, 5, 10], [1, 10, 11], [1, 15, 12]]
  }
}
```

### Carbon Emissions

#### Estimate Emissions Saved
```http
GET /emissions/estimate?route_distance={distance}&username={user}&session_id={session}
```

**Query Parameters:**
- `route_distance`: Actual route distance in meters
- `baseline_distance` (optional): Baseline search distance
- `emissions_factor` (optional): Custom CO2 emissions factor
- `username` (optional): Username for history tracking
- `session_id` (optional): Associated session ID

**Response (200 OK):**
```json
{
  "success": true,
  "route_distance": 125.5,
  "baseline_distance": 450.0,
  "emissions_factor": 0.194,
  "actual_emissions": 24.35,
  "baseline_emissions": 87.30,
  "emissions_saved": 62.95,
  "percentage_saved": 72.1,
  "message": "You saved 63.0g CO₂ (72.1%) by using AutoSpot!",
  "calculation_method": "static"
}
```

#### Get Emissions History
```http
GET /emissions/history?username={user}&limit={limit}&days={days}
```

**Response (200 OK):**
```json
{
  "username": "johndoe",
  "total_records": 25,
  "date_range": {
    "start": "2024-01-01T00:00:00Z",
    "end": "2024-01-15T23:59:59Z"
  },
  "summary": {
    "total_emissions_saved": 1250.75,
    "total_distance_optimized": 6450.0,
    "average_savings_percentage": 68.5,
    "environmental_impact": "equivalent to 0.85kg CO2 saved"
  },
  "records": [...]
}
```

### QR Code Generation

#### Generate Entrance QR Code
```http
POST /qr/generate-entrance
```

**Request Body:**
```json
{
  "entrance_id": "E1",
  "building_name": "Building A",
  "level": 1,
  "coordinates": {"x": 0, "y": 10}
}
```

**Response (200 OK):**
```json
{
  "qr_code_id": "qr_entrance_E1_1642234567",
  "qr_data": "ENTRANCE:E1:Building A:1:0,10",
  "qr_image_base64": "iVBORw0KGgoAAAANSUhEUgAAAPoAAAD6CAYAAACI7Fo9...",
  "expiry_time": "2024-01-15T23:59:59Z",
  "usage_info": {
    "scan_count": 0,
    "max_scans": 1000,
    "single_use": false
  }
}
```

#### Scan QR Code
```http
POST /qr/scan
```

**Request Body:**
```json
{
  "qr_data": "ENTRANCE:E1:Building A:1:0,10",
  "user_email": "user@example.com",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Admin Management

#### Admin Registration
```http
POST /admin/register
```

**Request Body:**
```json
{
  "email": "admin@autospot.com",
  "keyid": "ADMIN_KEY_2024"
}
```

#### Admin Login
```http
POST /admin/login
```

**Request Body:**
```json
{
  "keyid": "ADMIN_KEY_2024",
  "username": "admin_user",
  "password": "admin_password"
}
```

#### Update Parking Slot Status
```http
PUT /admin/parking/slot-status
```

**Request Body:**
```json
{
  "keyid": "ADMIN_KEY_2024",
  "username": "admin_user",
  "password": "admin_password",
  "building_name": "Building A",
  "level": 1,
  "slot_id": "A1-01",
  "new_status": "occupied",
  "reserved_by": "user@example.com"
}
```

## Error Handling

### Standard Error Response Format
```json
{
  "detail": "Error description",
  "error_code": "SPECIFIC_ERROR_CODE",
  "timestamp": "2024-01-15T10:30:00Z",
  "request_id": "req_1234567890"
}
```

### Common HTTP Status Codes

| Status Code | Description | Common Causes |
|-------------|-------------|---------------|
| 200 | OK | Successful request |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid input data, validation errors |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource already exists |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server-side error |
| 503 | Service Unavailable | External service unavailable |

## Rate Limiting

### Rate Limit Headers
All responses include rate limiting headers:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1642234567
```

### Rate Limits by Endpoint Category

| Category | Limit | Window |
|----------|-------|--------|
| Authentication | 10 requests | 1 minute |
| Parking Operations | 100 requests | 1 minute |
| Pathfinding | 200 requests | 1 minute |
| File Upload | 5 requests | 5 minutes |
| General API | 1000 requests | 1 hour |

## SDK and Code Examples

### Python SDK Example
```python
import requests
from typing import Optional

class AutoSpotAPI:
    def __init__(self, base_url: str, access_token: Optional[str] = None):
        self.base_url = base_url
        self.access_token = access_token
        
    def login(self, email: str, password: str) -> dict:
        response = requests.post(
            f"{self.base_url}/auth/login",
            json={"email": email, "password": password}
        )
        response.raise_for_status()
        data = response.json()
        self.access_token = data["access_token"]
        return data
        
    def get_parking_slots(self, building_name: str) -> dict:
        headers = {"Authorization": f"Bearer {self.access_token}"}
        response = requests.get(
            f"{self.base_url}/parking/slots",
            params={"building_name": building_name},
            headers=headers
        )
        response.raise_for_status()
        return response.json()

# Usage
api = AutoSpotAPI("https://api.autospot.it.com")
api.login("user@example.com", "password")
slots = api.get_parking_slots("Building A")
```

### JavaScript/Node.js Example
```javascript
class AutoSpotAPI {
    constructor(baseUrl) {
        this.baseUrl = baseUrl;
        this.accessToken = null;
    }
    
    async login(email, password) {
        const response = await fetch(`${this.baseUrl}/auth/login`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({email, password})
        });
        
        if (!response.ok) {
            throw new Error(`Login failed: ${response.statusText}`);
        }
        
        const data = await response.json();
        this.accessToken = data.access_token;
        return data;
    }
    
    async getParkingSlots(buildingName) {
        const response = await fetch(
            `${this.baseUrl}/parking/slots?building_name=${buildingName}`,
            {
                headers: {
                    'Authorization': `Bearer ${this.accessToken}`
                }
            }
        );
        
        if (!response.ok) {
            throw new Error(`API call failed: ${response.statusText}`);
        }
        
        return await response.json();
    }
}

// Usage
const api = new AutoSpotAPI('https://api.autospot.it.com');
await api.login('user@example.com', 'password');
const slots = await api.getParkingSlots('Building A');
```

## Webhooks and Real-time Updates

### Webhook Events
The API supports webhooks for real-time notifications:

- `parking.slot.status_changed`
- `session.started`
- `session.ended`
- `payment.completed`
- `user.registered`

### Webhook Payload Example
```json
{
  "event_type": "parking.slot.status_changed",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "building_name": "Building A",
    "level": 1,
    "slot_id": "A1-01",
    "old_status": "available",
    "new_status": "occupied",
    "user_email": "user@example.com"
  },
  "webhook_id": "wh_1234567890"
}
```

## Testing and Development

### Test Environment
- **Base URL**: `http://localhost:8000`
- **Test Database**: Isolated test data
- **Mock External Services**: No real charges or external API calls

### Health Check Endpoint
```http
GET /api/health
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "2.0.0",
  "services": {
    "database": "connected",
    "cache": "available",
    "external_apis": "reachable"
  }
}
```

## Support and Contact

- **Documentation**: https://docs.autospot.it.com
- **Status Page**: https://status.autospot.it.com
- **Support Email**: support@autospot.it.com
- **GitHub Repository**: https://github.com/autospot/backend

## Changelog

### Version 2.0.0 (Current)
- Added carbon emissions tracking
- Implemented advanced pathfinding algorithms
- Enhanced security with JWT authentication
- Added comprehensive admin management
- Introduced real-time session tracking

### Version 1.0.0
- Initial API release
- Basic parking management
- User authentication
- Payment processing