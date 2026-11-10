import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/data/models/driver.dart';
import 'package:p_sosyo_driver/app/data/providers/api_client.dart';
import 'package:p_sosyo_driver/app/data/services/database_service.dart';
import 'package:p_sosyo_driver/app/routes/app_routes.dart';

class LoginController extends GetxController {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode usernameFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  final RxBool rememberMe = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool keyboardVisible = false.obs;
  final RxBool isLoading = false.obs;

  final DatabaseService _dbService = DatabaseService.to;

  /// Currently authenticated driver (set after successful login).
  Driver? _currentDriver;
  Driver? get currentDriver => _currentDriver;

  @override
  void onInit() {
    super.onInit();
    usernameFocus.addListener(_onFocusChange);
    passwordFocus.addListener(_onFocusChange);
    _loadRememberedDriver();
  }

  /// Pre-fill username if a driver previously chose "remember me".
  Future<void> _loadRememberedDriver() async {
    final driver = await _dbService.getRememberedDriver();
    if (driver != null) {
      usernameController.text = driver.username;
      rememberMe.value = true;
    }
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

  /// Validate credentials, connect with RavaMate server info, and proceed.
  Future<void> submitLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Missing Fields',
        'Please enter both username and password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    isLoading.value = true;

    try {
      final isHardcodedPassword = password == '123' || password == 'password123';
      Driver? driver = await _dbService.authenticateDriver(username, password);

      // If driver is not in local DB yet, but password is '123', allow registration / lookup
      if (driver == null && !isHardcodedPassword) {
        Get.snackbar(
          'Login Failed',
          'Invalid username or password. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFEBEB),
          colorText: const Color(0xFFD32F2F),
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // Connecting with RavaMate servercred to fetch distributor info for this mdCode
      try {
        final endpoint = 'get/servercred/per/distributor?mdCode=$username';
        final creds = await ApiClient.getList(endpoint);
        if (creds.isNotEmpty) {
          final primary = creds.firstWhere(
            (e) => e['ip_desc'] == 'PRIMARY',
            orElse: () => creds.first,
          );
          final distCode = primary['distCode']?.toString();
          if (distCode != null && distCode.isNotEmpty) {
            await ApiClient.setDistCode(distCode);
          }
          final defaultDns = primary['default_dns']?.toString();
          if (defaultDns != null && defaultDns.isNotEmpty) {
            await ApiClient.setHost(defaultDns);
          }
          debugPrint(
              '[LoginController] Configured from RavaMate: distCode=$distCode, host=$defaultDns');
        }
      } catch (e) {
        debugPrint('[LoginController] Note: Servercred fetch skipped or offline: $e');
      }

      // Save driver's mdCode in preferences for syncing and requests
      await ApiClient.setDriverCode(username);

      // Ensure Driver record exists in SQLite
      driver ??= await _dbService.insertOrUpdateDriver(
        Driver(
          username: username,
          password: password,
          fullName: 'Driver $username',
          pin: '123456',
        ),
      );

      _currentDriver = driver;

      // Update remember me preference in DB
      if (driver.id != null) {
        await _dbService.updateRememberMe(
          driver.id!,
          rememberMe.value,
        );
      }

      Get.toNamed(AppRoutes.pinVerification);
    } catch (e) {
      debugPrint('Login error: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFFEBEB),
        colorText: const Color(0xFFD32F2F),
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
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
