class ApiConfig {
  // Environment configuration - set to true for local testing, false for production
  static const bool useLocalHost = true; 
  
  // Base URL switches between local and production based on environment
  static String get baseUrl => useLocalHost
    ? 'http://10.0.2.2:8000'  // Android emulator localhost
    : 'https://api.autospot.it.com'; // Production URL

  // Auth endpoints
  static String get loginEndpoint => '$baseUrl/auth/login';
  static String get registerEndpoint => '$baseUrl/auth/register';
  static String get registerRequestEndpoint => '$baseUrl/auth/register-request';
  static String get verifyOtpEndpoint => '$baseUrl/auth/verify-otp';
  static String get verifyRegistrationEndpoint => '$baseUrl/auth/verify-registration';
  static String get forgotPasswordEndpoint => '$baseUrl/auth/forgot-password';
  static String get verifyResetOtpEndpoint => '$baseUrl/auth/verify-reset-otp';
  static String get resetPasswordEndpoint => '$baseUrl/auth/reset-password';
  static String get changePasswordEndpoint => '$baseUrl/auth/change-password';
  static String get editProfileEndpoint => '$baseUrl/auth/edit-profile';
  static String get deleteAccountEndpoint => '$baseUrl/auth/delete-account';

  // User endpoints
  static String get getUserProfileEndpoint => '$baseUrl/auth/profile';
  static String get updateUserProfileEndpoint => '$baseUrl/auth/profile';

  // User Wallet
  static String getWalletBalanceEndpoint(String email) =>
    '$baseUrl/wallet/balance?email=$email';
  static String get addPaymentMethodEndpoint => '$baseUrl/wallet/payment-methods';
  static String getPaymentMethodsEndpoint(String email) =>
    '$baseUrl/wallet/payment-methods?email=$email';
  static String get addMoneyEndpoint => '$baseUrl/wallet/add-money';
  static Uri getTransactionHistoryEndpoint({
    required String email,
    int limit = 50,
    int offset = 0,
  }) {
    return Uri.parse('$baseUrl/wallet/transactions').replace(
      queryParameters: {
        'email': email,
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
  }

  static Uri payForParkingWithWalletEndpoint({
    required String email,
    required double amount,
    required String slotId,
    required String sessionId,
    required String buildingName,
  }) {
    return Uri.parse('$baseUrl/wallet/pay-parking').replace(
      queryParameters: {
        'email': email,
        'amount': amount.toString(),
        'slot_id': slotId,
        'session_id': sessionId,
        'building_name': buildingName,
      },
    );
  }

  // Pay Later
  static Uri getPayLaterEndpoint({
    required String email,
    required double amount,
    required String slotId,
    required String sessionId,
    required String buildingName,
    required DateTime startTime,
    required DateTime endTime,
    required Duration duration,
  }) {
    return Uri.parse('$baseUrl/wallet/pay-later').replace(
      queryParameters: {
        'email': email,
        'amount': amount.toString(),
        'slot_id': slotId,
        'session_id': sessionId,
        'building_name': buildingName,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration': duration.inMinutes.toString(), // Optional: cleaner format
      },
    );
  }
  static Uri getPendingPaymentsEndpoint({
    required String email,
    int limit = 50,
  }) {
    return Uri.parse('$baseUrl/wallet/pending-payments').replace(
      queryParameters: {
        'email': email,
        'limit': limit.toString(),
      },
    );
  }

  static Uri payPendingWithWalletEndpoint({
    required String email,
    required String transactionId,
  }) {
    return Uri.parse('$baseUrl/wallet/pay-pending-wallet').replace(
      queryParameters: {
        'email': email,
        'transaction_id': transactionId,
      },
    );
  }


  // Parking endpoints
  static String get getParkingMapsEndpoint => '$baseUrl/parking/maps';
  static String get uploadParkingMapEndpoint => '$baseUrl/parking/upload-map';
  static String getParkingMapByBuilding(String buildingName) => '$baseUrl/parking/maps/building/$buildingName';
  static String get predictFareEndpoint => '$baseUrl/parking/predict-fare';
  static String get getParkingRatesEndpoint => '$baseUrl/parking/rates'; // Endpoint to get parking rates
  
  // QR Code endpoints
  static String get generateEntranceQREndpoint => '$baseUrl/qr/generate-entrance-qr';
  static String get generateUserQREndpoint => '$baseUrl/qr/generate'; // Currently commented out in backend
  static String get validateQREndpoint => '$baseUrl/qr/validate';
  static String get listQREndpoint => '$baseUrl/qr/list';
  
  // Parking spot allocation endpoints
  static String get allocateSpotEndpoint => '$baseUrl/pathfinding/route-to-nearest-slot';
  static String get getAvailableDestinationsEndpoint => '$baseUrl/pathfinding/destinations';
  static String get shortestPathEndpoint => '$baseUrl/pathfinding/shortest-path';
  static String getNearestSlotEndpoint(String pointId) => '$baseUrl/pathfinding/nearest-slot/$pointId';

  // Session endpoint
  static String get startSessionEndpoint => '$baseUrl/session/start';
  static String get endSessionEndpoint => '$baseUrl/session/end';
  static String get sessionHistory => '$baseUrl/session/history';
  static String get clearAllSessionsEndpoint => '$baseUrl/session/clear-all';

  // Carbon emissions endpoint
  static String get emissionSession => '$baseUrl/emissions/estimate-session-journey';
  static String get emissionsHistory => '$baseUrl/emissions/history';
  static String estimateEmissionsForRouteEndpoint({
    required String buildingName,
    required String mapId,
    required bool useDynamicBaseline,
  }) {
    final encodedName = Uri.encodeComponent(buildingName);
    return '$baseUrl/emissions/estimate-for-route'
          '?building_name=$encodedName'
          '&map_id=$mapId'
          '&use_dynamic_baseline=$useDynamicBaseline';
  }

  // Subscription endpoints
  static String getSubscriptionStatusEndpoint(String email) =>
    '$baseUrl/subscription/status?email=$email';
  static String get subscriptionUpgradeEndpoint => '$baseUrl/subscription/upgrade';
  static String get subscriptionPricingEndpoint => '$baseUrl/subscription/pricing';

  // Admin endpoints
  static String get adminLoginEndpoint => '$baseUrl/admin/login';
  static String get adminDashboardEndpoint => '$baseUrl/admin/dashboard';
  static String get updateOperatorProfileEndpoint => '$baseUrl/admin/admin_edit_profile';
  static String get updateChangePasswordEndpoint => '$baseUrl/admin/admin_change_password';
  static String get editParkingFeeEndpoint => '$baseUrl/admin/admin_edit_parking_rate';

  // Common headers with some debug info
  static final Map<String, String> headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'AutoSpot-App/1.0',
    'Accept': 'application/json',
  };
}