import 'package:flutter_test/flutter_test.dart';
import 'package:autospot/config/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('baseUrl returns correct URL based on useLocalHost', () {
      // Since useLocalHost is const, we can only test the current value
      if (ApiConfig.useLocalHost) {
        expect(ApiConfig.baseUrl, 'http://10.0.2.2:8000');
      } else {
        expect(ApiConfig.baseUrl, 'https://api.autospot.it.com');
      }
    });

    group('Auth Endpoints', () {
      test('login endpoint is correctly formed', () {
        expect(ApiConfig.loginEndpoint, '${ApiConfig.baseUrl}/auth/login');
      });

      test('register endpoint is correctly formed', () {
        expect(ApiConfig.registerEndpoint, '${ApiConfig.baseUrl}/auth/register');
      });

      test('register request endpoint is correctly formed', () {
        expect(ApiConfig.registerRequestEndpoint, '${ApiConfig.baseUrl}/auth/register-request');
      });

      test('verify OTP endpoint is correctly formed', () {
        expect(ApiConfig.verifyOtpEndpoint, '${ApiConfig.baseUrl}/auth/verify-otp');
      });

      test('verify registration endpoint is correctly formed', () {
        expect(ApiConfig.verifyRegistrationEndpoint, '${ApiConfig.baseUrl}/auth/verify-registration');
      });

      test('forgot password endpoint is correctly formed', () {
        expect(ApiConfig.forgotPasswordEndpoint, '${ApiConfig.baseUrl}/auth/forgot-password');
      });

      test('verify reset OTP endpoint is correctly formed', () {
        expect(ApiConfig.verifyResetOtpEndpoint, '${ApiConfig.baseUrl}/auth/verify-reset-otp');
      });

      test('reset password endpoint is correctly formed', () {
        expect(ApiConfig.resetPasswordEndpoint, '${ApiConfig.baseUrl}/auth/reset-password');
      });

      test('change password endpoint is correctly formed', () {
        expect(ApiConfig.changePasswordEndpoint, '${ApiConfig.baseUrl}/auth/change-password');
      });

      test('edit profile endpoint is correctly formed', () {
        expect(ApiConfig.editProfileEndpoint, '${ApiConfig.baseUrl}/auth/edit-profile');
      });

      test('delete account endpoint is correctly formed', () {
        expect(ApiConfig.deleteAccountEndpoint, '${ApiConfig.baseUrl}/auth/delete-account');
      });
    });

    group('User Endpoints', () {
      test('get user profile endpoint is correctly formed', () {
        expect(ApiConfig.getUserProfileEndpoint, '${ApiConfig.baseUrl}/auth/profile');
      });

      test('update user profile endpoint is correctly formed', () {
        expect(ApiConfig.updateUserProfileEndpoint, '${ApiConfig.baseUrl}/auth/profile');
      });
    });

    group('Wallet Endpoints', () {
      test('wallet balance endpoint is correctly formed with email', () {
        const email = 'test@example.com';
        expect(
          ApiConfig.getWalletBalanceEndpoint(email),
          '${ApiConfig.baseUrl}/wallet/balance?email=$email',
        );
      });

      test('add payment method endpoint is correctly formed', () {
        expect(ApiConfig.addPaymentMethodEndpoint, '${ApiConfig.baseUrl}/wallet/payment-methods');
      });

      test('get payment methods endpoint is correctly formed with email', () {
        const email = 'test@example.com';
        expect(
          ApiConfig.getPaymentMethodsEndpoint(email),
          '${ApiConfig.baseUrl}/wallet/payment-methods?email=$email',
        );
      });

      test('add money endpoint is correctly formed', () {
        expect(ApiConfig.addMoneyEndpoint, '${ApiConfig.baseUrl}/wallet/add-money');
      });
    });

    group('Parking Endpoints', () {
      test('get parking maps endpoint is correctly formed', () {
        expect(ApiConfig.getParkingMapsEndpoint, '${ApiConfig.baseUrl}/parking/maps');
      });

      test('upload parking map endpoint is correctly formed', () {
        expect(ApiConfig.uploadParkingMapEndpoint, '${ApiConfig.baseUrl}/parking/upload-map');
      });

      test('get parking map by building is correctly formed', () {
        const buildingName = 'Building A';
        expect(
          ApiConfig.getParkingMapByBuilding(buildingName),
          '${ApiConfig.baseUrl}/parking/maps/building/$buildingName',
        );
      });

      test('predict fare endpoint is correctly formed', () {
        expect(ApiConfig.predictFareEndpoint, '${ApiConfig.baseUrl}/parking/predict-fare');
      });

      test('get parking rates endpoint is correctly formed', () {
        expect(ApiConfig.getParkingRatesEndpoint, '${ApiConfig.baseUrl}/parking/rates');
      });
    });

    group('QR Code Endpoints', () {
      test('generate entrance QR endpoint is correctly formed', () {
        expect(ApiConfig.generateEntranceQREndpoint, '${ApiConfig.baseUrl}/qr/generate-entrance-qr');
      });

      test('generate user QR endpoint is correctly formed', () {
        expect(ApiConfig.generateUserQREndpoint, '${ApiConfig.baseUrl}/qr/generate');
      });

      test('validate QR endpoint is correctly formed', () {
        expect(ApiConfig.validateQREndpoint, '${ApiConfig.baseUrl}/qr/validate');
      });

      test('list QR endpoint is correctly formed', () {
        expect(ApiConfig.listQREndpoint, '${ApiConfig.baseUrl}/qr/list');
      });
    });

    group('Parking Spot Allocation Endpoints', () {
      test('allocate spot endpoint is correctly formed', () {
        expect(ApiConfig.allocateSpotEndpoint, '${ApiConfig.baseUrl}/pathfinding/route-to-nearest-slot');
      });

      test('get available destinations endpoint is correctly formed', () {
        expect(ApiConfig.getAvailableDestinationsEndpoint, '${ApiConfig.baseUrl}/pathfinding/destinations');
      });

      test('shortest path endpoint is correctly formed', () {
        expect(ApiConfig.shortestPathEndpoint, '${ApiConfig.baseUrl}/pathfinding/shortest-path');
      });

      test('get nearest slot endpoint is correctly formed with point ID', () {
        const pointId = 'P123';
        expect(
          ApiConfig.getNearestSlotEndpoint(pointId),
          '${ApiConfig.baseUrl}/pathfinding/nearest-slot/$pointId',
        );
      });
    });

    group('Session Endpoints', () {
      test('start session endpoint is correctly formed', () {
        expect(ApiConfig.startSessionEndpoint, '${ApiConfig.baseUrl}/session/start');
      });

      test('end session endpoint is correctly formed', () {
        expect(ApiConfig.endSessionEndpoint, '${ApiConfig.baseUrl}/session/end');
      });

      test('clear all sessions endpoint is correctly formed', () {
        expect(ApiConfig.clearAllSessionsEndpoint, '${ApiConfig.baseUrl}/session/clear-all');
      });
    });

    group('Carbon Emissions Endpoint', () {
      test('estimate emissions endpoint is correctly formed with all parameters', () {
        const buildingName = 'Test Building';
        const mapId = 'map123';
        const useDynamicBaseline = true;

        final endpoint = ApiConfig.estimateEmissionsForRouteEndpoint(
          buildingName: buildingName,
          mapId: mapId,
          useDynamicBaseline: useDynamicBaseline,
        );

        expect(
          endpoint,
          '${ApiConfig.baseUrl}/emissions/estimate-for-route'
          '?building_name=${Uri.encodeComponent(buildingName)}'
          '&map_id=$mapId'
          '&use_dynamic_baseline=$useDynamicBaseline',
        );
      });

      test('estimate emissions endpoint correctly encodes special characters', () {
        const buildingName = 'Building & Co.';
        const mapId = 'map123';
        const useDynamicBaseline = false;

        final endpoint = ApiConfig.estimateEmissionsForRouteEndpoint(
          buildingName: buildingName,
          mapId: mapId,
          useDynamicBaseline: useDynamicBaseline,
        );

        expect(endpoint.contains('Building%20%26%20Co.'), true);
      });
    });

    group('Admin Endpoints', () {
      test('admin login endpoint is correctly formed', () {
        expect(ApiConfig.adminLoginEndpoint, '${ApiConfig.baseUrl}/admin/login');
      });

      test('admin dashboard endpoint is correctly formed', () {
        expect(ApiConfig.adminDashboardEndpoint, '${ApiConfig.baseUrl}/admin/dashboard');
      });

      test('update operator profile endpoint is correctly formed', () {
        expect(ApiConfig.updateOperatorProfileEndpoint, '${ApiConfig.baseUrl}/admin/admin_edit_profile');
      });

      test('update change password endpoint is correctly formed', () {
        expect(ApiConfig.updateChangePasswordEndpoint, '${ApiConfig.baseUrl}/admin/admin_change_password');
      });

      test('edit parking fee endpoint is correctly formed', () {
        expect(ApiConfig.editParkingFeeEndpoint, '${ApiConfig.baseUrl}/admin/admin_edit_parking_rate');
      });
    });

    group('Common Headers', () {
      test('headers contain correct content type', () {
        expect(ApiConfig.headers['Content-Type'], 'application/json');
      });

      test('headers contain user agent', () {
        expect(ApiConfig.headers['User-Agent'], 'AutoSpot-App/1.0');
      });

      test('headers contain accept type', () {
        expect(ApiConfig.headers['Accept'], 'application/json');
      });

      test('headers map has exactly 3 entries', () {
        expect(ApiConfig.headers.length, 3);
      });
    });

    group('URL Parameter Handling', () {
      test('handles email with special characters in wallet balance endpoint', () {
        const email = 'test+user@example.com';
        final endpoint = ApiConfig.getWalletBalanceEndpoint(email);
        expect(endpoint.contains(email), true);
      });

      test('handles building name with spaces', () {
        const buildingName = 'Building Name With Spaces';
        final endpoint = ApiConfig.getParkingMapByBuilding(buildingName);
        expect(endpoint.contains(buildingName), true);
      });

      test('handles point ID with special characters', () {
        const pointId = 'point-123_test';
        final endpoint = ApiConfig.getNearestSlotEndpoint(pointId);
        expect(endpoint.contains(pointId), true);
      });
    });
  });
}