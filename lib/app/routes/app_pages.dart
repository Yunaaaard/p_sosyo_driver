import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/home/views/home_page.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/views/landing_page.dart';
import 'package:p_sosyo_driver/app/modules/login/views/login_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.landing,
      page: () => const LandingPage(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
    ),
  ];
}