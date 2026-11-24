import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/cash_remittance/bindings/cash_remittance_binding.dart';
import 'package:p_sosyo_driver/app/modules/cash_remittance/views/cash_remittance_page.dart';
import 'package:p_sosyo_driver/app/modules/delivery_map/bindings/delivery_map_binding.dart';
import 'package:p_sosyo_driver/app/modules/delivery_map/views/delivery_map_page.dart';
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
import 'package:p_sosyo_driver/app/modules/route_planner/bindings/route_planner_binding.dart';
import 'package:p_sosyo_driver/app/modules/route_planner/views/route_planner_page.dart';
import 'package:p_sosyo_driver/app/modules/sync_queue/bindings/sync_queue_binding.dart';
import 'package:p_sosyo_driver/app/modules/sync_queue/views/sync_queue_page.dart';
import 'package:p_sosyo_driver/app/modules/van_loadout/bindings/van_loadout_binding.dart';
import 'package:p_sosyo_driver/app/modules/van_loadout/views/van_loadout_page.dart';
import 'app_routes.dart';

class AppPages {
  static GetPage<dynamic> _smoothPage({
    required String name,
    required GetPageBuilder page,
    Bindings? binding,
  }) {
    return GetPage(
      name: name,
      page: page,
      binding: binding,
      transition: Transition.rightToLeftWithFade,
      curve: Curves.easeOutCubic,
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  static final pages = [
    _smoothPage(
      name: AppRoutes.login,
      page: () => const LoginPage(),
      binding: LoginBinding(),
    ),
    _smoothPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    _smoothPage(
      name: AppRoutes.pinVerification,
      page: () => const PinVerificationPage(),
      binding: PinVerificationBinding(),
    ),
    _smoothPage(
      name: AppRoutes.orderDetails,
      page: () => const OrderDetailsPage(),
      binding: OrderDetailsBinding(),
    ),
    _smoothPage(
      name: AppRoutes.receiptDetails,
      page: () => const ReceiptDetailsPage(),
      binding: ReceiptDetailsBinding(),
    ),
    _smoothPage(
      name: AppRoutes.deliverySummary,
      page: () => const DeliverySummaryPage(),
    ),
    _smoothPage(
      name: AppRoutes.qrScanner,
      page: () => const QrScannerPage(),
      binding: QrScannerBinding(),
    ),
    _smoothPage(
      name: AppRoutes.endOfDay,
      page: () => const EndOfDayPage(),
      binding: EndOfDayBinding(),
    ),
    _smoothPage(
      name: AppRoutes.routeCalendar,
      page: () => const RouteCalendarPage(),
      binding: RouteCalendarBinding(),
    ),
    _smoothPage(
      name: AppRoutes.routePlanner,
      page: () => const RoutePlannerPage(),
      binding: RoutePlannerBinding(),
    ),
    _smoothPage(
      name: AppRoutes.vanLoadout,
      page: () => const VanLoadoutPage(),
      binding: VanLoadoutBinding(),
    ),
    _smoothPage(
      name: AppRoutes.cashRemittance,
      page: () => const CashRemittancePage(),
      binding: CashRemittanceBinding(),
    ),
    _smoothPage(
      name: AppRoutes.syncQueue,
      page: () => const SyncQueuePage(),
      binding: SyncQueueBinding(),
    ),
    _smoothPage(
      name: AppRoutes.deliveryMap,
      page: () => const DeliveryMapPage(),
      binding: DeliveryMapBinding(),
    ),
  ];
}