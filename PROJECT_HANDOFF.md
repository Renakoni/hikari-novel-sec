# hikari-novel-sec 项目交接说明

这份文档用于新会话快速对齐当前工程状态。项目路径：

```text
E:\hikari_novel_flutter
```

当前主要维护目标是 Android。用户通常使用：

```powershell
E:\flutter\bin\flutter.bat run -d 127.0.0.1:7555
```

MuMu 模拟器常用设备 ID：

```text
127.0.0.1:7555
```

## 项目定位

仓库名：`hikari-novel-sec`

这是基于原作者项目继续整理的个人维护版本：

- [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter)
- [wenku8reader](https://github.com/15dd/wenku8reader)

当前不提供 APK Release，README 里已经写明需要自行编译。

## 当前主要功能

已完成或基本完成：

- Android 编译运行
- 本地 EPUB 导入
- 本地 EPUB 自动加入书架
- 本地 EPUB 使用现有阅读器
- 本地 EPUB 阅读进度 / 继续阅读复用现有阅读历史机制
- 本地 EPUB 封面和章节内图片提取、缓存、显示
- 本地书与网络书个人标签
- 书架标签多选筛选
- 本地书长按管理
- 应用图标和名称使用 `wenku8reader` 资源
- 移除原作者 release 更新检查
- TTS provider 架构初步完成
- 系统 TTS / 火山引擎 TTS / Google TTS 三路可选

## 本地 EPUB 相关

核心文件：

- `lib/service/local_book_service.dart`
- `lib/network/parser.dart`
- `lib/pages/bookshelf/controller.dart`
- `lib/pages/reader/widgets/vertical_read_page.dart`
- `lib/pages/reader/widgets/horizontal_read_page.dart`
- `lib/pages/photo/view.dart`

注意点：

- EPUB 导入时会生成缓存，修改导入逻辑后，旧导入记录不会自动更新，通常需要删除旧本地书后重新导入。
- 本地书长按菜单现在只保留两个动作：
  - `从书架移除`
  - `删除导入记录和缓存文件`
- 之前的“删除导入记录但保留缓存文件”已经从 UI 删除。
- `temp_epub_debug.dart` 是临时脚本，已加入 `.gitignore`。

## 标签与筛选

核心文件：

- `lib/pages/novel_detail/controller.dart`
- `lib/pages/novel_detail/view.dart`
- `lib/pages/bookshelf/controller.dart`
- `lib/pages/bookshelf/view.dart`
- `lib/service/local_book_service.dart`

当前规则：

- 原始标签只读，不允许删除
- 个人标签可新增、可删除
- 本地书和网络书都可以加个人标签
- 书架右上角有标签筛选按钮
- 标签筛选支持多选
- `All` 作为清除筛选入口
- 标签排序规则：
  - `All` 固定第一位
  - 英文/数字开头在前
  - 中文标签在后
  - 中文按拼音排序

## TTS 架构

核心文件：

- `lib/models/tts_provider_type.dart`
- `lib/service/tts/tts_provider.dart`
- `lib/service/tts/providers/system_tts_provider.dart`
- `lib/service/tts/providers/volcengine_tts_provider.dart`
- `lib/service/tts/providers/google_tts_provider.dart`
- `lib/service/tts_service.dart`
- `lib/pages/reader/widgets/reader_setting.dart`
- `lib/pages/reader/widgets/tts_floating_controller.dart`

当前 provider：

- `system`
- `volcengine`
- `google`

### 系统 TTS

走 `flutter_tts`，依赖 Android 系统 TTS 引擎。

### 火山引擎 TTS

当前按豆包语音合成 1.0 接入：

```text
Resource ID: seed-tts-1.0
Endpoint: https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse
```

当前内置 5 个音色预设：

- `深夜播客 neutral`
  - speaker: `zh_male_shenyeboke_emo_v2_mars_bigtts`
  - emotion: `neutral`
  - emotion_scale: `2`
- `儒雅青年`
  - speaker: `zh_male_ruyaqingnian_mars_bigtts`
- `悬疑解说`
  - speaker: `zh_male_changtianyi_mars_bigtts`
- `擎苍`
  - speaker: `zh_male_qingcang_mars_bigtts`
- `温柔淑女`
  - speaker: `zh_female_wenroushunv_mars_bigtts`

火山请求里会带固定 `context_texts`：

```text
请用平稳、自然、克制的旁白语气朗读，保持整章前后语气一致，避免明显情绪波动，语速均匀。
```

注意：

- 如果本地旧配置里存着 `seed-tts-2.0`，启动时会自动迁移回 `seed-tts-1.0`。
- 火山 `tts_cache/volcengine` 有缓存上限：
  - 240 个文件
  - 约 160 MB

### Google TTS

当前接入 Google Cloud Text-to-Speech：

```text
Endpoint: https://texttospeech.googleapis.com/v1/text:synthesize
Language: cmn-CN
```

用户已用 `tools/test_google.py` 批量试听过，最终保留 10 个 Chirp3-HD 音色：

男声：

- `Enceladus` -> `cmn-CN-Chirp3-HD-Enceladus`
- `Fenrir` -> `cmn-CN-Chirp3-HD-Fenrir`
- `Iapetus` -> `cmn-CN-Chirp3-HD-Iapetus`
- `Orus` -> `cmn-CN-Chirp3-HD-Orus`
- `Puck` -> `cmn-CN-Chirp3-HD-Puck`
- `Rasalgethi` -> `cmn-CN-Chirp3-HD-Rasalgethi`
- `Schedar` -> `cmn-CN-Chirp3-HD-Schedar`
- `Umbriel` -> `cmn-CN-Chirp3-HD-Umbriel`

女声：

- `Gacrux` -> `cmn-CN-Chirp3-HD-Gacrux`
- `Vindemiatrix` -> `cmn-CN-Chirp3-HD-Vindemiatrix`

已删除旧基准：

- `cmn-CN-Wavenet-C`

Google 参数：

- `speakingRate` 默认 `1.0`
- `pitch` 不发送给 Chirp3-HD，因为 Google 返回过：

```text
This voice does not support pitch parameters at this time.
```

Google 文本处理：

- Google chunk 长度当前是 `500`
- Google 单句保护当前是 `180`
- TTS 入口会清洗阅读器注音标记：
  - `⟪字⧸pinyin⟫` -> `字`
  - 未闭合的 `⟪字⧸pinyin` -> `字`
- Google provider 请求前还会做 Google 专用标点归一化：
  - `……` -> `. `
  - `。！？；` -> `. `
  - `，、,` -> `. `

Google 缓存：

- `tts_cache/google`
- 240 个文件
- 约 160 MB

## 听书跟读定位

目前刚做了最小闭环：

- `TtsService` 暴露：
  - `currentChunkText`
  - `currentChunkIndex`
  - `currentChunkTotal`
  - `sessionProgress`
- 悬浮听书控制条会显示：
  - `听书 x/y`
  - 当前 chunk 的前一小段文本
- 竖向阅读页尝试高亮当前 chunk 开头的一段文本
- 阅读页会按 TTS session 进度自动跳转：
  - 竖向：滚动到大致百分比
  - 横向：跳到大致页码

注意：

- 这是粗粒度同步，不是逐字/逐句高亮。
- 横向阅读目前只做自动翻页，未做页内高亮。
- 竖向高亮依赖文本匹配，如果阅读器显示文本和 TTS 清洗后的文本不一致，可能匹配不到。

## 已知问题 / 风险

- 这个仓库有不少历史中文乱码，修改时要小心字符串被破坏。
- `dart analyze` 和 `dart format` 在当前环境里多次超时，最终验证主要靠 `flutter run`。
- Google TTS 对中文长句很敏感，会报：

```text
This request contains sentences that are too long.
```

目前已经加了 Google 专用处理，但还需要继续实机验证。

- 云端 TTS 分块播放仍然不是完全无缝。
  - 预取可以减少等待网络的停顿。
  - 但播放器切换 mp3 文件仍会有一点间隔。
  - 后续如果要继续优化，可以考虑 `just_audio` 播放队列。

- Google / 火山 API Key 不应提交。
  - `tools/` 已加入 `.gitignore`
  - `temp_epub_debug.dart` 已加入 `.gitignore`
  - 真实 key 目前只应出现在本地忽略目录或 App 的本地存储中。

## 临时脚本

`tools/` 已被 `.gitignore` 忽略。

当前主要脚本：

- `tools/volcengine_tts_smoke_test.py`
- `tools/test_google.py`

这些脚本只用于本地测试，不要提交。脚本里可能有真实 API Key。

## 推荐下一步

1. 先跑：

```powershell
E:\flutter\bin\flutter.bat run -d 127.0.0.1:7555
```

2. 重点验证：

- Google TTS 是否还报 long sentence
- Google TTS 播放停顿是否可接受
- 火山 TTS 1.0 的 5 个预设是否正常
- 听书悬浮控制条暂停 / 恢复状态是否同步
- 竖向阅读是否能高亮当前播放段落
- 横向阅读是否能按 TTS 进度自动翻页

3. 如果 Google 仍然停顿明显：

- 先考虑 `just_audio` 播放队列
- 再考虑更大 chunk 或章节级预生成

4. 如果 Google 仍然报句子过长：

- 降低 `_googleMaxSentenceLen`
- 或在 Google provider 里进一步把特殊符号、冒号、破折号等转换为 `. `
