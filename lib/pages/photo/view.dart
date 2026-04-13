import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../network/request.dart';

class PhotoPage extends StatefulWidget {
  PhotoPage({super.key});

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  late final bool _isGallery;
  late final int _initialIndex;
  PageController? _pageController;
  final RxInt currentIndex = 0.obs;

  @override
  void initState() {
    super.initState();
    _isGallery = Get.arguments["gallery_mode"] == true;
    _initialIndex = _isGallery ? ((Get.arguments["index"] as int?) ?? 0) : 0;
    currentIndex.value = _initialIndex;
    if (_isGallery) {
      _pageController = PageController(initialPage: _initialIndex);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton.filledTonal(onPressed: Get.back, icon: Icon(Icons.close, size: 30, color: Theme.of(context).colorScheme.primary)),
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body:
          _isGallery
              ? Stack(
                children: [
                  PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    itemCount: Get.arguments["list"].length,
                    builder: (_, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: _buildImageProvider(Get.arguments["list"][index]),
                      );
                    },
                    loadingBuilder:
                        (context, progress) => Center(
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress == null ? null : progress.cumulativeBytesLoaded / (progress.expectedTotalBytes?.toInt() ?? 0),
                            ),
                          ),
                        ),
                    pageController: _pageController!,
                    onPageChanged: (index) => currentIndex.value = index,
                  ),
                  Positioned.fill(
                    child: Container(
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.all(20.0),
                      child: Obx(
                        () => Text(
                          "${currentIndex.value + 1} / ${Get.arguments["list"].length}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.6), //阴影颜色
                                offset: Offset(1, 1), //阴影偏移量
                                blurRadius: 6, //模糊程度
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : PhotoView(
                imageProvider: _buildImageProvider(Get.arguments["url"]),
                loadingBuilder:
                    (context, progress) => Center(
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress == null ? null : progress.cumulativeBytesLoaded / (progress.expectedTotalBytes?.toInt() ?? 0),
                        ),
                      ),
                    ),
              ),
    );
  }

  ImageProvider _buildImageProvider(String path) {
    final isLocalFile = !path.startsWith('http') && File(path).existsSync();
    if (isLocalFile) {
      return FileImage(File(path));
    }
    return CachedNetworkImageProvider(path, headers: Request.userAgent);
  }
}
