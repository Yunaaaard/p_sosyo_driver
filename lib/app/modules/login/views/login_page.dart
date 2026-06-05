import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/themes/theme_colors.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';
import 'package:p_sosyo_driver/app/widgets/custom_button.dart';
import 'package:p_sosyo_driver/app/widgets/custom_textfield.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = bottomInset > 0;

    // Sync controller keyboard state with actual keyboard inset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.syncKeyboardState(keyboardOpen);
    });

    return GestureDetector(
      onTap: controller.dismissKeyboard,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Obx(() {
            final isKeyboardVisible = controller.keyboardVisible.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: isKeyboardVisible ? 0.85 : 0.72,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isKeyboardVisible ? 12 : 16,
                      20,
                      isKeyboardVisible ? 16 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(isKeyboardVisible),
                        const SizedBox(height: 20),
                        _buildUsernameField(),
                        const SizedBox(height: 18),
                        _buildPasswordField(),
                        const SizedBox(height: 16),
                        _buildRememberRow(),
                        const SizedBox(height: 25),
                        CustomButton(
                          label: 'Let\'s Start',
                          onPressed: controller.submitLogin,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Logo + welcome text — collapses when keyboard is visible.
  Widget _buildHeader(bool isKeyboardVisible) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isKeyboardVisible ? 0.0 : 1.0,
        child: SizedBox(
          height: isKeyboardVisible ? 0 : null,
          child: Column(
            children: [
              Center(
                child: Image.asset(
                  'assets/images/psosyo_login_logo.png',
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F333A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your details below to log back into\nyour account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  height: 1.5,
                  color: ThemeColors.primary.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Username label + text field.
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Username',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: controller.usernameController,
          focusNode: controller.usernameFocus,
          hintText: 'ex. SMB0012',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => controller.focusPassword(),
        ),
      ],
    );
  }

  /// Password label + text field with visibility toggle.
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => CustomTextField(
            controller: controller.passwordController,
            focusNode: controller.passwordFocus,
            hintText: 'Enter your password',
            obscureText: controller.obscurePassword.value,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => controller.submitLogin(),
            suffixIcon: IconButton(
              onPressed: controller.togglePasswordVisibility,
              icon: Icon(
                controller.obscurePassword.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFFB8BCC5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Remember-me checkbox + forgot password link.
  Widget _buildRememberRow() {
    return Row(
      children: [
        Obx(
          () => Checkbox(
            value: controller.rememberMe.value,
            onChanged: controller.toggleRememberMe,
            activeColor: const Color(0xFF6533E7),
            side: const BorderSide(
              color: Color(0xFFC2C5CF),
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const Expanded(
          child: Text(
            'Remember me',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF8A8F99),
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6533E7),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}