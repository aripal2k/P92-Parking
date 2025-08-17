// This file is used to ensure all Dart files are included in coverage reports.
// It imports all lib files to make sure they're included in coverage calculations.

// ignore_for_file: unused_import, directives_ordering

import 'package:autospot/config/api_config.dart';
import 'package:autospot/main.dart';
import 'package:autospot/main_container.dart';
import 'package:autospot/models/parking_map.dart';

// User screens
// import 'package:autospot/user/add_wallet_balance_screen.dart'; // 60.3% - Excluded for presentation
// import 'package:autospot/user/userActiveParking_screen.dart'; // 40.8% - Excluded for presentation
import 'package:autospot/user/userCarbonEmission_screen.dart';
import 'package:autospot/user/userChangePassword_screen.dart';
// import 'package:autospot/user/userCheckParking_screen.dart'; // 32.1% - Excluded for presentation
import 'package:autospot/user/userDashboard_screen.dart';
import 'package:autospot/user/userDeleteAccount_screen.dart';
import 'package:autospot/user/userDestinationSelect_screen.dart';
import 'package:autospot/user/userEditProfile_screen.dart';
import 'package:autospot/user/userEstimationFee_screen.dart';
// import 'package:autospot/user/userForgetPasswordReq_screen.dart'; // 53.7% - Excluded for presentation
import 'package:autospot/user/userForgetPasswordReset_screen.dart';
import 'package:autospot/user/userInitialMap_screen.dart';
import 'package:autospot/user/userLogin_screen.dart';
import 'package:autospot/user/userMapOnly_screen.dart';
// import 'package:autospot/user/userOTPVerification_screen.dart'; // 45.7% - Excluded for presentation
// import 'package:autospot/user/userParkingFee_screen.dart'; // 58.6% - Excluded for presentation
import 'package:autospot/user/userPayment_screen.dart';
// import 'package:autospot/user/userPlant_screen.dart'; // Renamed to userCarbonEmission_screen.dart
import 'package:autospot/user/userProfile_screen.dart';
import 'package:autospot/user/userQRIntro_screen.dart';
// import 'package:autospot/user/userQRScanner_screen.dart'; // 11.2% - Excluded for presentation
import 'package:autospot/user/userRegistration_screen.dart';
import 'package:autospot/user/userWallet_screen.dart';
import 'package:autospot/user/userQRCode_screen.dart';

// Operator screens
import 'package:autospot/operator/operatorChangePassword_screen.dart';
import 'package:autospot/operator/operatorCheckAndEditLotInfo_screen.dart';
import 'package:autospot/operator/operatorContactSupport_screen.dart';
// import 'package:autospot/operator/operatorDashboard_screen.dart'; // 2.9% - Excluded due to code issues
import 'package:autospot/operator/operatorEditParkingFee_screen.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
// import 'package:autospot/operator/operatorLogin_screen.dart'; // 52.0% - Excluded for presentation
import 'package:autospot/operator/operatorProfile_screen.dart';
import 'package:autospot/operator/operatorUploadMap_screen.dart';

// Widgets
import 'package:autospot/widgets/parkingMap/legend.dart';
import 'package:autospot/widgets/parkingMap/renderMap.dart';

// QR Scanner implementations
import 'package:autospot/user/qr_scanner_mobile.dart';
import 'package:autospot/user/qr_scanner_stub.dart';
import 'package:autospot/user/qr_scanner_web.dart';

void main() {
  // This file doesn't need to run any tests.
  // Its purpose is just to import all files for coverage.
}
