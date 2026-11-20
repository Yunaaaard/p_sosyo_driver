import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/core/constants/app_constants.dart';
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

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
              // 1. Deep studio backdrop with subtle brand radial glow
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    gradient: RadialGradient(
                      center: const Alignment(0.75, -0.88),
                      radius: 1.1,
                      colors: [
                        AppColors.primary.withOpacity(0.24),
                        AppColors.secondary.withOpacity(0.12),
                        AppColors.surfaceDark,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.06,
                    child: Image.asset(
                      AppConstants.backgroundAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // 2. Top Brand Header (Visible when keyboard is closed)
              SafeArea(
                bottom: false,
                child: Obx(() {
                  final isKeyboardVisible = controller.keyboardVisible.value;
                  return AnimatedOpacity(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    opacity: isKeyboardVisible ? 0.0 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.28),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: SvgPicture.asset(
                                    AppConstants.paqnerLogoAsset,
                                    width: 22,
                                    height: 17,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppConstants.appName,
                                      style: AppTypography.heading.copyWith(
                                        color: Colors.white,
                                        fontSize: 24,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDarkElevated,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                              border: Border.all(
                                color: AppColors.surfaceDarkBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.mint,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'DRIVER EDITION',
                                  style: AppTypography.micro.copyWith(
                                    fontSize: 13.5,
                                    color: AppColors.mint,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

              // 3. Anchored Rounded Form Container
              Align(
                alignment: Alignment.bottomCenter,
                child: Obx(() {
                  final isKeyboardVisible = controller.keyboardVisible.value;

                  return AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: isKeyboardVisible ? 0.90 : 0.80,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadii.sheet),
                            topRight: Radius.circular(AppRadii.sheet),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 28,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.xxl,
                              isKeyboardVisible ? 16 : 14,
                              AppSpacing.xxl,
                              bottomInset > 0
                                  ? bottomInset + AppSpacing.lg
                                  : AppSpacing.xxl,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 38,
                                    height: 4,
                                    margin: const EdgeInsets.only(
                                      bottom: AppSpacing.lg,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.borderStrong
                                          .withOpacity(0.55),
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.pill),
                                    ),
                                  ),
                                ),
                                _buildHeader(isKeyboardVisible, reduceMotion),
                                const SizedBox(height: AppSpacing.xxl),
                                CustomTextField(
                                  controller: controller.usernameController,
                                  focusNode: controller.usernameFocus,
                                  label: 'Driver MD Code',
                                  hintText: 'e.g. SMB0012 or MN0007',
                                  prefixIcon: Icons.badge_outlined,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      controller.focusPassword(),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Obx(
                                  () => CustomTextField(
                                    controller: controller.passwordController,
                                    focusNode: controller.passwordFocus,
                                    label: 'Password',
                                    hintText: 'Enter your password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText:
                                        controller.obscurePassword.value,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                        controller.submitLogin(),
                                    suffixIcon: IconButton(
                                      onPressed:
                                          controller.togglePasswordVisibility,
                                      icon: Icon(
                                        controller.obscurePassword.value
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: AppColors.inkMuted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildRememberRow(),
                                const SizedBox(height: AppSpacing.xxl),
                                Obx(
                                  () => CustomButton(
                                    label: 'Sign In',
                                    icon: Icons.arrow_forward_rounded,
                                    isLoading: controller.isLoading.value,
                                    onPressed: controller.submitLogin,
                                  ),
                                ),
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

  Widget _buildHeader(bool isKeyboardVisible, bool reduceMotion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: isKeyboardVisible
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: AppColors.primaryBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'app_login_logo',
                          child: SvgPicture.asset(
                            AppConstants.paqnerLogoAsset,
                            width: 34,
                            height: 26,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FIELD DISPATCH',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.eyebrow.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Route & E-Receipt Verification',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 16.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const Text(
          'Driver Sign In',
          style: AppTypography.display,
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in with your driver MD Code to load today\'s deliveries.',
          style: AppTypography.body.copyWith(
            fontSize: 18.5,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildRememberRow() {
    return Row(
      children: [
        Expanded(
          child: Obx(
            () => InkWell(
              onTap: () =>
                  controller.toggleRememberMe(!controller.rememberMe.value),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: controller.rememberMe.value,
                        onChanged: controller.toggleRememberMe,
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Remember MD Code',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 17.5,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Default: 123',
            style: AppTypography.monoRef.copyWith(
              fontSize: 15,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
