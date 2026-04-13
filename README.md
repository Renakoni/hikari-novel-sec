# hikari-novel-sec

基于 Flutter 的轻小说阅读客户端，主要面向 Android 使用。

这个仓库是我在 [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter) 的基础上继续整理的个人维护版本，同时也参考和沿用了 [wenku8reader](https://github.com/15dd/wenku8reader) 的部分资源与思路。当前不提供现成 APK，默认按“自行编译、自行使用”的方式维护。

## 说明与来源

这个版本不是从零重写的项目，而是在原项目基础上继续调整：

- 补本地 EPUB 导入、阅读和清理流程
- 调整书架、标签和筛选体验
- 扩展听书功能，保留系统 TTS，并加入火山引擎 TTS 的实验支持
- 做一些适合个人使用的工程整理和小修复

这个仓库能继续往前做，离不开原作者和历史贡献者前面的工作。建议第一次接触这个项目的人也去看看原仓库：

- [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter)
- [wenku8reader](https://github.com/15dd/wenku8reader)

<div align="center">
  <img src="./assets/images/logo_transparent.png" alt="Logo" height="220">
</div>

## 项目状态

- 主要维护目标：Android
- 当前不发布 APK Release
- 需要自行配置 Flutter / Android 环境后编译
- 更适合已有基础开发经验、愿意自己折腾的人使用

## 功能概览

- 基础浏览、搜索、书架、详情、阅读
- 阅读进度保存与继续阅读
- 章节缓存
- 深色 / 浅色模式
- 平板适配
- 本地 EPUB 导入
- 本地书加入书架
- 本地书与网络书的个人标签
- 书架标签多选筛选
- 本地书移除、导入记录与缓存清理
- 系统 TTS 听书
- 火山引擎 TTS 实验支持
- Google Cloud TTS 实验支持

## 本地 EPUB

本地 EPUB 目前已经接入到现有阅读流程里：

- 导入 `.epub`
- 自动加入书架
- 使用现有阅读器阅读
- 记录阅读进度
- 显示继续阅读
- 支持本地封面和章节内图片
- 支持个人标签
- 支持从书架移除
- 支持删除导入记录并清理缓存文件

说明：

- 本地书会带有 `Local`、`EPUB` 这类默认标签
- 默认标签不可删除
- 个人标签可以自行添加和删除
- 删除导入记录和缓存文件属于不可逆操作

## 听书

听书目前有两条路线：

- 系统 TTS：调用 Android 系统的 Text-to-Speech 引擎，稳定性取决于手机系统和已安装的 TTS 引擎。
- 火山引擎 TTS：实验功能，当前默认按豆包语音合成模型 1.0 接入，`Resource ID` 默认是 `seed-tts-1.0`。
- Google Cloud TTS：实验功能，当前按 Cloud Text-to-Speech 接入，内置了一组 `cmn-CN-Chirp3-HD` 普通话音色。

火山引擎模式目前内置了几个常用音色预设，设置页里可以直接选择，也保留了手动输入 `Speaker` 的方式。API Key、App ID 等参数需要用户自己在火山控制台获取和填写。
Google 模式需要用户自己填写 Google Cloud TTS API Key。Google 的 `speakingRate` 和 `pitch` 使用独立参数，不和系统 TTS 的语速、音调范围混用。

注意：

- 云端 TTS 需要网络和可用额度
- 不建议把自己的 Access Key 提交到公开仓库
- 小说长文本会被分块请求，实际听感仍然会受音色、模型和文本结构影响

## 平台说明

| 平台 | 状态 | 备注 |
| --- | --- | --- |
| Android | 可用 | 主要维护目标 |
| Windows | 可编译，体验一般 | 更适合调试，不建议作为正式使用平台 |
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
5. 编译 APK

常用命令：

```bash
flutter pub get
flutter run
flutter build apk --debug
flutter build apk --release
```

如果只是想先验证功能，建议先打 `debug` 包。

## 使用说明

- 默认依赖文库站点相关接口
- 网络环境、节点状态、站点风控都会影响使用
- 模拟器环境比真机更容易触发风控
- 如果遇到 Cloudflare 拦截，优先换真机测试

## 安装包说明

这个仓库不提供 APK Release。

原因很简单：

- 项目更偏个人自用和学习
- 站点环境和风控并不稳定
- 公开分发安装包没有必要，也容易带来额外问题

如果你确实需要使用，建议自己编译。

## 版本说明

这里不会把每次小改动都写成很长的更新日志。README 只保留当前版本的重要能力和使用注意事项；具体变更以 Git 提交记录为准。

如果后续功能变化比较大，再单独维护 `CHANGELOG.md` 会更合适。

## 声明

- 本项目仅用于学习、研究和个人使用
- 项目内容与相关站点官方无关
- 请不要将本仓库理解为官方客户端
- 如果你打算继续分发、二次发布或公开传播，请自行承担相应责任

## 致谢

再次感谢原作者及相关历史贡献者，这个版本是在以下项目基础上继续整理和修改的：

- [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter)
- [wenku8reader](https://github.com/15dd/wenku8reader)

同时也感谢这些项目在交互、结构或实现思路上提供的参考：

- [flutter_dmzj](https://github.com/xiaoyaocz/flutter_dmzj)
- [venera](https://github.com/venera-app/venera)
- [mihon](https://github.com/mihonapp/mihon)
- [mikan_flutter](https://github.com/iota9star/mikan_flutter)
- [pilipala](https://github.com/guozhigq/pilipala)
- [PiliPalaX](https://github.com/orz12/PiliPalaX)
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
