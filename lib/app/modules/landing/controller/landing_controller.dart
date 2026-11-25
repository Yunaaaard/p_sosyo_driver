import 'dart:async';

import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/utils/app_logger.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';
import 'package:video_player/video_player.dart';

class LandingController extends GetxController {
  late final VideoPlayerController videoController;
  final RxBool isVideoReady = false.obs;

  Timer? _fallbackTimer;
  bool _hasNavigated = false;

  @override
  void onInit() {
    super.onInit();
    _initVideo();
  }

  Future<void> _initVideo() async {
    videoController =
        VideoPlayerController.asset('assets/videos/landing_intro.mp4');

    // Safety timer in case video decoding stalls on low-end devices
    _fallbackTimer = Timer(const Duration(milliseconds: 5600), _navigateNext);

    try {
      await videoController.initialize();
      await videoController.setVolume(1.0);
      await videoController.setLooping(false);
      isVideoReady.value = true;
      videoController.addListener(_onVideoProgress);
      await videoController.play();
    } catch (e, stack) {
      logError('Error playing landing_intro.mp4', e, stack);
      _navigateNext();
    }
  }

  void _onVideoProgress() {
    if (_hasNavigated || !videoController.value.isInitialized) return;
    final dur = videoController.value.duration;
    final pos = videoController.value.position;
    if (dur > Duration.zero && pos >= dur) {
      _navigateNext();
    }
  }

  Future<void> skipToNext() async => _navigateNext();

  Future<void> _navigateNext() async {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _fallbackTimer?.cancel();

    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void onClose() {
    _fallbackTimer?.cancel();
    videoController.removeListener(_onVideoProgress);
    videoController.dispose();
    super.onClose();
  }
}
