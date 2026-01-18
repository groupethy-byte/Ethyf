import 'package:get/get.dart';

import 'sub_category_controller.dart';

class SubCategoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubCategoryController>(
      () => SubCategoryController(),
    );
  }
}
