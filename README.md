# AutoSpot - Smart Vehicle Parking Management System

[![Backend Tests](https://github.com/unsw-cse-comp99-3900/capstone-project-25t2-3900-t16a-cherry/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/unsw-cse-comp99-3900/capstone-project-25t2-3900-t16a-cherry/actions)
[![Backend Coverage](https://img.shields.io/badge/Backend%20Coverage-75%25-brightgreen)](./Backend/tests/README.md)
[![Frontend Coverage](https://img.shields.io/badge/Frontend%20Coverage-70%25-yellow)](./Frontend/autospot/test/README.md)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Project Overview

AutoSpot is a comprehensive smart parking management system that optimizes parking space utilization, reduces search time, and minimizes carbon emissions through intelligent routing and real-time slot management.

### Key Features
- **Real-time Parking Availability**: Live updates on parking slot status
- **Smart Pathfinding**: Optimal route calculation to available spots
- **QR Code Entry/Exit**: Seamless access control via QR scanning
- **Carbon Emission Tracking**: Environmental impact monitoring
- **Dynamic Pricing**: Time-based and demand-based fare calculation
- **Mobile & Web Support**: Cross-platform Flutter application
- **Admin Dashboard**: Comprehensive parking lot management

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Flutter)                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ User Module │  │ Operator Module│  │ Admin Module │  │
│  └─────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
                     REST API (HTTPS)
                            │
┌─────────────────────────────────────────────────────────┐
│                   Backend (FastAPI)                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │         API Gateway & Middleware Layer          │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐  │
│  │   Auth   │ │ Parking  │ │ Session  │ │ Wallet  │  │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐  │
│  │Pathfinding│ │Emissions │ │  QRCode  │ │  Admin  │  │
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘  │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│    MongoDB    │  │     Redis     │  │  CloudWatch   │
│   (Database)  │  │    (Cache)    │  │   (Metrics)   │
└───────────────┘  └───────────────┘  └───────────────┘
```

## Technology Stack

### Backend
- **Framework**: FastAPI (Python 3.10+)
- **Database**: MongoDB (NoSQL)
- **Cache**: Redis
- **Authentication**: JWT tokens
- **API Documentation**: OpenAPI/Swagger
- **Testing**: Pytest with 75% coverage
- **Deployment**: Docker, AWS EC2

### Frontend
- **Framework**: Flutter 3.0+
- **State Management**: Provider/SharedPreferences
- **HTTP Client**: Dio
- **Testing**: Flutter Test with 70% coverage
- **Platforms**: iOS, Android, Web

### Infrastructure
- **Containerization**: Docker & Docker Compose
- **CI/CD**: GitHub Actions
- **Monitoring**: AWS CloudWatch
- **Domain**: autospot.it.com
- **API Endpoint**: api.autospot.it.com

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.10+ (for local development)
- Flutter 3.0+ (for frontend)
- Git

### Installation

#### Using Docker (Recommended)
```bash
# Clone the repository
git clone https://github.com/unsw-cse-comp99-3900/capstone-project-25t2-3900-t16a-cherry.git
cd capstone-project-25t2-3900-t16a-cherry

# Start backend services
cd Backend
docker-compose up --build

# Backend will be available at http://localhost:8000
```

#### Local Development

**Backend:**
```bash
cd Backend
pip install -r requirements.txt

# Create .env file
echo "MONGODB_URI=mongodb://localhost:27017" > .env

# Run the server
uvicorn app.main:app --reload --port 8000
```

**Frontend:**
```bash
# Navigate to Flutter project directory (important!)
cd Frontend/autospot  # ⚠️ Note: autospot subdirectory!

# Install dependencies
flutter pub get

# Run on emulator/device
flutter run

# Run on web
flutter run -d chrome
```

## Testing

### Backend Testing

#### Prerequisites - Install Dependencies First!
```bash
cd Backend

# Linux/Mac/WSL
pip install -r requirements.txt

# Windows PowerShell - Choose one method:
# Method 1: Install with --user flag (simplest)
python -m pip install -r requirements.txt --user

# Method 2: Use virtual environment (recommended)
python -m venv venv
.\venv\Scripts\Activate  # Windows
source venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
```

**Critical dependencies for testing** (all included in requirements.txt):
- `pytest` - Testing framework
- `pytest-cov` - Coverage reporting  
- `mongomock` - MongoDB mocking (required!)
- `pytest-asyncio` - Async test support
- `pytest-mock` - Enhanced mocking

#### Running Tests

##### Linux/Mac/WSL
```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# View coverage report
open htmlcov/index.html      # Mac
xdg-open htmlcov/index.html  # Linux
```

##### Windows PowerShell
```powershell
# Run all tests (must use python -m)
python -m pytest

# Run with coverage
python -m pytest --cov=app --cov-report=html

# View coverage report
start htmlcov/index.html
```

**Troubleshooting Windows issues:**
- If `ModuleNotFoundError: No module named 'mongomock'`: Install dependencies first!
- If permission errors: Use `--user` flag or run as Administrator
- If `pytest` command not found: Use `python -m pytest` instead

### Frontend Testing

**Important:** The Flutter project is located in `Frontend/autospot`, NOT in `Frontend`!

```bash
# Navigate to the correct directory first
cd Frontend/autospot  # ⚠️ Must be in autospot subdirectory!

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate and view HTML report
# Linux/Mac
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html      # Mac
xdg-open coverage/html/index.html  # Linux

# Windows PowerShell
# (genhtml needs to be installed separately on Windows)
start coverage/html/index.html
```

**Common Error:** If you see "Test directory 'test' not found", you're in the wrong directory. Make sure you're in `Frontend/autospot`, not just `Frontend`.

## API Documentation

### Interactive API Docs
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Key Endpoints

#### Authentication
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `POST /auth/change-password` - Change password

#### Parking Management
- `GET /parking/slots` - Get available slots
- `POST /parking/upload-map` - Upload parking map
- `GET /parking/fare` - Calculate parking fare

#### Session Management
- `POST /session/start` - Start parking session
- `POST /session/end` - End parking session
- `GET /session/active` - Get active session

#### Wallet & Payments
- `GET /wallet/balance` - Get wallet balance
- `POST /wallet/add-funds` - Add funds to wallet
- `POST /wallet/payment` - Process payment

## Project Structure

```
capstone-project/
├── Backend/
│   ├── app/
│   │   ├── main.py           # FastAPI application
│   │   ├── auth/             # Authentication module
│   │   ├── parking/          # Parking management
│   │   ├── session/          # Session tracking
│   │   ├── wallet/           # Payment processing
│   │   ├── pathfinding/      # Route calculation
│   │   ├── emissions/        # Carbon tracking
│   │   ├── QRcode/           # QR generation
│   │   └── admin/            # Admin operations
│   ├── tests/                # Test suite
│   ├── requirements.txt      # Python dependencies
│   └── docker-compose.yml    # Docker configuration
│
├── Frontend/
│   └── autospot/
│       ├── lib/
│       │   ├── main.dart     # App entry point
│       │   ├── user/         # User screens
│       │   ├── operator/     # Operator screens
│       │   └── config/       # Configuration
│       ├── test/             # Test suite
│       └── pubspec.yaml      # Flutter dependencies
│
├── docs/                     # Documentation
├── .github/                  # GitHub Actions
└── README.md                 # This file
```

## Development Guidelines

### Code Style
- **Python**: Follow PEP 8, use Black formatter
- **Dart**: Follow Flutter style guide
- **Commits**: Use conventional commits format

### Testing Requirements
- Minimum 70% code coverage
- All API endpoints must have tests
- Mock all external dependencies
- Document test failures in `test_failures.md`

### Branch Strategy
- `main`: Production-ready code
- `develop`: Development branch
- Feature branches: `feature/description`
- Bug fixes: `fix/description`

## Deployment

### Production Deployment
The application is automatically deployed to AWS EC2 on push to main branch.

- API URL: https://api.autospot.it.com
- Web App: https://autospot.it.com

### Manual Deployment
```bash
# SSH to server
ssh ubuntu@54.156.215.128

# Pull latest changes
cd /home/ubuntu/app
git pull origin main

# Restart services
docker-compose down
docker-compose up -d
```

## Environment Variables

### Backend (.env)
```
MONGODB_URI=mongodb://localhost:27017
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
OPENAI_API_KEY=your-openai-key
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
```

### Frontend (lib/config/api_config.dart)
```dart
// Toggle for environment
static const bool useLocalHost = false; // true for local, false for production
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Pull Request Guidelines
- Include test coverage for new features
- Update documentation as needed
- Ensure all tests pass
- Follow code style guidelines

## Troubleshooting

### Common Issues

#### MongoDB Connection Error
```bash
# Ensure MongoDB is running
docker-compose up mongodb
```

#### Redis Connection Error
```bash
# Ensure Redis is running
docker-compose up redis
```

#### Flutter Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Performance Metrics

- **API Response Time**: < 200ms average
- **Database Query Time**: < 50ms average
- **Test Execution Time**: < 2 minutes
- **Docker Build Time**: < 3 minutes
- **Coverage Goals**: 75% backend, 70% frontend

## Security

- JWT-based authentication
- Password hashing with bcrypt
- Input validation on all endpoints
- Rate limiting on API calls
- HTTPS enforcement in production
- Environment variables for secrets

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- UNSW CSE COMP3900 Course Staff
- Team T16A Cherry Members
- Open Source Contributors

## Documentation

For detailed documentation, see:
- [Backend Testing Guide](Backend/tests/README.md)
- [Frontend Testing Guide](Frontend/autospot/test/README.md)
- [API Documentation](http://localhost:8000/docs)
- [Testing Strategy](docs/TESTING_GUIDE.md)
- [Mocking Strategy](docs/MOCKING_STRATEGY.md)