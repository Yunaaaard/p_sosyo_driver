import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class LoginController extends GetxController {
	final TextEditingController usernameController = TextEditingController();
	final TextEditingController passwordController = TextEditingController();

	final FocusNode usernameFocus = FocusNode();
	final FocusNode passwordFocus = FocusNode();

	final RxBool rememberMe = false.obs;
	final RxBool obscurePassword = true.obs;
	final RxBool keyboardVisible = false.obs;

	@override
	void onInit() {
		super.onInit();
		usernameFocus.addListener(_onFocusChange);
		passwordFocus.addListener(_onFocusChange);
	}

	void _onFocusChange() {
		keyboardVisible.value = usernameFocus.hasFocus || passwordFocus.hasFocus;
	}

	/// Called from the view when the actual keyboard inset changes,
	/// to keep [keyboardVisible] in sync with the real keyboard state.
	void syncKeyboardState(bool isOpen) {
		if (keyboardVisible.value != isOpen) {
			keyboardVisible.value = isOpen;
		}
	}

	void dismissKeyboard() {
		usernameFocus.unfocus();
		passwordFocus.unfocus();
	}

	void focusPassword() {
		passwordFocus.requestFocus();
	}

	void toggleRememberMe(bool? value) {
		rememberMe.value = value ?? false;
	}

	void togglePasswordVisibility() {
		obscurePassword.value = !obscurePassword.value;
	}

	void submitLogin() {
		Get.toNamed(AppRoutes.pinVerification);
	}

	@override
	void onClose() {
		usernameFocus.removeListener(_onFocusChange);
		passwordFocus.removeListener(_onFocusChange);
		usernameFocus.dispose();
		passwordFocus.dispose();
		usernameController.dispose();
		passwordController.dispose();
		super.onClose();
	}
}