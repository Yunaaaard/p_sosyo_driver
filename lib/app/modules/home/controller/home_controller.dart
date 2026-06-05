import 'package:get/get.dart';

class HomeController extends GetxController {
  final RxString activeTab = "Out for Delivery".obs;

  void changeTab(String tabName) {
    activeTab.value = tabName;
  }
}
