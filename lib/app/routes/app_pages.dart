import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/end_of_day/bindings/end_of_day_binding.dart';
import 'package:p_sosyo_driver/app/modules/end_of_day/views/end_of_day_page.dart';
import 'package:p_sosyo_driver/app/modules/home/bindings/home_binding.dart';
import 'package:p_sosyo_driver/app/modules/home/views/home_page.dart';
import 'package:p_sosyo_driver/app/modules/login/bindings/login_binding.dart';
import 'package:p_sosyo_driver/app/modules/login/views/login_page.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/bindings/pin_verification_binding.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/views/pin_verification.dart';
import 'package:p_sosyo_driver/app/modules/order_details/bindings/order_details_binding.dart';
import 'package:p_sosyo_driver/app/modules/order_details/views/order_details.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/bindings/receipt_details_binding.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/views/delivery_summary_page.dart';
import 'package:p_sosyo_driver/app/modules/receipt_details/views/receipt_details.dart';
import 'package:p_sosyo_driver/app/modules/qr_scanner/bindings/qr_scanner_binding.dart';
import 'package:p_sosyo_driver/app/modules/qr_scanner/views/qr_scanner_page.dart';
import 'package:p_sosyo_driver/app/modules/route_calendar/bindings/route_calendar_binding.dart';
import 'package:p_sosyo_driver/app/modules/route_calendar/views/route_calendar_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
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
    GetPage(
      name: AppRoutes.orderDetails,
      page: () => const OrderDetailsPage(),
      binding: OrderDetailsBinding(),
    ),
    GetPage(
      name: AppRoutes.receiptDetails,
      page: () => const ReceiptDetailsPage(),
      binding: ReceiptDetailsBinding(),
    ),
    GetPage(
      name: AppRoutes.deliverySummary,
      page: () => const DeliverySummaryPage(),
    ),
    GetPage(
      name: AppRoutes.qrScanner,
      page: () => const QrScannerPage(),
      binding: QrScannerBinding(),
    ),
    GetPage(
      name: AppRoutes.endOfDay,
      page: () => const EndOfDayPage(),
      binding: EndOfDayBinding(),
    ),
    GetPage(
      name: AppRoutes.routeCalendar,
      page: () => const RouteCalendarPage(),
      binding: RouteCalendarBinding(),
    ),
  ];
}