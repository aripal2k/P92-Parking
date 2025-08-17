import 'package:autospot/user/add_wallet_balance_screen.dart';
import 'package:autospot/user/userChangePassword_screen.dart';
import 'package:autospot/user/userCheckParking_screen.dart';
import 'package:autospot/user/userEditProfile_screen.dart';
import 'package:autospot/user/userEstimationFee_screen.dart';
import 'package:autospot/user/userProfile_screen.dart';
import 'package:autospot/user/userWallet_screen.dart';
import 'package:autospot/user/userParkingFee_screen.dart';
import 'package:autospot/user/userQRCode_screen.dart';
import 'package:autospot/user/userRegistration_screen.dart';
import 'package:autospot/user/userOTPVerification_screen.dart';
import 'package:autospot/user/userLogin_screen.dart';
import 'package:autospot/user/userForgetPasswordReq_screen.dart';
import 'package:autospot/user/userForgetPasswordReset_screen.dart';
import 'package:autospot/user/userDeleteAccount_screen.dart';
import 'package:autospot/user/userQRScanner_screen.dart';
import 'package:autospot/user/userQRIntro_screen.dart';  // Add QR intro screen
import 'package:autospot/user/userDestinationSelect_screen.dart';
import 'package:autospot/user/userActiveParking_screen.dart';
import 'package:autospot/user/userMapOnly_screen.dart';  // Add MapOnly screen
import 'package:autospot/user/userPayment_screen.dart';  // Add Payment screen
import 'package:autospot/user/userCarbonEmission_screen.dart';

import 'package:autospot/operator/operatorLogin_screen.dart';
import 'package:autospot/operator/operatorDashboard_screen.dart';
import 'package:autospot/operator/operatorContactSupport_screen.dart';
import 'package:autospot/operator/operatorProfile_screen.dart';
import 'package:autospot/operator/operatorEditProfile_screen.dart';
import 'package:autospot/operator/operatorChangePassword_screen.dart';
import 'package:autospot/operator/operatorEditParkingFee_screen.dart';
import 'package:autospot/operator/operatorUploadMap_screen.dart';

// Import the main container
import 'package:autospot/main_container.dart';
import 'package:autospot/screens/splash_screen.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:flutter/material.dart';

void main() {
  tz.initializeTimeZones();
  runApp(const MyApp());
}

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoSpot',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      navigatorObservers: [routeObserver],
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/verify-registration': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return VerifyOtpScreen(userData: args);
        },
        '/dashboard': (context) => const MainContainer(initialIndex: 0), // Main container as dashboard
        '/forgot-password': (context) => const ForgetPasswordRequestScreen(),
        '/reset-password': (context) => const ForgetPasswordResetScreen(),
        '/operator-login': (context) => const OperatorLoginScreen(),
        '/operator_dashboard': (context) => const OperatorDashboardScreen(),
        '/operator_profile': (context) => const OperatorProfileScreen(),
        '/operator_profile/edit': (context) => const OperatorEditProfileScreen(),
        '/operator_profile/change-password': (context) => const OperatorChangePasswordScreen(),
        '/operator_profile/edit_parking_fee': (context) => const OperatorEditParkingFeeScreen(),
        '/operator_profile/upload_map': (context) => const OperatorUploadMapScreen (),
        '/contact_support': (context) => const OperatorContactSupportScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/profile/change-password': (context) => const ChangePasswordScreen(),
        '/profile/edit': (context) => const EditProfileScreen(),
        '/profile/delete': (context) => const DeleteAccountScreen(),
        '/parking-map': (context) => const ParkingMapScreen(forceShowMap: true),
        '/wallet': (context) => const WalletScreen(),
        '/wallet/add-money': (context) => const AddBalanceScreen(),
        '/estimation-fee': (context) => const EstimationFeeScreen(),
        '/parking-fee': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args != null && args is Map) {
            return ParkingFeeScreen(
              startTime: args['startTime'] as DateTime?,
              isActiveSession: args['isActiveSession'] as bool? ?? false,
            );
          }
          return const ParkingFeeScreen();
        },
        '/qr-code': (context) => const QRCodeScreen(),
        '/qr-intro': (context) => const QRIntroScreen(),  // QR introduction screen
        '/qr-scanner': (context) => const QRScannerScreen(),
        '/carbon-emission': (context) => const UserCarbonEmissionScreen(),
        '/destination-select': (context) => const DestinationSelectScreen(),
        '/active-session': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          final dynamic startTimeArg = args['startTime'];
          final DateTime startTime = startTimeArg is String
              ? DateTime.parse(startTimeArg)
              : (startTimeArg as DateTime);
          return ActiveParkingScreen(startTime: startTime);
        },
        // New routes for direct access to main container with specified tab
        '/main': (context) => const MainContainer(initialIndex: 0),
        '/map': (context) => const MainContainer(initialIndex: 1),
        '/eco': (context) => const MainContainer(initialIndex: 2),
        '/parking-detail': (context) => const ParkingMapScreen(forceShowMap: true),
        '/map-only': (context) => const MapOnlyScreen(),
        '/payment': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return PaymentScreen(
              amount: args['amount'] as double,
              sessionId: args['sessionId'] as String,
              parkingLocation: args['parkingLocation'] as String,
              parkingSlot: args['parkingSlot'] as String,
              parkingDate: args['parkingDate'] as DateTime,
            );
          }
          // Fallback - shouldn't happen in normal flow
          return PaymentScreen(
            amount: 0.0,
            sessionId: 'unknown',
            parkingLocation: 'Unknown',
            parkingSlot: 'Unknown',
            parkingDate: DateTime.now(),
          );
        },
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
