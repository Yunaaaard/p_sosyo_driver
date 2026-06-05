import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/bindings/landing_binding.dart';
import 'package:p_sosyo_driver/app/modules/home/bindings/home_binding.dart';
import 'package:p_sosyo_driver/app/modules/home/views/home_page.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/views/landing_page.dart';
import 'package:p_sosyo_driver/app/modules/login/bindings/login_binding.dart';
import 'package:p_sosyo_driver/app/modules/login/views/login_page.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/bindings/pin_verification_binding.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/views/pin_verification.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.landing,
      page: () => const LandingPage(),
      binding: LandingBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.pinVerification,
      page: () => const PinVerificationPage(),
      binding: PinVerificationBinding(),
    ),
  ];
}