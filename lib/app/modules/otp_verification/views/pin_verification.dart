import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/otp_verification/controller/pin_verification_controller.dart';

class PinVerificationPage extends GetView<PinVerificationController> {
  const PinVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background stripes image covering whole screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/psosyo_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // Bottom card containing logo, text, pins, and custom keyboard
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.83,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/psosyo_login_logo.png',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Subtitle text
                        const Text(
                          'To secure your psosyo account set\n6 digit pin code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF8A8F99),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // PIN indicator slots row
                        _buildPinSlots(),
                        const SizedBox(height: 48),

                        // Custom Numeric Keyboard
                        _buildKeyboard(),
                        const SizedBox(height: 16),
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

  /// Builds the 6 PIN indicator slots.
  Widget _buildPinSlots() {
    return Obx(() {
      final currentPin = controller.pin.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          final isFilled = currentPin.length > index;
          return Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFE2E4E8),
                width: 1.5,
              ),
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
              child: isFilled
                  ? Container(
                      key: ValueKey('dot_filled_$index'),
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2F333A),
                        shape: BoxShape.circle,
                      ),
                    )
                  : SizedBox(
                      key: ValueKey('dot_empty_$index'),
                    ),
            ),
          );
        }),
      );
    });
  }

  /// Builds the custom numeric keyboard grid.
  Widget _buildKeyboard() {
    return Column(
      children: [
        _buildKeyboardRow(['1', '2', '3']),
        _buildKeyboardRow(['4', '5', '6']),
        _buildKeyboardRow(['7', '8', '9']),
        _buildBottomKeyboardRow(),
      ],
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) => _buildNumberKey(key)).toList(),
      ),
    );
  }

  Widget _buildBottomKeyboardRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDeleteKey(),
          _buildNumberKey('0'),
          _buildSubmitKey(),
        ],
      ),
    );
  }

  /// Builds a regular numeric keyboard button.
  Widget _buildNumberKey(String digit) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => controller.addDigit(digit),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Text(
              digit,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F333A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 'Delete' button.
  Widget _buildDeleteKey() {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.deleteDigit,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F333A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the right-arrow submit button.
  Widget _buildSubmitKey() {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: controller.submitPin,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF6533E7),
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}