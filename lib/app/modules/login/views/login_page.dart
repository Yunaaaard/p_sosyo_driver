import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';

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

    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: controller.dismissKeyboard,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              // 1. Ambient Background Layer with Brand Overlay
              Positioned.fill(
                child: Image.asset(
                  'assets/images/psosyo_background.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Subtle Darker Top Gradient to make artwork and status bar pop
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                        Colors.black.withOpacity(0.15),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Top Branding & Floating Header (Visible when keyboard is closed)
              SafeArea(
                child: Obx(() {
                  final isKeyboardVisible = controller.keyboardVisible.value;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isKeyboardVisible ? 0.0 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'P-Sosyo Driver Edition',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // 4. Bottom Modern Sheet Container
              Align(
                alignment: Alignment.bottomCenter,
                child: Obx(() {
                  final isKeyboardVisible = controller.keyboardVisible.value;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: isKeyboardVisible ? 0.88 : 0.78,
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
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              24,
                              isKeyboardVisible ? 14 : 16,
                              24,
                              isKeyboardVisible ? 16 : 28,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Drag Handle
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

                                // Brand Logo & Title Header
                                _buildHeader(isKeyboardVisible),
                                const SizedBox(height: 24),

                                // Username / MD Code Field
                                _buildUsernameField(),
                                const SizedBox(height: 18),

                                // Password Field
                                _buildPasswordField(),
                                const SizedBox(height: 14),

                                // Remember Me Row
                                _buildRememberRow(),
                                const SizedBox(height: 24),

                                // Primary Login Button
                                _buildSubmitButton(),
                                const SizedBox(height: 16),

                                // Security Footer
                                _buildSecurityBadge(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the animated header with logo, title and friendly subtitle.
  Widget _buildHeader(bool isKeyboardVisible) {
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: SizedBox(
            height: isKeyboardVisible ? 0 : 105,
            child: isKeyboardVisible
                ? const SizedBox.shrink()
                : Center(
                    child: Hero(
                      tag: 'app_login_logo',
                      child: Image.asset(
                        'assets/images/psosyo_login_logo.png',
                        height: 95,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),
        ),
        if (!isKeyboardVisible) const SizedBox(height: 12),
        const Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2F333A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in with your driver MD Code to access deliveries',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF8A8F99),
          ),
        ),
      ],
    );
  }

  /// Username / MD Code text field.
  Widget _buildUsernameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Salesman / Driver MD Code',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: controller.usernameController,
            focusNode: controller.usernameFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => controller.focusPassword(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2F333A),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. SMB0012 or MN0007',
              hintStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFFB8BCC5),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF6533E7),
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Password field with visibility toggle and lock prefix.
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2F333A),
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: controller.passwordController,
              focusNode: controller.passwordFocus,
              obscureText: controller.obscurePassword.value,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => controller.submitLogin(),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2F333A),
              ),
              decoration: InputDecoration(
                hintText: 'Enter your password (e.g. 123)',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFFB8BCC5),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF6533E7),
                    size: 20,
                  ),
                ),
                suffixIcon: IconButton(
                  onPressed: controller.togglePasswordVisibility,
                  icon: Icon(
                    controller.obscurePassword.value
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF8A8F99),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Remember-me checkbox and forgot password link.
  Widget _buildRememberRow() {
    return Row(
      children: [
        Obx(
          () => SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
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
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Remember me',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF8A8F99),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EFFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Default: 123',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6533E7),
            ),
          ),
        ),
      ],
    );
  }

  /// Glowing gradient submit button with loading state.
  Widget _buildSubmitButton() {
    return Obx(() {
      final isLoading = controller.isLoading.value;

      return Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF6533E7), Color(0xFF7E4BFA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6533E7).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : controller.submitLogin,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Let\'s Start',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    });
  }

  /// Subtle security footnote badge.
  Widget _buildSecurityBadge() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 14,
          color: Color(0xFFB8BCC5),
        ),
        SizedBox(width: 6),
        Text(
          'Protected by Fast Logistics Driver System',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Color(0xFFB8BCC5),
          ),
        ),
      ],
    );
  }
}
