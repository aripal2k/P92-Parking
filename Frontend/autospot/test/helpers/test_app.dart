import 'package:flutter/material.dart';
import 'package:autospot/main.dart';
import 'package:autospot/user/userLogin_screen.dart';
import 'package:autospot/user/userRegistration_screen.dart';
import 'package:autospot/user/userOTPVerification_screen.dart';
import 'package:autospot/user/userForgetPasswordReq_screen.dart';
import 'package:autospot/user/userForgetPasswordReset_screen.dart';
import 'package:autospot/user/userDestinationSelect_screen.dart';
import 'package:autospot/user/userCheckParking_screen.dart';
import 'package:autospot/user/userActiveParking_screen.dart';
import 'package:autospot/user/userParkingFee_screen.dart';
import 'package:autospot/user/userPayment_screen.dart';
import 'package:autospot/user/userWallet_screen.dart';
import 'package:autospot/user/userProfile_screen.dart';
import 'package:autospot/user/userEditProfile_screen.dart';
import 'package:autospot/user/userChangePassword_screen.dart';
import 'package:autospot/user/userDeleteAccount_screen.dart';
import 'package:autospot/user/userQRCode_screen.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'package:autospot/user/userQRIntro_screen.dart';
import 'package:autospot/user/userMapOnly_screen.dart';
import 'package:autospot/user/userEstimationFee_screen.dart';
import 'package:autospot/user/userCarbonEmission_screen.dart';
import 'package:autospot/user/add_wallet_balance_screen.dart';
import 'package:autospot/operator/operatorLogin_screen.dart';
import 'package:autospot/operator/operatorDashboard_screen.dart';
import 'package:autospot/operator/operatorContactSupport_screen.dart';
import 'package:autospot/operator/operatorProfile_screen.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
import 'package:autospot/operator/operatorChangePassword_screen.dart';
import 'package:autospot/operator/operatorEditParkingFee_screen.dart';
import 'package:autospot/operator/operatorUploadMap_screen.dart';
import 'package:autospot/main_container.dart';

/// Test version of MyApp that skips SplashScreen and goes directly to LoginScreen
class TestMyApp extends StatelessWidget {
  const TestMyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoSpot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      navigatorObservers: [routeObserver],
      routes: {
        '/': (context) => const LoginScreen(), // Skip SplashScreen in tests
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainContainer(initialIndex: 0),
        '/register': (context) => const RegistrationScreen(),
        '/verify-registration': (context) => VerifyOtpScreen(userData: const {}),
        '/dashboard': (context) => const MainContainer(initialIndex: 0),
        '/forgot-password': (context) => const ForgetPasswordRequestScreen(),
        '/reset-password': (context) => const ForgetPasswordResetScreen(),
        '/destination-select': (context) => const DestinationSelectScreen(),
        '/parking-map': (context) => const ParkingMapScreen(forceShowMap: true),
        '/map': (context) => const MainContainer(initialIndex: 1),
        '/eco': (context) => const MainContainer(initialIndex: 2),
        '/qr': (context) => const MainContainer(initialIndex: 3),
        '/wallet': (context) => const MainContainer(initialIndex: 4),
        '/profile': (context) => const MainContainer(initialIndex: 5),
        '/parking-fee': (context) => const ParkingFeeScreen(),
        '/active-session': (context) => ActiveParkingScreen(startTime: DateTime.now()),
        '/payment': (context) => PaymentScreen(
          amount: 0.0,
          sessionId: '',
          parkingLocation: '',
          parkingSlot: '',
          parkingDate: DateTime.now(),
        ),
        '/wallet/add-money': (context) => const AddBalanceScreen(),
        '/profile/user': (context) => const ProfileScreen(),
        '/profile/change-password': (context) => const ChangePasswordScreen(),
        '/profile/edit': (context) => const EditProfileScreen(),
        '/profile/delete': (context) => const DeleteAccountScreen(),
        '/qr-code': (context) => const QRCodeScreen(),
        '/qr-scanner': (context) => const QRScannerScreen(),
        '/qr-intro': (context) => const QRIntroScreen(),
        '/map-only': (context) => const MapOnlyScreen(),
        '/estimation-fee': (context) => const EstimationFeeScreen(),
        '/carbon-emission': (context) => const UserCarbonEmissionScreen(),
        '/operator-login': (context) => const OperatorLoginScreen(),
        '/operator/login': (context) => const OperatorLoginScreen(),
        '/operator_dashboard': (context) => const OperatorDashboardScreen(),
        '/operator/dashboard': (context) => const OperatorDashboardScreen(),
        '/contact_support': (context) => const OperatorContactSupportScreen(),
        '/operator/contact-support': (context) => const OperatorContactSupportScreen(),
        '/operator_profile': (context) => const OperatorProfileScreen(),
        '/operator/profile': (context) => const OperatorProfileScreen(),
        '/operator_profile/edit': (context) => const OperatorEditProfileScreen(),
        '/operator/profile/edit': (context) => const OperatorEditProfileScreen(),
        '/operator_profile/change-password': (context) => const OperatorChangePasswordScreen(),
        '/operator/profile/change-password': (context) => const OperatorChangePasswordScreen(),
        '/operator_profile/edit_parking_fee': (context) => const OperatorEditParkingFeeScreen(),
        '/operator/edit-parking-fee': (context) => const OperatorEditParkingFeeScreen(),
        '/operator_profile/upload_map': (context) => const OperatorUploadMapScreen(),
        '/operator/upload-map': (context) => const OperatorUploadMapScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}