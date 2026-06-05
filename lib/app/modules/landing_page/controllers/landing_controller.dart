import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/modules/login/views/login_page.dart';

class LandingController extends GetxController {
  Timer? _timer;

  @override
  void onReady() {
    super.onReady();
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

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}