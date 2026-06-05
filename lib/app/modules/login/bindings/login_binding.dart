import 'package:get/get.dart';
import 'package:p_sosyo_driver/app/modules/login/controller/login_controller.dart';

class LoginBinding extends Bindings {
	@override
	void dependencies() {
		Get.lazyPut<LoginController>(() => LoginController());
	}
}