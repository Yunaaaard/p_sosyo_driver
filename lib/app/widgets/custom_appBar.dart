import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final Widget? trailing;

  const CustomAppBar({
    super.key,
    this.title = 'PSOSYO',
    this.showBackButton = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDefaultLogo = title == 'PSOSYO';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showBackButton)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AppBarIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Get.back(),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: showBackButton ? 52 : 24,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: isDefaultLogo
                        ? HoldablePsosyoLogo(
                            onLongHold: () => _showAdminLogoutDialog(context),
                          )
                        : Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading.copyWith(fontSize: 23),
                          ),
                  ),
                ),
                if (trailing != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
              ],
            ),
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
            return Dialog(
              backgroundColor: AppColors.surface,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xxl,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Verification',
                                style: AppTypography.title,
                              ),
                              Text(
                                'Clear local data and end session',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: passController,
                      obscureText: isObscured,
                      autofocus: true,
                      style: AppTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Enter admin password',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.inkSubtle,
                        ),
                        filled: true,
                        fillColor: AppColors.canvas,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.inkMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              isObscured = !isObscured;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.inkSecondary,
                              side: const BorderSide(
                                  color: AppColors.borderStrong),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              'Cancel',
                              style: AppTypography.label.copyWith(
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
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
                                  backgroundColor: AppColors.dangerTint,
                                  colorText: AppColors.danger,
                                  margin: const EdgeInsets.all(16),
                                  borderRadius: 12,
                                  duration: const Duration(seconds: 2),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadii.md),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Text(
                              'Confirm',
                              style: AppTypography.label.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              color: AppColors.inkPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class HoldablePsosyoLogo extends StatefulWidget {
  final VoidCallback onLongHold;
  final Duration holdDuration;

  const HoldablePsosyoLogo({
    super.key,
    required this.onLongHold,
    this.holdDuration = AppConstants.adminHoldDuration,
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
          final scale = 1.0 - (_animController.value * 0.06);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: scale,
                child: child,
              ),
              if (_animController.value > 0.02)
                Positioned(
                  bottom: -4,
                  child: SizedBox(
                    width: 64,
                    height: 2,
                    child: LinearProgressIndicator(
                      value: _animController.value,
                      backgroundColor: AppColors.primaryTint,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: SizedBox(
          width: 140.4,
          height: 24,
          child: SvgPicture.asset(
            AppConstants.appBarLogoAsset,
            width: 140.4,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
