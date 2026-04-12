import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hikari_novel_flutter/common/database/database.dart';
import 'package:hikari_novel_flutter/models/cat_chapter.dart';
import 'package:hikari_novel_flutter/models/cat_volume.dart';
import 'package:hikari_novel_flutter/models/novel_detail.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'db_service.dart';

class LocalBookService {
  static const String epubAidPrefix = "local_epub_";
  static const String localUrlPrefix = "local://epub/";

  static bool isLocalAid(String aid) => aid.startsWith(epubAidPrefix);

  static bool isLocalBookshelfEntry(BookshelfEntityData data) => isLocalAid(data.aid);

  static Future<List<BookshelfEntityData>> getLocalBookshelfEntries() async {
    final all = await DBService.instance.getAllBookshelf();
    return all.where(isLocalBookshelfEntry).toList();
  }

  static Future<LocalImportResult?> importEpub() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['epub']);
    if (result == null || result.files.single.path == null) return null;

    final sourcePath = result.files.single.path!;
    final archive = ZipDecoder().decodeBytes(await File(sourcePath).readAsBytes());

    final containerContent = _readArchiveFileAsString(archive, 'META-INF/container.xml');
    if (containerContent == null) {
      throw Exception("EPUB missing META-INF/container.xml");
    }

    final containerDoc = XmlDocument.parse(containerContent);
    final rootFile = _firstOrNull(containerDoc.findAllElements('rootfile'))?.getAttribute('full-path');
    if (rootFile == null || rootFile.isEmpty) {
      throw Exception("EPUB missing OPF path");
    }

    final opfContent = _readArchiveFileAsString(archive, rootFile);
    if (opfContent == null) {
      throw Exception("Failed to read EPUB OPF");
    }

    final opfDir = path.dirname(rootFile) == '.' ? '' : path.dirname(rootFile);
    final opfDoc = XmlDocument.parse(opfContent);
    final packageElement = _firstOrNull(opfDoc.findAllElements('package'));
    if (packageElement == null) {
      throw Exception("Invalid EPUB OPF");
    }

    final metadata = _firstOrNull(packageElement.findElements('metadata'));
    final manifest = _firstOrNull(packageElement.findElements('manifest'));
    final spine = _firstOrNull(packageElement.findElements('spine'));
    if (manifest == null || spine == null) {
      throw Exception("EPUB missing manifest or spine");
    }

    final title = _readMetadataText(metadata, {'title'}) ?? path.basenameWithoutExtension(sourcePath);
    final author = _readMetadataText(metadata, {'creator'}) ?? "Local Import";
    final description = _readMetadataText(metadata, {'description'}) ?? "Imported EPUB";
    final aid = "$epubAidPrefix${DateTime.now().millisecondsSinceEpoch}";

    final appDir = await getApplicationSupportDirectory();
    final importedBookDir = Directory(path.join(appDir.path, 'imported_books', aid));
    final coverDir = Directory(path.join(importedBookDir.path, 'cover'));
    final chapterCacheDir = Directory(path.join(appDir.path, 'cached_chapter'));
    await importedBookDir.create(recursive: true);
    await coverDir.create(recursive: true);
    await chapterCacheDir.create(recursive: true);
    await File(path.join(importedBookDir.path, 'source.epub')).writeAsBytes(await File(sourcePath).readAsBytes(), flush: true);

    final manifestItems = <String, _ManifestItem>{};
    for (final item in manifest.findElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;

      manifestItems[id] = _ManifestItem(
        id: id,
        href: _normalizeArchivePath(path.join(opfDir, href)),
        mediaType: item.getAttribute('media-type') ?? '',
        properties: item.getAttribute('properties') ?? '',
      );
    }

    final coverPath = await _extractCoverImage(
      archive: archive,
      manifestItems: manifestItems,
      metadata: metadata,
      coverDir: coverDir,
    );

    final chapters = <CatChapter>[];
    for (final entry in spine.findElements('itemref').indexed) {
      final index = entry.$1;
      final itemRef = entry.$2;
      final idRef = itemRef.getAttribute('idref');
      if (idRef == null) continue;

      final manifestItem = manifestItems[idRef];
      if (manifestItem == null || !_isTextLike(manifestItem.mediaType)) continue;

      final chapterRaw = _readArchiveFileAsString(archive, manifestItem.href);
      if (chapterRaw == null) continue;

      final chapterDoc = html_parser.parse(chapterRaw);
      chapterDoc.querySelectorAll('img, script, style').forEach((element) => element.remove());
      final headingTitle = chapterDoc.querySelector('h1, h2, h3')?.text.trim();
      final documentTitle = chapterDoc.querySelector('title')?.text.trim();
      final chapterTitle = (headingTitle != null && headingTitle.isNotEmpty)
          ? headingTitle
          : ((documentTitle != null && documentTitle.isNotEmpty) ? documentTitle : "Chapter ${index + 1}");
      final bodyHtml = chapterDoc.body?.innerHtml.trim();
      if (bodyHtml == null || bodyHtml.isEmpty) continue;

      final cid = "${aid}_chapter_$index";
      await File(path.join(chapterCacheDir.path, "${aid}_$cid.txt")).writeAsString('<div id="content">$bodyHtml</div>');
      chapters.add(CatChapter(title: chapterTitle, cid: cid));
    }

    if (chapters.isEmpty) {
      throw Exception("No readable chapters found in EPUB");
    }

    final detail = NovelDetail(
      title,
      author,
      "Local EPUB",
      DateTime.now().toIso8601String().split('T').first,
      coverPath ?? "",
      description,
      const ["Local", "EPUB"],
      [],
      "Imported",
      "Local Reading",
      false,
    )..catalogue = [CatVolume(title: "Content", chapters: chapters)];

    await DBService.instance.upsertNovelDetail(NovelDetailEntityData(aid: aid, json: jsonEncode(detail.toJson())));
    await DBService.instance.upsertBookshelf(
      BookshelfEntityData(
        aid: aid,
        bid: aid,
        url: "$localUrlPrefix$aid",
        title: title,
        img: coverPath ?? "",
        classId: "0",
      ),
    );

    return LocalImportResult(aid: aid, title: title);
  }

  static Future<void> removeFromBookshelf(String aid) async {
    await DBService.instance.deleteBookshelfByAid(aid);
  }

  static Future<void> deleteImportedRecord(String aid) async {
    await DBService.instance.deleteBookshelfByAid(aid);
    await DBService.instance.deleteBrowsingHistory(aid);
    await DBService.instance.deleteReadHistoryByAid(aid);
    await DBService.instance.deleteNovelDetail(aid);
  }

  static Future<void> deleteImportedRecordAndFiles(String aid) async {
    await deleteImportedRecord(aid);

    final appDir = await getApplicationSupportDirectory();
    final importedBookDir = Directory(path.join(appDir.path, 'imported_books', aid));
    if (await importedBookDir.exists()) {
      await importedBookDir.delete(recursive: true);
    }

    final chapterCacheDir = Directory(path.join(appDir.path, 'cached_chapter'));
    if (await chapterCacheDir.exists()) {
      await for (final entity in chapterCacheDir.list()) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        if (name.startsWith('${aid}_')) {
          await entity.delete();
        }
      }
    }
  }

  static String? _readArchiveFileAsString(Archive archive, String filePath) {
    final file = _findArchiveFile(archive, filePath);
    if (file == null) return null;

    final content = file.content;
    if (content is String) return content.toString();
    if (content is Uint8List) return utf8.decode(content, allowMalformed: true);
    if (content is List<int>) return utf8.decode(content, allowMalformed: true);
    return null;
  }

  static Future<String?> _extractCoverImage({
    required Archive archive,
    required Map<String, _ManifestItem> manifestItems,
    required XmlElement? metadata,
    required Directory coverDir,
  }) async {
    String? coverId;
    for (final meta in metadata?.findElements('meta') ?? const Iterable<XmlElement>.empty()) {
      if (meta.getAttribute('name') == 'cover') {
        coverId = meta.getAttribute('content');
        break;
      }
    }

    _ManifestItem? coverItem = coverId == null ? null : manifestItems[coverId];
    coverItem ??= _firstOrNull(manifestItems.values.where((item) => item.properties.contains('cover-image')));
    coverItem ??= _firstOrNull(manifestItems.values.where((item) => item.mediaType.startsWith('image/')));
    if (coverItem == null || coverItem.href.isEmpty) return null;

    final file = _findArchiveFile(archive, coverItem.href);
    if (file == null) return null;

    final content = file.content;
    final bytes = content is Uint8List ? content : Uint8List.fromList(content as List<int>);
    final extension = path.extension(coverItem.href).isEmpty ? '.img' : path.extension(coverItem.href);
    final savedPath = path.join(coverDir.path, "cover$extension");
    await File(savedPath).writeAsBytes(bytes, flush: true);
    return savedPath;
  }

  static String? _readMetadataText(XmlElement? metadata, Set<String> candidateNames) {
    if (metadata == null) return null;

    for (final node in metadata.descendants.whereType<XmlElement>()) {
      if (!candidateNames.contains(node.name.local.toLowerCase())) continue;
      final text = node.innerText.trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }

  static bool _isTextLike(String mediaType) =>
      mediaType.contains('xhtml') || mediaType.contains('html') || mediaType.contains('xml');

  static String _normalizeArchivePath(String value) => value.replaceAll('\\', '/');

  static T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;

  static ArchiveFile? _findArchiveFile(Archive archive, String filePath) {
    final normalizedTarget = _normalizeArchivePath(filePath);
    for (final file in archive.files) {
      if (_normalizeArchivePath(file.name) == normalizedTarget) {
        return file;
      }
    }
    return null;
  }
}

class LocalImportResult {
  final String aid;
  final String title;

  LocalImportResult({required this.aid, required this.title});
}

class _ManifestItem {
  final String id;
  final String href;
  final String mediaType;
  final String properties;

  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });
}
