extends RefCounted
## data/catalog.json：站点顺序、器物条数、字段完整性。

func run(t: TestReport) -> void:
	var catalog := Catalog.load_catalog()
	t.ok(not catalog.is_empty(), "catalog.json 可加载")
	t.eq(Catalog.validate(catalog).size(), 0, "catalog 校验无错误")

	t.eq(catalog.get("sites", []).size(), KilnConstants.SITE_IDS.size(), "站点数与常量一致")
	t.eq(Catalog.site(catalog, &"guyao").get("name", ""), "古窑民俗博览区", "guyao 名称")
	t.eq(Catalog.site(catalog, &"taoxichuan").get("decal", ""), "粉彩花瓣纹", "taoxichuan 贴画名")

	t.eq(catalog.get("items", []).size(), 5, "5 个器型")
	t.eq(Catalog.items_for_site(catalog).size(), KilnConstants.ORDERS_PER_SCENE, "每站取 3 单")
	t.eq(Catalog.item(catalog, &"moon-jar").get("name", ""), "青带月光罐", "moon-jar 名称")
	t.eq(Catalog.item(catalog, &"band-pot").get("customer", ""), "Mabel", "band-pot 顾客")

	t.ok(Catalog.site(catalog, &"__nope__").is_empty(), "未知站点返回空字典")
	t.ok(Catalog.item(catalog, &"__nope__").is_empty(), "未知器物返回空字典")
	t.ok(catalog.get("achievements", []).size() >= 3, "至少 3 个成就占位")
