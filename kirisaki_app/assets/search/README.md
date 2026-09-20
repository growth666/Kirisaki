# 中文搜索词库

当前已接入 DanbooruSearchOnline 的 53,296 条本地标签，来源、许可证及转换步骤见 [UPSTREAM.md](UPSTREAM.md)。下述 80 条数据现在作为人工纠错和 Zerochan 专用映射层保留，不再是全部词库。

最新联网核验：[2026-09-19 报告](../../docs/dictionary-audit-2026-09-19/README.md)。支持可选 `danbooru` 字段单独覆盖 Danbooru 标签；例如火影忍者在该站使用 `naruto_(series)`，其他 Booru 图源仍使用 `naruto`。

`keywords.json` 是随应用发布的离线词库，当前包含 80 个词条：42 个角色、2 个作品、36 个常用标签。无需联网翻译，首次加载后在内存中缓存；新增词条只需修改数据文件，重新构建应用。本轮不含远程更新或任意句子翻译。

角色覆盖 Re:Zero、VOCALOID、伪恋、某科学的超电磁炮、约会大作战、刀剑神域、火影忍者、魔卡少女樱、五等分的新娘、孤独摇滚、鬼灭之刃、间谍过家家、辉夜大小姐、青春猪头少年、新世纪福音战士。支持部分昵称和繁体名称，未收录的写法仍需输入全名或英文标签。

“小樱 / 小櫻”同时对应春野樱和木之本樱，由用户根据所属作品选择，不自动选择首项。

本轮抽查确认了 [Danbooru 的 Asuna 标签及别名](https://safebooru.donmai.us/wiki_pages/asuna_(sao))；Zerochan 的部分页面查询返回 502。该记录不代表新增角色已在所有图源完成搜索、分页及图片加载验收。

## 格式

```json
{
  "version": 1,
  "entries": [
    {
      "label": "樱花",
      "aliases": ["樱花", "櫻花"],
      "booru": "cherry_blossoms",
      "zerochan": "Cherry Blossoms"
    }
  ]
}
```

`label` 不可重复，`aliases` 为非空中文名称或别名列表；`booru` 用于 Safebooru 和 Danbooru（后者可用 `danbooru` 字段覆盖），`zerochan` 用于 Zerochan。TBIB 已移出内置名单。未明确的图源标签可以省略，但至少提供一种。自定义图源不自动套用这些映射。

同一别名允许对应多个不同条目，以便展示同名候选。输入去除首尾空白后精确匹配，不拆分“蕾姆 女仆”等组合，也不猜测未收录词。用户确认后才提交标签；词库加载失败会提示重试或使用英文。

词条是辅助搜索候选，并非全部图源的实时可用性保证。当前新增词条已通过格式及映射测试，尚未逐条完成真实网络搜索验收。发布前应检查目标图源的标签和结果；站点标签改变时更新对应字段。

验证：`flutter test test/core/source/chinese_search_dictionary_test.dart test/features/search/presentation/pages/search_page_test.dart`。
