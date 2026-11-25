import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/landing/controller/landing_controller.dart';
import 'package:video_player/video_player.dart';

class LandingPage extends GetView<LandingController> {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        if (!controller.isVideoReady.value) {
          return const SizedBox.expand();
        }
        final size = controller.videoController.value.size;
        return SafeArea(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.84,
              heightFactor: 0.84,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(controller.videoController),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
