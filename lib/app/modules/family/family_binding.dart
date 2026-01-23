import 'package:get/get.dart';
import 'family_controller.dart';

class FamilyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FamilyController>(
      () => FamilyController(),
    );
  }
}