# hikari-novel-sec

基于 Flutter 的轻小说阅读客户端。

这个仓库是我基于原项目继续整理和自用的版本，主要目标还是 Android。当前不提供现成安装包，默认按“自行编译、自行使用”的方式维护。

## 说明与来源

这个项目基于原作者的 [hikari_novel_flutter](https://github.com/15dd/hikari_novel_flutter) 和 [wenku8reader](https://github.com/15dd/wenku8reader) 继续整理而来。

我这边做的主要是：

- 补本地 EPUB 导入与管理
- 调整书架、标签和筛选
- 补一些本地阅读相关能力
- 做适合自己使用的工程整理

这个仓库能继续往前做，离不开原作者前面的工作。无论是整体思路、基础功能，还是很多早期实现，核心来源都在上面两个项目里。

这里单独表示感谢，也建议第一次接触这个项目的人顺手去看看原仓库。

<div align="center">
  <img src="./assets/images/logo_transparent.png" alt="Logo" height="220">
</div>

## 项目现状

- 主支持平台：Android
- 当前仓库不发布 APK
- 需要自行配置 Flutter / Android 环境后编译
- 适合已经有基本开发经验、愿意自己折腾的人

## 目前有的功能

- 基础浏览、搜索、书架、详情、阅读
- 阅读进度保存与继续阅读
- 章节缓存
- 深色 / 浅色模式
- 平板适配
- 本地 EPUB 导入
- 本地书加入书架
- 本地书个人标签
- 书架标签筛选
- 本地书删除与文件清理

## 本地 EPUB 支持情况

目前已经支持一套最小但可用的本地书流程：

- 导入 `.epub`
- 自动加入书架
- 使用现有阅读器阅读
- 记录阅读进度
- 显示继续阅读
- 为本地书添加个人标签
- 从书架移除
- 删除导入记录
- 删除导入记录并清理缓存文件

说明：

- 本地书会带有 `Local`、`EPUB` 这类默认标签
- 默认标签不可删除
- 个人标签可以自行添加和删除

## 平台说明

| 平台 | 状态 | 备注 |
| --- | --- | --- |
| Android | 可用 | 主要维护目标 |
| Windows | 可编译，体验一般 | 更适合调试，不建议当正式使用平台 |
| iOS / macOS | 未实测 | 理论可编译，不保证可用 |
| Linux / Web | 不作为当前目标 | 未适配 |

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

我的环境里至少验证过 Android 编译链可以正常工作。大致步骤：

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

如果只是想先验证功能，先打 `debug` 包最省事。

## 使用说明

- 默认依赖文库站点相关接口
- 网络环境、节点状态、站点风控都会影响使用
- 模拟器环境比真机更容易触发风控
- 如果遇到 Cloudflare 拦截，优先换真机测试

## 安装包说明

这个仓库不提供 APK Release。

原因很简单：

- 这个项目更偏自用和学习
- 站点环境和风控并不稳定
- 公开分发安装包没必要，也容易带来额外问题

如果你确实需要使用，建议自己编译。

## 说明

- 本项目仅用于学习、研究和个人使用
- 项目内容与相关站点官方无关
- 请不要将本仓库理解为官方客户端
- 若你打算继续分发、二次发布或公开传播，请自己承担相应责任

## 致谢

- [flutter_dmzj](https://github.com/xiaoyaocz/flutter_dmzj)
- [venera](https://github.com/venera-app/venera)
- [mihon](https://github.com/mihonapp/mihon)
- [mikan_flutter](https://github.com/iota9star/mikan_flutter)
- [pilipala](https://github.com/guozhigq/pilipala)
- [PiliPalaX](https://github.com/orz12/PiliPalaX)
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
