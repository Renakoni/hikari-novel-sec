import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hikari_novel_flutter/models/user_info.dart';
import 'package:hikari_novel_flutter/router/route_path.dart';
import 'package:hikari_novel_flutter/widgets/state_page.dart';

import '../../service/local_book_service.dart';
import '../../service/local_storage_service.dart';

class MyController extends GetxController {
  Rxn<UserInfo> userInfo = Rxn(LocalStorageService.instance.getUserInfo());

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  void logout() {
    LocalStorageService.instance.setCookie(null);
    Get.offAndToNamed(RoutePath.welcome);
  }

  Future<void> importEpub() async {
    try {
      final result = await LocalBookService.importEpub();
      if (result == null) return;
      showSnackBar(message: "Imported: ${result.title}", context: Get.context!);
    } catch (e) {
      showSnackBar(message: "Import failed: $e", context: Get.context!);
    }
  }

  Future<void> importMarkdown() async {
    try {
      final result = await LocalBookService.importMarkdown();
      if (result == null) return;
      showSnackBar(message: "Imported: ${result.title}", context: Get.context!);
    } catch (e) {
      showSnackBar(message: "Import failed: $e", context: Get.context!);
    }
  }

  Future<void> importTxt() async {
    try {
      final result = await LocalBookService.importTxt();
      if (result == null) return;
      showSnackBar(message: "Imported: ${result.title}", context: Get.context!);
    } catch (e) {
      showSnackBar(message: "Import failed: $e", context: Get.context!);
    }
  }
}
