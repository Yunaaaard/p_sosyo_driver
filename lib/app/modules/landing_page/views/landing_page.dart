import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/controllers/landing_controller.dart';

class LandingPage extends GetView<LandingController> {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/psosyo_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // Foreground Content
          Center(
            child: Image.asset(
              'assets/images/psosyo_driver_logo.png',
              width: 250,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}