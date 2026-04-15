# hikari-novel-sec

一个基于 Flutter 的小说阅读客户端，主要面向 Android 使用。

这个仓库是在 [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter) 的基础上继续整理和实验的个人维护版本，也参考了 [wenku8reader](https://github.com/15dd/wenku8reader) 的部分资源与思路。当前重点不再只是“能读小说”，而是围绕阅读器加入 AI 章节分析、人物状态记忆和关系图谱整理能力。

当前维护仓库：[hikari-novel-sec](https://github.com/Renakoni/hikari-novel-sec)

<div align="center">
  <img src="./assets/images/logo_transparent.png" alt="Logo" height="220">
</div>

## 当前定位

Hikari Novel Sec 是一个偏实验性质的个人阅读器。

它保留基础阅读、书架、本地导入、听书等能力，同时重点加入了 AI 阅读辅助：

- 分析当前章节的剧情概要
- 提取人物状态
- 合并人物别名、代号和身份
- 维护人物关系状态
- 建立本书级别的 AI 记忆
- 对超长章节做分块分析和递归聚合
- 通过本地日志观察 AI 请求、响应和合并过程

项目当前不提供现成 APK Release，默认按“自行编译、自行配置、自行使用”的方式维护。

## 主要功能

### 阅读器

- 小说浏览、搜索、书架、详情页、章节目录
- 阅读进度保存与继续阅读
- 章节缓存
- 深色 / 浅色模式
- 横向翻页和竖向滚动
- 平板适配
- 书架标签筛选与搜索

### 本地导入

当前导入入口统一为“导入电子书”，再选择格式。

支持：

- EPUB：使用现有阅读器逻辑，支持章节、封面和章节内图片
- Markdown：作为单篇 Markdown 阅读，不做章节分割
- TXT：当前按单篇连续文本导入，保留换行格式；章节切分后续再做

本地书会自动加入书架，并带有默认标签。导入记录、章节缓存和阅读进度可以从书架或书籍详情中清理。

### 听书

听书目前支持三类来源：

- Android 系统 TTS
- 火山引擎 TTS
- Google Cloud TTS

听书支持：

- 悬浮控制条
- 暂停 / 继续 / 停止
- 播完当前章后自动进入下一章
- 云端 TTS 音色配置

云端 TTS 需要自行配置 API Key、模型或音色参数。请不要把自己的密钥提交到公开仓库。

## AI 章节分析

AI 分析是当前版本的主要实验方向。

### 支持范围

当前 AI 分析主要面向：

- 网络小说章节
- 本地 EPUB

Markdown / TXT 暂不默认启用 AI 分析，主要是为了避免未分章文本直接导致请求过大或上下文失控。

### Provider 配置

阅读设置中有独立的 AI 页，可以配置：

- Base URL
- API Key
- Model
- Temperature
- 最大请求 Tokens
- 最大回复 Tokens
- 系统提示词
- 用户提示词模板
- 合并阶段提示词

也支持：

- 拉取模型列表
- 测试连接
- 预览当前 Prompt
- 预览合并阶段 Prompt
- 恢复默认提示词

接口按 OpenAI-compatible Chat Completions 风格接入，因此可以连接硅基流动、OpenAI-compatible 网关或其他兼容服务。

### 分析入口

阅读器顶部右侧有 AI 入口。

当前支持：

- 分析当前章节
- 查看本章分析结果
- 查看本书 AI 记忆

书籍详情页右上角菜单中可以清除本书 AI 缓存。

### 分析结果

章节分析结果包括：

- 章节总结
- 人物列表
- 人物重要性分层
- 人物别名
- 人物当前状态摘要
- 人物关系
- 关系强度
- 关系状态摘要

分析结果会保存到本地。只要不清理缓存，或者不重新分析当前章节，已有分析结果会继续保留。

### 本书 AI 记忆

每次章节分析完成后，会同步更新本书级别的 AI 记忆：

- 最近章节总结
- 章节大纲摘要
- 人物状态
- 人物别名
- 人物出现次数
- 人物关系状态
- 关系强度

这些信息会在后续章节分析时作为上下文的一部分传给模型，避免每一章都孤立分析。

### 超长章节处理

对于特别长的章节，当前不会再简单截断到请求上限。

现在的策略是：

- 单次请求只使用最大请求预算的约 4/5，给 Prompt、记忆和模型输出留余量
- 超过预算的章节自动分块
- 分块时优先在句末、段落末尾或换行处切分
- 每个分块单独做结构化抽取
- 分块结果再递归聚合成完整章节分析
- 聚合后的结果继续进入本书级别的人物和关系记忆合并流程

这套逻辑主要是为了处理《罪与罚》这类单章非常长的文本，避免后半章完全被截断，也避免一次请求塞入过多内容导致模型幻觉或遗漏。

### AI 日志

调试阶段会写入 AI 相关日志，便于检查：

- Provider 配置
- 模型拉取
- 请求长度
- Prompt 预览
- 响应预览
- 分块分析过程
- 合并过程
- 异常信息

API Key 会脱敏记录。

Android 上日志会尽量写到容易导出的目录，开发工具页也提供了查看与清理入口。

## 当前限制

- AI 分析结果依赖上游模型质量，不保证完全准确
- 人物别名和关系合并仍可能出错
- 重大事件提取、事件时间线、可交互关系图谱还没有正式做
- Markdown / TXT 的 AI 分析暂未开放
- 云端 TTS 和 AI Provider 都需要可用网络与额度
- Cloudflare、站点风控、代理环境可能影响网络小说加载

## 平台说明

| 平台 | 状态 | 备注 |
| --- | --- | --- |
| Android | 主要目标 | 当前主要维护和测试平台 |
| Windows | 可编译 / 调试 | 更适合开发，不建议作为正式阅读平台 |
| iOS / macOS | 未实测 | 理论可编译，不保证可用 |
| Linux / Web | 非当前目标 | 未适配 |

## 截图

### 手机

<div align="center">
  <img src="./readme/1.jpg" width="30%">
  <img src="./readme/2.jpg" width="30%">
  <img src="./readme/3.jpg" width="30%">
</div>

### 平板

<div align="center">
  <img src="./readme/1_tablet.png" width="80%">
  <img src="./readme/2_tablet.png" width="80%">
</div>

## 编译

大致步骤：

1. 安装 Flutter
2. 安装 Android Studio / Android SDK
3. 克隆仓库
4. 安装依赖
5. 编译或运行

常用命令：

```bash
flutter pub get
flutter run
flutter build apk --debug
flutter build apk --release
```

如果只是验证功能，建议先打 `debug` 包。

## 使用注意

- 当前不提供 APK Release
- 不建议提交自己的 API Key、Access Key 或代理配置
- 本项目更偏个人自用和实验，不保证所有站点、所有设备都稳定
- 如果遇到 Cloudflare 拦截，优先用真机和稳定网络环境排查
- 如果 AI 分析返回异常，先查看 AI 日志和 Provider 配置

## 声明

- 本项目仅用于学习、研究和个人使用
- 项目内容与相关站点官方无关
- 请不要将本仓库理解为任何站点的官方客户端
- 如果继续分发、二次发布或公开传播，请自行承担相应责任

## 致谢

这个版本是在以下项目基础上继续整理和修改的：

- [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter)
- [wenku8reader](https://github.com/15dd/wenku8reader)

同时也参考过这些项目在交互、结构或实现思路上的经验：

- [flutter_dmzj](https://github.com/xiaoyaocz/flutter_dmzj)
- [venera](https://github.com/venera-app/venera)
- [mihon](https://github.com/mihonapp/mihon)
- [mikan_flutter](https://github.com/iota9star/mikan_flutter)
- [pilipala](https://github.com/guozhigq/pilipala)
- [PiliPalaX](https://github.com/orz12/PiliPalaX)
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
