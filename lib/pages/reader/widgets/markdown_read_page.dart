import 'dart:io';

import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MarkdownReadPage extends StatelessWidget {
  final String data;
  final EdgeInsets padding;
  final Color textColor;

  const MarkdownReadPage({
    super.key,
    required this.data,
    required this.padding,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseConfig = Theme.of(context).brightness == Brightness.dark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    return MarkdownWidget(
      data: data,
      padding: padding,
      config: baseConfig.copy(
        configs: [
          ImgConfig(builder: _buildImage),
          PConfig(textStyle: TextStyle(fontSize: 16, height: 1.65, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildImage(String url, Map<String, String> attributes) {
    final alt = attributes['alt'] ?? '';
    final imageUrl = url.trim();
    if (imageUrl.startsWith('http')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, _, __) => _buildError(alt),
        ),
      );
    }

    final file = _localImageFile(imageUrl);
    if (file != null && file.existsSync()) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, _, __) => _buildError(alt),
        ),
      );
    }

    return _buildError(alt);
  }

  File? _localImageFile(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('file://')) {
      try {
        return File.fromUri(Uri.parse(url));
      } catch (_) {
        return null;
      }
    }
    return File(url);
  }

  Widget _buildError(String alt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          if (alt.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(alt.trim())),
          ],
        ],
      ),
    );
  }
}
