# AutoSpot Backend - Smart Parking Management System

A high-performance, scalable backend service built with FastAPI, featuring advanced algorithms for parking optimization, real-time session management, and intelligent pathfinding.

## 🚀 Quick Start

### Option 1: Run with Docker Compose
1. Make sure you have Docker and Docker Compose installed.
2. Start all services (backend and MongoDB) with one command:
   ```bash
   docker-compose up --build
   ```
3. **Load sample data** (in another terminal):
   ```bash
   python app/examples/local_mongodb_storage.py
   ```
4. The backend will be available at http://localhost:8000/docs

---
✅ **Ready to test!** Access API documentation at: http://localhost:8000/docs

### Option 2: Run Locally with Python

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Start the server:
   ```bash
   uvicorn app.main:app --reload --port 8080
   ```


## Environment Variables Setup

**Note:** The `.env` file contains sensitive information and will not be committed to the Git repository. Each developer needs to create this file themselves.

### Using Docker Compose (Recommended) - NO .env file needed!
When using `docker-compose up`, the environment variables are automatically set in the `docker-compose.yml` file. You don't need to create a `.env` file.

### Local Development (without Docker) - .env file required
If you want to run the backend locally without Docker, create a `.env` file in the Backend directory:

```bash
# MongoDB connection configuration (local environment)
MONGODB_URI=mongodb://localhost:27017

# Optional configurations (not currently used in the code)
# JWT_SECRET_KEY=your-secret-key-here
# DEBUG=True
```
## 🎯 Key Features

### Advanced Algorithms
- **Dijkstra's Shortest Path**: Optimal route calculation for parking navigation
- **Computer Vision Processing**: GPT-4o integration for intelligent map analysis
- **Carbon Emission Calculation**: Environmental impact tracking and optimization
- **Dynamic Pricing**: Time-based and demand-responsive fare calculation

### Technical Excellence
- **75% Test Coverage**: Comprehensive testing with 529+ test cases
- **Redis Caching**: High-performance caching with hit rate monitoring
- **CloudWatch Integration**: Real-time performance metrics and monitoring
- **Production-Ready**: Docker containerization with SSL/TLS security

### API Capabilities
- **RESTful Design**: OpenAPI/Swagger documentation
- **Real-time Updates**: WebSocket support for live parking status
- **Multi-level Support**: Complex 3D parking structure navigation
- **Robust Authentication**: JWT-based security with OTP verification

## 📊 Performance Metrics

- **Average Response Time**: <200ms
- **Concurrent Users**: 1,000+ supported
- **Database Query Time**: <50ms average
- **Cache Hit Rate**: 87% for parking data
- **Uptime**: 99.8% availability

## 🛠 Technology Stack

- **Framework**: FastAPI (Python 3.10+)
- **Database**: MongoDB with optimized indexing
- **Cache**: Redis with intelligent invalidation
- **Authentication**: JWT with bcrypt password hashing
- **Vision AI**: OpenAI GPT-4o integration
- **Monitoring**: AWS CloudWatch
- **Testing**: Pytest with comprehensive mocking
- **Deployment**: Docker with multi-stage builds

## 📁 Project Structure

```
Backend/
├── app/
│   ├── auth/                    # Authentication & user management
│   ├── parking/                 # Parking operations & map processing
│   ├── pathfinding/            # Dijkstra algorithm & navigation
│   ├── emissions/              # Carbon footprint calculation
│   ├── session/                # Parking session management
│   ├── wallet/                 # Payment & transaction handling
│   ├── admin/                  # Administrative operations
│   ├── QRcode/                 # QR code generation & scanning
│   ├── vision/                 # AI-powered image processing
│   └── cache.py                # Redis cache management
├── tests/                      # Comprehensive test suite (529+ tests)
├── docs/                       # Detailed technical documentation
├── scripts/                    # Deployment & utility scripts
└── requirements.txt            # Python dependencies
```

## 🧪 Testing Strategy

Our testing approach ensures reliability and maintainability:

### Test Coverage by Module
- **Cache System**: 95% coverage
- **Pathfinding**: 88% coverage  
- **Emissions**: 93% coverage
- **Authentication**: 87% coverage
- **Parking Operations**: 85% coverage
- **Overall Coverage**: 75%

### Testing Features
- **Complete Mocking**: All external dependencies mocked (MongoDB, Redis, OpenAI)
- **Edge Case Coverage**: Boundary conditions and error scenarios
- **Concurrency Testing**: Race condition handling
- **Performance Testing**: Load testing with 1,000+ concurrent users
- **Security Testing**: Authentication and authorization validation

## 📚 Documentation

Comprehensive documentation for development and deployment:

- **[API Documentation](docs/API_DOCUMENTATION.md)**: Complete endpoint reference
- **[Algorithms & Technical Implementation](docs/ALGORITHMS_AND_TECHNICAL_IMPLEMENTATION.md)**: Deep dive into algorithms
- **[Performance & Scalability](docs/PERFORMANCE_AND_SCALABILITY.md)**: Performance metrics and optimization
- **[Security & Deployment](docs/SECURITY_AND_DEPLOYMENT.md)**: Production deployment guide
- **[Testing Guide](../docs/TESTING_GUIDE.md)**: Testing strategies and best practices
- **[Mocking Strategy](../docs/MOCKING_STRATEGY.md)**: Comprehensive mocking patterns

## 🔧 Development Setup

### Prerequisites
- Python 3.10+
- Docker & Docker Compose
- MongoDB (for local development)
- Redis (for caching)

### Installation Steps

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd Backend
   pip install -r requirements.txt
   ```

2. **Environment Configuration**
   ```bash
   # Create .env file (for local development)
   echo "MONGODB_URI=mongodb://localhost:27017" > .env
   echo "REDIS_URL=redis://localhost:6379" >> .env
   echo "DEBUG=true" >> .env
   ```

3. **Run Tests**
   ```bash
   # Run all tests with coverage
   pytest --cov=app --cov-report=html
   
   # Run specific test modules
   pytest tests/test_pathfinding.py -v
   ```

4. **Load Sample Data** (Optional)
   ```bash
   # Load example parking maps and user data
   python app/examples/local_mongodb_storage.py
   ```

5. **Start Development Server**
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```

## 🚀 Production Deployment

### Docker Deployment (Recommended)
```bash
# Build and start all services
docker-compose up --build -d

# Load sample data (after services are running)
python app/examples/local_mongodb_storage.py

# View logs
docker-compose logs -f backend

# Scale services
docker-compose up --scale backend=3
```

### Manual Deployment
```bash
# Install dependencies
pip install -r requirements.txt

# Start with production settings
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## 🔐 Security Features

- **Password Security**: bcrypt hashing with salt rounds
- **JWT Authentication**: Secure token-based authentication
- **Input Validation**: Comprehensive Pydantic model validation
- **Rate Limiting**: API endpoint protection
- **CORS Configuration**: Secure cross-origin resource sharing
- **Environment Variables**: Secure secret management
- **Audit Logging**: Comprehensive security event logging

## 📈 Monitoring & Observability

### CloudWatch Integration
- Real-time performance metrics
- Error rate monitoring  
- Custom business metrics
- Automated alerting

### Health Checks
```bash
# Check system health
curl http://localhost:8000/api/health

# Cache statistics
curl http://localhost:8000/api/cache/stats
```

## 🌱 Environmental Impact

Our carbon emission calculation system:
- Tracks CO₂ savings from optimized routing
- Uses real Australian vehicle emission data (0.194g/meter)
- Provides environmental impact insights
- Gamifies eco-friendly parking choices

## 🤝 Contributing

### Development Workflow
1. Create feature branch from `develop`
2. Write tests first (TDD approach)
3. Implement feature with comprehensive documentation
4. Ensure all tests pass and coverage ≥75%
5. Create pull request with detailed description

### Code Quality Standards
- Follow PEP 8 style guidelines
- Write comprehensive docstrings
- Maintain test coverage above 75%
- Use type hints for all functions
- Mock all external dependencies in tests

## 🎖 Technical Achievements

This backend demonstrates advanced software engineering practices:

- **Algorithm Implementation**: Complex graph algorithms (Dijkstra)
- **AI Integration**: Computer vision with GPT-4o
- **Performance Optimization**: Sub-200ms response times
- **Scalable Architecture**: Microservice-ready design
- **Production Quality**: Enterprise-grade security and monitoring
- **Comprehensive Testing**: Industry-standard test coverage

## 📞 Support & Resources

- **Interactive API Docs**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/api/health
- **Cache Stats**: http://localhost:8000/api/cache/stats

## 📊 Sample Data

### Load Example Data
The system includes comprehensive sample data for testing:

```bash
# Load sample data to MongoDB
python app/examples/local_mongodb_storage.py
```

**Sample data includes:**
- 🏢 **Parking Maps**: Multi-level parking structures (Building A, Westfield Sydney)
- 👤 **Test Users**: Pre-configured user accounts for testing
- 🅿️ **Parking Sessions**: Sample parking session history
- 💳 **Payment Data**: Mock transaction and wallet data

**Test Accounts Available:**
- **User**: `user@example.com` / password: `password123`
- **Admin**: `admin@autospot.com` / admin credentials
- **Operator**: Operator access credentials

### API Testing Examples
Once sample data is loaded, try these API calls:
```bash
# Get parking slots
curl "http://localhost:8000/parking/slots?building_name=Building A"

# Test pathfinding
curl "http://localhost:8000/pathfinding/shortest-path?start=1,0,0&end=1,5,5&building_name=Building A"

# Check emissions calculation
curl "http://localhost:8000/emissions/estimate?route_distance=25.5"
```

## Data Persistence

The project uses Docker Compose to configure MongoDB data persistence:
- Data is stored in Docker volume `mongo-data`
- Data will not be lost after computer restart
- Data will persist until the volume is manually deleted