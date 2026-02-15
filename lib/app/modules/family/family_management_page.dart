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
        final invitations = controller.pendingInvitations;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Undangan Masuk
              if (invitations.isNotEmpty) ...[
                const Text(
                  'Undangan Masuk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                ...invitations.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    color: Colors.blue.shade50,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.mail, color: Colors.blue),
                      title: Text('Undangan dari Keluarga ${data['familyName']}'),
                      subtitle: Text('Diundang oleh: ${data['inviterName']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                            tooltip: 'Terima',
                            onPressed: () => controller.acceptInvitation(doc.id, data['familyId']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                            tooltip: 'Tolak',
                            onPressed: () => controller.rejectInvitation(doc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
                const Divider(thickness: 1),
                const SizedBox(height: 20),
              ],

              // Tampilan Keluarga atau No Family
              if (family == null)
                _buildNoFamilyView(context)
              else
                _buildFamilyDetails(context, family, familyMembers, controller),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFamilyDetails(BuildContext context, dynamic family, List<Map<String, String>> familyMembers, FamilyController controller) {
    return Column(
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
                // Text('ID Keluarga: ${family.id}', style: const TextStyle(color: Colors.grey)), // ID Keluarga disembunyikan
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
        ...familyMembers.map((member) {
          final isOwner = member['uid'] == family.ownerUid;
          final isAdminView = controller.user?.uid == family.ownerUid;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Row(
                children: [
                  Flexible(
                    child: Text(member['name'] ?? 'Nama tidak dikenal', overflow: TextOverflow.ellipsis),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              trailing: (isAdminView && !isOwner)
                  ? IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: 'Hapus Anggota',
                      onPressed: () {
                        controller.removeMember(member['uid']!);
                      },
                    )
                  : null,
            ),
          );
        }),
        // Tampilkan Undangan Terkirim (Pending Members)
        if (controller.sentInvitations.isNotEmpty) ...[
          ...controller.sentInvitations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              elevation: 2,
              color: Colors.grey.shade50,
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.grey),
                title: Text('${data['inviteeName'] ?? 'Calon Anggota'}'),
                subtitle: const Text('Status: Menunggu Konfirmasi', style: TextStyle(color: Colors.orange, fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Batalkan Undangan',
                  onPressed: () => controller.cancelInvitation(doc.id),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 20),
        // Hanya tampilkan form invite jika user adalah owner (Admin)
        if (family.isPro && controller.user?.uid == family.ownerUid)
          _buildInviteMemberSection(context),
        
        const SizedBox(height: 40),
        
        // Hanya tampilkan tombol hapus jika user adalah owner (Admin)
        if (controller.user?.uid == family.ownerUid) ...[
          const Divider(thickness: 1, color: Colors.red),
          const SizedBox(height: 10),
          _buildDangerZone(context, controller),
        ]
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, FamilyController controller) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
                'Zona Berbahaya',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 10),
            const Text(
                'Tindakan di bawah ini tidak dapat diurungkan. Pastikan Anda benar-benar yakin.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Hapus Keluarga Ini'),
                    onPressed: () => _showDeleteFamilyConfirmation(context, controller),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                    ),
                ),
            ),
        ],
    );
  }

  void _showDeleteFamilyConfirmation(BuildContext context, FamilyController controller) {
    Get.defaultDialog(
        title: 'Anda Yakin?',
        titleStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        middleText:
            'Menghapus keluarga akan menghapus SEMUA data terkait (termasuk data semua anggota) dan mengembalikan akun semua anggota ke versi gratis. Tindakan ini tidak dapat diurungkan.',
        textConfirm: 'Ya, Hapus Keluarga',
        textCancel: 'Batal',
        buttonColor: Colors.red,
        confirmTextColor: Colors.white,
        cancelTextColor: Colors.black87,
        onConfirm: () {
            Get.back(); // Close dialog first
            controller.deleteFamily();
        },
    );
  }

  Widget _buildNoFamilyView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          '* Masukkan UID / Email anggota yang ingin diundang.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}