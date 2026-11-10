import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    this.title = 'PSOSYO',
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDefaultLogo = title == 'PSOSYO';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEBEBEB),
            width: 1.0,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF8A8F99),
                  size: 20,
                ),
                onPressed: () => Get.back(),
              )
            : null,
        title: isDefaultLogo
            ? HoldablePsosyoLogo(
                onLongHold: () => _showAdminLogoutDialog(context),
              )
            : Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF2F333A),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _showAdminLogoutDialog(BuildContext context) {
    final passController = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Enter Admin Password',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F333A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter password to clear data and logout.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFF8A8F99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: isObscured,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFB8BCC5),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F6F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: const Color(0xFF8A8F99),
                        ),
                        onPressed: () {
                          setState(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF8A8F99),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final entered = passController.text.trim();
                    if (entered == 'k1m123' || kDebugMode) {
                      Navigator.pop(dialogContext);
                      await DatabaseService.to.logoutAndClearData();
                    } else {
                      Get.snackbar(
                        'Access Denied',
                        'Invalid password.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFFFFEBEB),
                        colorText: const Color(0xFFD32F2F),
                        margin: const EdgeInsets.all(16),
                        borderRadius: 12,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6533E7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class HoldablePsosyoLogo extends StatefulWidget {
  final VoidCallback onLongHold;
  final Duration holdDuration;

  const HoldablePsosyoLogo({
    super.key,
    required this.onLongHold,
    this.holdDuration = const Duration(seconds: 3),
  });

  @override
  State<HoldablePsosyoLogo> createState() => _HoldablePsosyoLogoState();
}

class _HoldablePsosyoLogoState extends State<HoldablePsosyoLogo>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startHold() {
    _animController.forward(from: 0.0);
    _timer?.cancel();
    _timer = Timer(widget.holdDuration, () {
      HapticFeedback.heavyImpact();
      _animController.reset();
      widget.onLongHold();
    });
  }

  void _cancelHold() {
    _timer?.cancel();
    _timer = null;
    if (_animController.isAnimating || _animController.value > 0) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: () => _cancelHold(),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = 1.0 - (_animController.value * 0.08);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: const Text(
          'PSOSYO',
          style: TextStyle(
            fontFamily: 'ITTENOVIANADEMO',
            color: Color(0xFF6533E7),
            fontSize: 26,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
