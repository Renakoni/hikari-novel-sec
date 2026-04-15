import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/common/constants.dart';
import 'package:hikari_novel_flutter/network/request.dart';
import 'package:hikari_novel_flutter/pages/my/controller.dart';
import 'package:hikari_novel_flutter/router/app_sub_router.dart';

class MyPage extends StatelessWidget {
  MyPage({super.key});

  final controller = Get.put(MyController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            _buildUserInfoCard(context),
            const SizedBox(height: 20),
            ListTile(title: Text("browsing_history".tr), leading: const Icon(Icons.history), onTap: AppSubRouter.toBrowsingHistory),
            ListTile(title: const Text("导入电子书"), leading: const Icon(Icons.upload_file_outlined), onTap: () => _showImportBookSheet(context)),
            ListTile(title: Text("setting".tr), leading: const Icon(Icons.settings_outlined), onTap: AppSubRouter.toSetting),
            ListTile(title: Text("about".tr), leading: const Icon(Icons.info_outline), onTap: AppSubRouter.toAbout),
            ListTile(title: Text("logout".tr), leading: const Icon(Icons.logout), onTap: controller.logout),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportBookSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text("EPUB"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.importEpub();
                },
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text("Markdown"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.importMarkdown();
                },
              ),
              ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: const Text("TXT"),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.importTxt();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardBorderRadius)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => {AppSubRouter.toUserInfo()},
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: controller.userInfo.value == null
                    ? const CircleAvatar()
                    : CircleAvatar(backgroundImage: CachedNetworkImageProvider(controller.userInfo.value!.avatar, headers: Request.userAgent)),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                controller.userInfo.value?.username ?? "",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  }
}
