# 中文词库图源标签联网核验

## 后续排查与修复

2026-09-19，Windows 直连，使用应用实际网络客户端复查：九个 Zerochan 失败标签均先返回 301，Location 丢失 JSON 与分页参数。正式标签直接请求有结果。现在原生端显式处理同源 HTTPS 重定向，保留 User-Agent、JSON 参数和分页参数，限制跳转次数并拒绝跨域及循环跳转。Web 受浏览器跳转机制限制，本轮未验证；词库使用正式标签也减少了重定向需求。

修正映射：Flowers → Flower、Cherry Blossoms → Cherry Blossom、Twintails → Twin Tails、Cat Ears → Nekomimi、Maid → Maid Outfit、Hyuga Hinata → Hyuuga Hinata、Yor Forger → Yor Briar。

另外，Starry Sky 指向同名作品 Starry☆Sky，不能代表风景星空，改为 Stars (Sky)；Bow 指向 Null，暂时移除 Zerochan 的“蝴蝶结”映射（其他图源保留），不以 Hair Bow 等更窄标签冒充通用词义。

应用客户端实测：八个修正后的正式标签、Cherry Blossoms 与 Yor Forger 两个旧别名，以及 Cherry Blossoms 第二页均返回图片。记录见 `zerochan-fixed.json` 和 `zerochan-redirects.json`。本轮未重新下载图片、未在 Android 实机复测。

TBIB：Dart 请求 TLS 握手失败，Windows curl 直连 tbib.org 和 www.tbib.org 均连接重置，尚未取得 HTTP 响应；不能归因于标签，也不能确定是网络路径还是站点策略。保持配置，不降级 HTTP、不关闭 TLS 校验。无可用代理或第二网络可供进一步对照，暂未解决。

[Zerochan 官方 API 说明](https://www.zerochan.net/api)要求 User-Agent 包含项目名称与 Zerochan 用户名，并限制每分钟 60 次请求。目前项目没有提供实际 Zerochan 用户名，因此不能声称访问身份已满足全部要求，也不伪造用户名。本轮实测成功不代表未来不会受访问限制。

时间：2026-09-19，首次请求 UTC 12:47 起。环境：Windows，Dart HTTP 客户端，直连，无代理。使用当前搜索地址构造器和 JSON 解析器，每个图源串行请求，间隔 750ms；连续三次失败后停止该站批量请求，剩余项明确记为跳过。

范围：80 个词条，四个内置搜索源；Zerochan 有两个词条未配置映射，因此为 78 项。仅核验第一页（limit=2）是否返回可解析的图片记录，不验证图片身份完全准确、图片下载、分页、Android 或国内普遍可达性。未应用客户端内容过滤，因此“有结果”不保证当前内容设置下一定显示图片。

| 图源 | 有图片记录 | 空结果 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| Safebooru | 80 | 0 | 0 | 0 |
| Danbooru Safe | 79 | 1 | 0 | 0 |
| Zerochan | 69 | 0 | 9 | 0 |
| TBIB Safe | 0 | 0 | 3 | 77 |

## 已修正

Danbooru 的 `naruto` 两次返回 HTTP 200 空列表，`naruto_(series)` 返回两条图片记录。词库新增可选 `danbooru` 字段，优先于共享 `booru` 字段，仅修正此站的“火影忍者”映射。Safebooru 原标签仍有结果，不替换。

## 未归因到标签的失败

- TBIB：三次 TLS 握手中断，尚未收到 HTTP 响应。不是空结果，也不能证明标签无效。后续独立复查两个标签仍握手失败。
- Zerochan：Starry Sky、Flowers、Cherry Blossoms、Twintails、Cat Ears、Maid、Bow、Hyuga Hinata、Yor Forger 返回 503。前三项复查仍返回 503，随后按阈值停止。
- Zerochan 对照复查：Rem (Re:Zero)、Scenery 和再次请求 Rem 均有结果；Hyuga Hinata、Yor Forger、Cherry Blossoms 仍返回 503。说明当前连接下存在请求相关的失败，但不能仅凭 HTTP 状态判断是源站防护、上游故障还是标签路径问题。本轮没有取得 404，也不修改这九项映射。

JSON 文件记录每项时间、请求地址、状态和错误；不保存图片。脚本的测试成功仅代表核验完成，图源成功与否以逐项结果为准。

## 重现

在应用目录执行：

```bash
flutter test --no-pub test/live/dictionary_live_test.dart --dart-define=RUN_DICTIONARY_LIVE=true
```

结果写入 `build/dictionary-checks/`。正常单元测试默认跳过联网核验。可使用 `DICTIONARY_FILE`、`AUDIT_FOLDER` dart-define 指定复查词库与输出目录。
