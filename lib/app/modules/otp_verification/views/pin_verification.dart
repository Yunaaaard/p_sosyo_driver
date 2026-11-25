import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/controller/pin_verification_controller.dart';

class PinVerificationPage extends GetView<PinVerificationController> {
  const PinVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Clean Rounded Step Progress (No Back Navigation)
              _buildTopBar(),

              // 2. Centered Passcode Header & 6 Rounded Slots
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildPinSlots(reduceMotion),
                        const SizedBox(height: AppSpacing.md),
                        Obx(() {
                          if (controller.isVerifyMode.value) {
                            return SizedBox(
                              height: 36,
                              child: TextButton.icon(
                                onPressed: controller.switchAccount,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: AppColors.inkSecondary,
                                ),
                                label: Text(
                                  'Switch account',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (!controller.isConfirming.value) {
                            return const SizedBox(height: 36);
                          }
                          return SizedBox(
                            height: 36,
                            child: TextButton.icon(
                              onPressed: controller.reset,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                'Change first passcode',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Clean Rounded Numeric Keypad Tray (No Grid Lines)
              _buildKeypadDeck(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Obx(() {
        if (controller.isVerifyMode.value) {
          return const SizedBox.shrink();
        }

        final stepTwo = controller.isConfirming.value;
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: stepTwo ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                stepTwo ? 'STEP 2 / 2' : 'STEP 1 / 2',
                style: AppTypography.micro.copyWith(
                  fontSize: 14,
                  color: AppColors.inkSecondary,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: SvgPicture.asset(
            AppConstants.paqnerLogoAsset,
            width: 34,
            height: 26,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Obx(
          () => Text(
            controller.isVerifyMode.value
                ? 'Enter Passcode'
                : controller.isConfirming.value
                    ? 'Confirm Passcode'
                    : 'Set New Passcode',
            textAlign: TextAlign.center,
            style: AppTypography.display.copyWith(fontSize: 30),
          ),
        ),
        const SizedBox(height: 6),
        Obx(
          () => Text(
            controller.isVerifyMode.value
                ? 'Enter your 6-digit passcode to unlock your driver session.'
                : controller.isConfirming.value
                    ? 'Re-enter your 6-digit passcode to confirm.'
                    : 'Create a 6-digit passcode to lock your driver session.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: 18,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinSlots(bool reduceMotion) {
    return Obx(() {
      final isConfirm = controller.isConfirming.value;
      final value =
          isConfirm ? controller.confirmPin.value : controller.pin.value;

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(PinVerificationController.pinLength, (index) {
            final hasDigit = index < value.length;
            final isActive = index == value.length;

            return AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              width: 44,
              height: 54,
              decoration: BoxDecoration(
                color: hasDigit ? AppColors.primaryTint : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: isActive || hasDigit
                      ? AppColors.primary
                      : AppColors.borderStrong,
                  width: isActive ? 2.0 : 1.3,
                ),
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: hasDigit
                    ? Container(
                        key: ValueKey('dot_${isConfirm ? "c" : "p"}_$index'),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : SizedBox(
                        key: ValueKey('empty_${isConfirm ? "c" : "p"}_$index'),
                      ),
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _buildKeypadDeck() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Obx(
        () => AbsorbPointer(
          absorbing: controller.isSaving.value || controller.isInputLocked.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeypadRow(['1', '2', '3']),
              const SizedBox(height: AppSpacing.sm),
              _buildKeypadRow(['4', '5', '6']),
              const SizedBox(height: AppSpacing.sm),
              _buildKeypadRow(['7', '8', '9']),
              const SizedBox(height: AppSpacing.sm),
              _buildBottomKeypadRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      children: [
        for (int i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          _buildNumberKey(digits[i]),
        ],
      ],
    );
  }

  Widget _buildBottomKeypadRow() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                controller.deleteDigit();
              },
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: const SizedBox(
                height: 56,
                child: Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    color: AppColors.inkSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildNumberKey('0'),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Obx(() {
            final isReady = (controller.isConfirming.value
                    ? controller.confirmPin.value.length
                    : controller.pin.value.length) ==
                PinVerificationController.pinLength;
            final isSaving = controller.isSaving.value;

            return Material(
              color: isReady ? AppColors.primary : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                onTap: isReady && !isSaving ? controller.submitPin : null,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Icon(
                            Icons.arrow_forward_rounded,
                            color: isReady ? Colors.white : AppColors.inkSubtle,
                            size: 24,
                          ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNumberKey(String digit) {
    return Expanded(
      child: Material(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            controller.addDigit(digit);
          },
          borderRadius: BorderRadius.circular(AppRadii.md),
          splashColor: AppColors.primary.withOpacity(0.12),
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                digit,
                style: AppTypography.display.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
