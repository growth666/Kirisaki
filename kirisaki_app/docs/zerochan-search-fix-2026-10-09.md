# Zerochan 搜索修复验收

日期：2026-10-09。平台：Windows 开发机，直连；Android 实机未验证。

同一网络中 `/NARUTO?json&p=1&l=2` 返回 HTTP 500，正文包含重复大括号、JSON 和 HTML；普通标签页返回 200。官方 XML 搜索接口返回 200，提供分页、标签、成人分级和缩略图。单图 JSON 详情正常。

修复：原生客户端遇到 Zerochan JSON 500/502 或无法解析的数据时，仅尝试一次官方 XML 接口。保留分页参数、同源重定向限制、内容过滤和原图详情解析。403/429 不触发备用请求。Web 暂不扩展。

验收：111 个图源及搜索页面回归测试通过；相关静态检查无问题。真实应用服务搜索 NARUTO 第一页和第二页成功，图片不同；单图原图解析、缩略图及原图 HTTP 下载成功。未测试 Android 相册写入。

复验命令：`flutter test --dart-define=RUN_ZEROCHAN_FALLBACK_LIVE=true test/live/zerochan_search_fallback_live_test.dart`。

限制：不能修复站点对客户端的 403 拒绝或网络不可达；官方要求的用户名配置和全局节流不属于本次搜索修复。
