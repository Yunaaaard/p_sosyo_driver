import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/controller/pin_verification_controller.dart';

class PinVerificationPage extends GetView<PinVerificationController> {
  const PinVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/psosyo_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Subtle Dark Vignette at Top
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // 3. Top Navigation Bar (Back Button)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        if (controller.isConfirming.value) {
                          controller.reset();
                        } else {
                          Get.back();
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.isConfirming.value
                                ? Icons.verified_user_outlined
                                : Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            controller.isConfirming.value
                                ? 'Step 2 of 2'
                                : 'Step 1 of 2',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Card Container
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.86,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6533E7).withOpacity(0.12),
                      blurRadius: 36,
                      offset: const Offset(0, -10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Drag Pill
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E4E8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Logo / Header
                        _buildHeader(),
                        const SizedBox(height: 24),

                        // Non-Overlapping 6 PIN Slots
                        _buildPinSlots(),
                        const SizedBox(height: 12),

                        // Reset / Change PIN link if in confirming mode
                        Obx(() {
                          if (controller.isConfirming.value) {
                            return Center(
                              child: TextButton.icon(
                                onPressed: controller.reset,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Color(0xFF6533E7),
                                ),
                                label: const Text(
                                  'Change first passcode',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6533E7),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 32);
                        }),

                        // Clean Numeric Keypad (Numbers only, no letters)
                        _buildKeypad(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top logo, dynamic title & subtitle matching RavaMate.
  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Image.asset(
            'assets/images/psosyo_login_logo.png',
            height: 70,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),

        // Title: Changes between 'Set New Passcode' and 'Confirm Passcode'
        Obx(
          () => Text(
            controller.isConfirming.value
                ? 'Confirm Passcode'
                : 'Set New Passcode',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2F333A),
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle: Changes dynamically matching RavaMate
        Obx(
          () => Text(
            controller.isConfirming.value
                ? 'Re-enter your passcode to continue\nusing the app.'
                : 'Create a new passcode to secure your\naccount.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF8A8F99),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the 6 PIN indicator boxes with responsive sizing that NEVER overlaps.
  Widget _buildPinSlots() {
    return Obx(() {
      final isConfirm = controller.isConfirming.value;
      final value = isConfirm ? controller.confirmPin.value : controller.pin.value;

      return Center(
        child: SizedBox(
          width: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              final hasDigit = index < value.length;
              final isActive = index == value.length;

              return Container(
                width: 40,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF6533E7)
                        : hasDigit
                            ? const Color(0xFF6533E7)
                            : const Color(0xFFE2E4E8),
                    width: isActive ? 2.0 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6533E7).withOpacity(0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Text(
                    hasDigit ? '•' : '',
                    key: ValueKey('slot_${isConfirm ? "c" : "p"}_${index}_$hasDigit'),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F333A),
                      height: 1.0,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    });
  }

  /// Builds the numeric keypad (digits only, no complicated letters).
  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _buildBottomKeypadRow(),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) => _buildNumberKey(digit)).toList(),
    );
  }

  Widget _buildBottomKeypadRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Delete Key (Left)
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.deleteDigit,
              borderRadius: BorderRadius.circular(30),
              splashColor: const Color(0xFFD32F2F).withOpacity(0.1),
              child: Container(
                height: 60,
                alignment: Alignment.center,
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
            ),
          ),
        ),

        // '0' Key (Center)
        _buildNumberKey('0'),

        // Submit / Confirm Key (Right)
        Expanded(
          child: Obx(() {
            final isReady = (controller.isConfirming.value
                    ? controller.confirmPin.value.length
                    : controller.pin.value.length) ==
                6;
            final isSaving = controller.isSaving.value;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isReady && !isSaving ? controller.submitPin : null,
                borderRadius: BorderRadius.circular(30),
                splashColor: const Color(0xFF6533E7).withOpacity(0.2),
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF6533E7),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          color: isReady
                              ? const Color(0xFF6533E7)
                              : const Color(0xFFC7CAD3),
                          size: 30,
                        ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Clean numeric key button with NO letters.
  Widget _buildNumberKey(String digit) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.addDigit(digit),
          borderRadius: BorderRadius.circular(30),
          splashColor: const Color(0xFF6533E7).withOpacity(0.12),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Text(
              digit,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2F333A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
