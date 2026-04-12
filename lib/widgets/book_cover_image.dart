import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class BookCoverImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Map<String, String>? httpHeaders;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget Function(BuildContext context, double? progress)? progressBuilder;

  const BookCoverImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.httpHeaders,
    this.errorBuilder,
    this.progressBuilder,
  });

  bool get _isLocalFile => imageUrl.isNotEmpty && !imageUrl.startsWith('http') && File(imageUrl).existsSync();

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _defaultPlaceholder(context);
    }

    if (_isLocalFile) {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, __) => _buildError(context, Exception("封面加载失败")),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      httpHeaders: httpHeaders,
      fit: fit,
      progressIndicatorBuilder: progressBuilder == null
          ? null
          : (context, _, progress) => progressBuilder!(context, progress.progress),
      errorWidget: (context, _, error) => _buildError(context, error),
    );
  }

  Widget _buildError(BuildContext context, Object error) => errorBuilder?.call(context, error) ?? _defaultPlaceholder(context);

  Widget _defaultPlaceholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.book_outlined)),
      );
}
