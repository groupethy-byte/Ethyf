import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'category_controller.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CategoryController controller = Get.find<CategoryController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Page'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Category Page is working',
              style: TextStyle(fontSize: 20),
            ),
            Obx(
              () => Text(
                '${controller.count}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          controller.increment();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}