<div align="center">

<img src="kirisaki_app/assets/branding/preview.png" width="144" alt="Kirisaki 应用图标" />

# Kirisaki

**发现喜欢的二次元图片，收藏属于自己的灵感。**

基于 Flutter 的跨平台二次元图片搜索与浏览客户端

![状态](https://img.shields.io/badge/状态-开发中-E95869)
![Flutter](https://img.shields.io/badge/Flutter-跨平台-02569B?logo=flutter)
![平台](https://img.shields.io/badge/优先适配-Windows%20%7C%20Android-E9B953)

[功能介绍](#已实现功能) · [快速开始](#快速开始) · [开发计划](#开发计划) · [问题反馈](https://github.com/growth666/Kirisaki/issues)

</div>

> **项目正在开发中，尚不代表正式稳定版本。** 功能、界面和图源配置仍会调整。欢迎试用和反馈，不同设备及网络环境下的体验可能存在差异。

## 关于项目

Kirisaki 的名字灵感来自《伪恋》中的桐崎千棘。项目将图片推荐、关键词搜索、原图预览与本地收藏整合在一起，希望提供简洁、顺手的二次元图片浏览体验。

目前由客户端直接访问图源，收藏、历史和设置保存在本地，不需要登录账号，也没有项目自建的云端数据库或图片中转服务。

## 已实现功能

| 模块 | 当前功能 |
| --- | --- |
| 图片发现 | 推荐图片流、瀑布流展示、关键词搜索与分页加载 |
| 多图源搜索 | 切换内置图源；部分 Danbooru、Zerochan 人物名称支持候选标签选择 |
| 图源管理 | 内置源启用 / 禁用；自定义源 JSON 导入、编辑、启用 / 禁用和删除；重复 ID 校验 |
| 图片预览 | 原图查看、收藏与下载；Zerochan 原图地址解析 |
| 本地收藏 | 收藏图片及管理收藏列表 |
| 历史记录 | 浏览历史、搜索历史、下载记录与个人数据概览 |
| 内容显示 | “我的 → 内容显示”提供 18+ 内容显示开关，默认关闭 |
| 网络设置 | 原生平台 HTTP 代理配置，覆盖搜索、缩略图、原图及下载请求 |
| 外观与设置 | 亮色 / 暗黑 / 跟随系统、下载位置设置、缩略图缓存清理、本地数据清理 |
| 贡献者展示 | “我的 → 贡献者榜单”展示特别鸣谢名单 |

### 当前内置图源

| 图源 | 用途与说明 |
| --- | --- |
| Safebooru | 关键词搜索，使用 DAPI 接口 |
| Danbooru (Safe) | 使用 `safebooru.donmai.us`，按站点标签搜索 |
| Zerochan | 关键词搜索；部分同名角色可选择具体人物条目 |
| Alcy 推荐源 | 推荐图片流，独立于搜索图源管理 |

图源来自第三方网站，可用性会随接口、网络和访问限制变化，不承诺所有地区均可直连。既往测试结果与未验证项见 [图源核验记录](kirisaki_app/docs/source-verification.md)。

## 平台与当前限制

- **Windows / Android**：优先开发和适配的平台。Windows 已有部分实测记录；Android 仍需持续真机验收，构建成功不等于全部功能均已验证。
- **Web**：保留工程支持，但受第三方图源 CORS 限制，部分功能（包括推荐流）可能无法使用。
- **iOS / macOS / Linux**：保留平台工程，不代表已经完成构建、发布或完整功能验收。
- **关键词**：优先使用图源认可的英文标签或角色全名；尚未实现中文名称自动翻译。候选标签不等同于全站模糊搜索。
- **内容显示**：依赖图源及标签规则，不保证完整识别或过滤所有成人内容。开启显示也不会解除 Safe 图源自身的限制。
- **代理**：支持 HTTP / mixed 端口，不支持将 SOCKS-only 端口直接作为 HTTP 代理。Android 的 `127.0.0.1` 指手机自身，使用电脑代理时需填写手机可达的局域网地址。
- **数据**：尚无账号、跨设备同步或云端备份。

## 快速开始

需要 Flutter SDK 和对应平台的开发工具链。当前项目要求 **Dart `^3.13.1`**，请使用包含兼容 Dart 版本的 Flutter SDK。

```bash
git clone https://github.com/growth666/Kirisaki.git
cd Kirisaki/kirisaki_app
flutter doctor
flutter pub get
flutter devices
flutter run
```

指定设备运行：

```bash
flutter run -d windows
flutter run -d <设备ID>
```

Windows 构建需在配置好桌面开发工具链的 Windows 环境执行；Android 需配置 Android SDK 和设备或模拟器。

### 检查与构建

在 `kirisaki_app` 目录执行：

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```

以上为本地操作指令，不代表当前提交已通过全部检查。正式分发 Android 包前还需配置发布签名并保管密钥。真实网络图源测试单独开启，详见 [核验记录](kirisaki_app/docs/source-verification.md#reproduction)。

## 项目结构

```text
Kirisaki/
├── README.md
└── kirisaki_app/
    ├── lib/
    │   ├── core/          # 图源、网络、下载、存储、主题与路由
    │   └── features/      # 搜索、预览、收藏、我的、设置等页面
    ├── assets/branding/   # 应用图标、原图及预览
    ├── docs/             # 图源核验等开发记录
    ├── test/             # 单元、页面及可选真实网络测试
    └── tool/             # 图标资源生成工具
```

主要使用 Flutter / Dart、Material Design、go_router、HTTP / Dio、HTML 解析及 shared_preferences 等组件。

## 开发计划

以下为后续方向，**尚未完成，不代表交付时间承诺**：

- [ ] 持续改进图源兼容性、搜索提示与错误处理。
- [ ] 补充 Android 真机及不同网络环境的验收。
- [ ] 完善内容分级识别和显示控制。
- [ ] 完善正式发布签名、安装包和版本说明流程。
- [ ] 增加应用内版本检查与更新引导。
- [ ] 探索远程公告及可回退的图源配置更新。

账号同步、消息推送和完整下载任务管理目前尚未实现。

## 反馈与参与

欢迎通过 [Issues](https://github.com/growth666/Kirisaki/issues) 反馈问题或提出建议。问题报告请包含系统及应用版本、图源、关键词、网络方式、复现步骤和错误截图，请勿上传密码、代理凭据或其他隐私信息。

提交功能改动前，建议先通过 Issue 说明需求与范围；提交时附上改动说明和实际验证结果。

## 特别鸣谢

感谢 **失去重力**、**徐氏** 对项目的支持。应用内贡献者榜单按原鸣谢顺序展示，不代表贡献排名。

## 素材说明

图片与角色素材的权利归各自权利人所有。当前图标使用提供的角色图片裁切制作。仓库目前没有附带 LICENSE 文件，代码许可与第三方素材授权需分别明确。
