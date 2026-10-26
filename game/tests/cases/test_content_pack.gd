extends RefCounted
## 双发行门控：desktop_full 与 web_demo 共用一份工程，靠 feature tag 切内容。

func run(t: TestReport) -> void:
	var ids := ContentPack.available_site_ids()
	t.ok(ids.size() >= 1, "至少开放 1 个站点")
	t.eq(ContentPack.is_demo(), OS.has_feature("demo"), "演示标记与 feature tag 一致")

	if ContentPack.is_demo():
		t.eq(ids.size(), 1, "试玩版只开放 1 站")
		t.eq(ContentPack.limits()["codex_max"], 4, "试玩版图鉴上限 4")
	else:
		t.eq(ids.size(), 4, "完整版开放 4 站")
		t.eq(ContentPack.limits()["codex_max"], -1, "完整版图鉴无上限")

	t.ok(ContentPack.is_site_available(ids[0]), "首站可用")
	t.ok(not ContentPack.is_site_available(&"__nope__"), "未知站点不可用")
	t.ok(ContentPack.limits()["allow_transfer_code"], "允许试玩版迁移码")
