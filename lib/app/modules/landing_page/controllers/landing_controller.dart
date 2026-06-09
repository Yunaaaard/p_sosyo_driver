import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/modules/login/views/login_page.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class LandingController extends GetxController {
  Timer? _timer;

  @override
  void onReady() async {
    super.onReady();
    
    // Check if the authenticated session is still active.
    final driver = await DatabaseService.to.getAuthenticatedDriver();
    
    if (driver != null) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      _timer = Timer(const Duration(seconds: 3), () {
        if (!Get.isRegistered<LoginController>()) {
          Get.put(LoginController());
        }

        Get.bottomSheet(
          const LoginPage(),
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.transparent,
          enableDrag: false,
          isDismissible: false,
        );
      });
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}