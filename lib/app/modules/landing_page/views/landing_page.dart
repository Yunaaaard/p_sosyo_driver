import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/animations/fade_in_animation.dart';
import 'package:p_sosyo_driver/app/animations/scale_animation.dart';
import 'package:p_sosyo_driver/app/modules/landing_page/controllers/landing_controller.dart';

class LandingPage extends GetView<LandingController> {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image — fades in immediately
          Positioned.fill(
            child: FadeInAnimation(
              duration: const Duration(milliseconds: 1000),
              child: Image.asset(
                'assets/images/psosyo_background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Logo — fades in and scales up after a short delay
          Center(
            child: FadeInAnimation(
              duration: const Duration(milliseconds: 900),
              delay: const Duration(milliseconds: 400),
              child: ScaleInAnimation(
                duration: const Duration(milliseconds: 900),
                delay: const Duration(milliseconds: 400),
                beginScale: 0.6,
                curve: Curves.easeOutBack,
                child: Image.asset(
                  'assets/images/psosyo_driver_logo.png',
                  width: 250,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}