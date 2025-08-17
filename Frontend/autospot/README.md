# AutoSpot - Smart Parking Solution

A comprehensive Flutter application for intelligent parking management, featuring real-time navigation, carbon emission tracking, and seamless user experience across mobile and web platforms.

## 🚀 Key Features

### Core Functionality
- **Smart Parking Navigation**: Dijkstra's algorithm-based shortest path routing
- **Real-time Updates**: Instant parking slot status updates without manual refresh
- **Carbon Emission Tracking**: Calculate CO₂ savings for sustainable parking
- **Multi-platform Support**: Flutter web, iOS, and Android applications
- **QR Code Integration**: Seamless entry and exit management

### User Experience
- **Interactive Parking Maps**: 20×20 grid layouts with realistic obstacles
- **Dynamic Pricing**: Time-based and demand-responsive fare calculation
- **Wallet Management**: Secure payment processing with multiple card support
- **Profile Management**: Comprehensive user account and vehicle information
- **Session Tracking**: Real-time parking session monitoring

### Operator Features
- **Map Management**: Upload and configure parking lot layouts
- **Fee Configuration**: Dynamic pricing and rate management
- **User Support**: Contact and assistance management
- **Analytics Dashboard**: Performance monitoring and insights

## 🏗️ Architecture

### Technology Stack
- **Framework**: Flutter 3.8.1+ with Dart SDK
- **State Management**: Provider pattern with shared preferences
- **HTTP Client**: Dio for API communication
- **QR Code**: Cross-platform QR scanning and generation
- **Testing**: Comprehensive test suite with 75%+ coverage

### Project Structure
```
lib/
├── main.dart                 # Application entry point
├── main_container.dart       # Main navigation container
├── config/                   # Configuration and API settings
├── models/                   # Data models and DTOs
├── user/                     # User-facing screens and features
├── operator/                 # Operator management screens
├── widgets/                  # Reusable UI components
│   └── parkingMap/           # Interactive parking map components
└── time_utils.dart           # Time utility functions
```

### Key Dependencies
- **image_picker**: Camera and gallery integration
- **http**: RESTful API communication
- **shared_preferences**: Local data persistence
- **qr_code_scanner**: QR code scanning capabilities
- **permission_handler**: Device permission management
- **timezone**: Time zone handling
- **intl**: Internationalization support

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / Xcode (for mobile development)
- VS Code (recommended for development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Frontend/autospot
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For web
   flutter run -d chrome
   
   # For mobile (iOS/Android)
   flutter run
   ```

### Development Setup

1. **Code Analysis**
   ```bash
   flutter analyze
   ```

2. **Run Tests**
   ```bash
   # Unit and widget tests
   flutter test
   
   # Integration tests
   flutter test integration_test/
   ```

3. **Generate Coverage Report**
   ```bash
   flutter test --coverage
   genhtml coverage/lcov.info -o coverage/html
   ```

## 🧪 Testing Strategy

### Test Coverage
- **Unit Tests**: Core business logic and utilities
- **Widget Tests**: UI component behavior and interactions
- **Integration Tests**: End-to-end user workflows
- **Mock Testing**: External dependencies and API calls

### Test Structure
```
test/
├── unit/                     # Unit tests for business logic
├── widget/                   # Widget and screen tests
├── helpers/                  # Test utilities and mocks
└── integration_test/         # End-to-end testing
```

### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/auth_service_test.dart

# Run with coverage
flutter test --coverage
```

## 📱 Platform Support

### Mobile Platforms
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+
- **Features**: Camera access, location services, push notifications

### Web Platform
- **Browsers**: Chrome, Firefox, Safari, Edge
- **Features**: Responsive design, PWA capabilities
- **Deployment**: AWS S3 static hosting with CDN

### Desktop Platforms
- **Windows**: Windows 10+
- **macOS**: macOS 10.15+
- **Linux**: Ubuntu 18.04+

## 🔧 Configuration

### Environment Setup
- **API Configuration**: `lib/config/api_config.dart`
- **Environment Variables**: Configure backend endpoints
- **Feature Flags**: Enable/disable specific features

### Build Configuration
- **Release Builds**: Optimized for production
- **Debug Builds**: Development and testing
- **Profile Builds**: Performance analysis

## 🚀 Deployment

### Web Deployment
```bash
# Build for web
flutter build web

# Deploy to S3 (using provided scripts)
./scripts/deploy_to_s3.sh
```

### Mobile Deployment
```bash
# Android APK
flutter build apk --release

# iOS Archive
flutter build ios --release
```

### CI/CD Pipeline
- **GitHub Actions**: Automated testing and deployment
- **Code Quality**: Linting and analysis checks
- **Test Coverage**: Minimum 75% coverage requirement

## 📊 Performance Metrics

### Key Performance Indicators
- **App Launch Time**: < 3 seconds
- **Screen Transition**: < 500ms
- **API Response**: < 2 seconds
- **Memory Usage**: < 150MB
- **Battery Efficiency**: Optimized for mobile devices

### Optimization Strategies
- **Lazy Loading**: On-demand resource loading
- **Image Optimization**: Compressed assets and caching
- **State Management**: Efficient state updates
- **Memory Management**: Proper disposal and cleanup

## 🔒 Security Features

### Data Protection
- **Secure Storage**: Encrypted local data
- **API Security**: HTTPS communication
- **Input Validation**: Comprehensive form validation
- **Permission Management**: Minimal required permissions

### Payment Security
- **Card Validation**: Industry-standard validation
- **Secure Communication**: Encrypted payment processing
- **Fraud Prevention**: Multiple validation layers

## 🌱 Sustainability Features

### Carbon Emission Tracking
- **Distance Calculation**: Actual vs. baseline routes
- **Emission Factors**: Australian vehicle standards
- **Environmental Impact**: CO2 savings display
- **User Awareness**: Sustainability education

## 🤝 Contributing

### Development Guidelines
1. **Code Style**: Follow Flutter and Dart conventions
2. **Testing**: Maintained 75%+ test coverage
3. **Documentation**: Updated README for new features
4. **Code Review**: All changes require review

### Pull Request Process
1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request
5. Address review feedback

## 📚 Documentation

### Additional Resources
- [Backend API Documentation](../Backend/docs/API_DOCUMENTATION.md)
- [Installation Manual](../Backend/docs/INSTALLATION_MANUAL.md)
- [Testing Guide](../docs/TESTING_GUIDE.md)
- [Architecture Overview](../Backend/docs/PERFORMANCE_AND_SCALABILITY.md)

### API Integration
- **Authentication**: JWT-based user sessions
- **Real-time Updates**: WebSocket communication
- **Data Synchronization**: Optimistic updates
- **Error Handling**: Comprehensive error management

## 🐛 Troubleshooting

### Common Issues
1. **Dependencies**: Run `flutter clean && flutter pub get`
2. **Build Errors**: Check Flutter and Dart versions
3. **Platform Issues**: Verify platform-specific requirements
4. **Test Failures**: Check test environment setup

### Support
- **Documentation**: Check this README and linked docs
- **Issues**: Report bugs via GitHub issues
- **Community**: Flutter community forums and Discord

## 📄 License

This project is part of the COMP3900 Capstone Project at the University of New South Wales (UNSW).

## 🙏 Acknowledgments

- **Flutter Team**: For the excellent cross-platform framework
- **University of New South Wales (UNSW)**: For academic support and guidance
- **Project Mentors**: For technical guidance and feedback
- **Open Source Community**: For the tools and libraries used

---

**Version**: 1.0.0  
**Last Updated**: August 2025  
**Maintainers**: AutoSpot Development Team
