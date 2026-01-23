import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'family_controller.dart';
import '../../../utils/user_utils.dart'; // To get current user info for displaying name

class FamilyManagementPage extends GetView<FamilyController> {
  const FamilyManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Keluarga'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final family = controller.currentFamily.value;
        final familyMembers = controller.familyMembers;

        if (family == null) {
          return _buildNoFamilyView(context);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nama Keluarga: ${family.familyName}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text('ID Keluarga: ${family.id}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 10),
                      Text(
                        family.isPro ? 'Status: Pro (Aktif)' : 'Status: Free (Upgrade untuk fitur lengkap)',
                        style: TextStyle(
                            color: family.isPro ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      if (!family.isPro)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              controller.upgradeFamilyToPro(); // Call the upgrade method
                            },
                            child: const Text('Upgrade ke Pro'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Text(
                'Anggota Keluarga',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (familyMembers.isEmpty)
                const Text('Belum ada anggota keluarga.'),
              ...familyMembers.map((member) => Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(member['name'] ?? 'Tidak Dikenal'),
                  subtitle: Text(member['uid'] ?? ''),
                  // TODO: Add options to remove member if current user is owner
                ),
              )),
              const SizedBox(height: 20),
              if (family.isPro)
                _buildInviteMemberSection(context),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildNoFamilyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Anda belum tergabung dalam keluarga.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Untuk menggunakan fitur keluarga, Anda bisa membuat keluarga baru atau bergabung dengan keluarga yang sudah ada (memerlukan undangan).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                _showCreateFamilyDialog(context);
              },
              child: const Text('Buat Keluarga Baru'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                _showJoinFamilyDialog(context);
              },
              child: const Text('Bergabung dengan Keluarga'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFamilyDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    Get.defaultDialog(
      title: 'Buat Keluarga Baru',
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(hintText: 'Nama Keluarga Anda'),
      ),
      textConfirm: 'Buat',
      textCancel: 'Batal',
      onConfirm: () {
        if (nameController.text.isNotEmpty) {
          controller.createFamily(nameController.text);
          Get.back();
        } else {
          Get.snackbar('Error', 'Nama keluarga tidak boleh kosong');
        }
      },
    );
  }

  void _showJoinFamilyDialog(BuildContext context) {
    final TextEditingController inviteCodeController = TextEditingController();
    Get.defaultDialog(
      title: 'Bergabung dengan Keluarga',
      content: TextField(
        controller: inviteCodeController,
        decoration: const InputDecoration(hintText: 'Kode Undangan Keluarga'),
      ),
      textConfirm: 'Gabung',
      textCancel: 'Batal',
      onConfirm: () {
        if (inviteCodeController.text.isNotEmpty) {
          // TODO: Implement actual join family logic using invite code
          Get.snackbar('Fitur', 'Bergabung dengan keluarga akan datang!');
          Get.back();
        } else {
          Get.snackbar('Error', 'Kode undangan tidak boleh kosong');
        }
      },
    );
  }

  Widget _buildInviteMemberSection(BuildContext context) {
    final TextEditingController inviteController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Undang Anggota Baru',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: inviteController,
          decoration: InputDecoration(
            hintText: 'UID atau Email Anggota',
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (inviteController.text.isNotEmpty) {
                  controller.inviteMember(inviteController.text);
                  inviteController.clear();
                }
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '* Untuk saat ini, masukkan UID anggota Firebase yang ingin diundang.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}