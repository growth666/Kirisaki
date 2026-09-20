# DanbooruSearchOnline 本地词库

来源：https://github.com/SuzumiyaAkizuki/DanbooruSearchOnline

作者：SuzumiyaAkizuki；上游提交：`6cf30e7d38b729eb18fe8903f242dbbc5ce13399`。

原始文件：`origin_database/tags_enhanced.csv`。上游仓库 GPL-3.0 许可证随包保存在 `DanbooruSearchOnline-LICENSE.txt`，未发现数据单独许可证。本文件及许可证应随词库分发保留；不将第三方数据宣称为 Kirisaki 自有素材。

本地修改：GBK 解码，筛选类别 0/3/4，拆分中文别名，去重并按热度排序，移除本轮不用的 wiki 释义，转换成 UTF-8 JSON。原始 53,300 行得到 53,296 个标签。JSON 内记录原文件 SHA-256；文件约 4.37 MB。复现方式：

```text
python tool/import_search_dictionary.py /path/to/tags_enhanced.csv
```

`danbooru_local.json` 属于上述上游数据的转换版本，保留 GPL-3.0 许可。原始可编辑 CSV 可从上述固定提交取得；转换脚本随项目提供。此次未复制上游检索引擎代码，也未更改整个应用的许可证。

检索只使用中文别名的精确、前缀和子串匹配；没有引入语义模型或 API。使用字符索引减少逐次扫描量，原生平台 JSON 转换在 isolate 中进行。候选上限 8，提交后的精确候选上限 30。

现有 `keywords.json` 保留为纠错、昵称及 Zerochan 专用映射层。Zerochan 对没有独立映射的导入词条使用英文标签作为站点 `/suggest?q=` 查询线索（下划线转为空格），展示站点候选供用户确认后才搜图；不把该线索视为已验证的 Zerochan 标签。成功候选在当前服务实例中最多缓存 100 项，不持久化。无法匹配、网络错误时提示用户修改或重试，没有自动翻译或自动选择首项。

上游 NSFW 标记非 0 的本地候选在关闭内容开关时隐藏，不代表未标记条目均安全。Zerochan 提示接口返回的候选没有可靠的内容评级；搜索图片仍沿用现有过滤。

尚未对全部标签完成站点联网验证；词库内容可能有误译、旧标签或匹配歧义。Safebooru 与 Danbooru 标签体系也不完全一致。
