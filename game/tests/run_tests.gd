extends SceneTree
## 无头测试入口：`godot --headless --path game --script res://tests/run_tests.gd`
##
## 约定：测试用例是不依赖 autoload 的纯逻辑脚本（extends RefCounted，实现 run(report)）。
## 需要场景树/自动加载的用例放到 tests/integration/，另开一个入口，别混进来。

const SUITES := [
	"res://tests/cases/test_constants.gd",
	"res://tests/cases/test_catalog.gd",
	"res://tests/cases/test_manifest.gd",
	"res://tests/cases/test_content_pack.gd",
	"res://tests/cases/test_assets.gd",
	"res://tests/cases/test_sculpture.gd",
	"res://tests/cases/test_workshop.gd",
	"res://tests/cases/test_slice.gd",
]

func _initialize() -> void:
	var report := TestReport.new()

	for path in SUITES:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			report.error("无法加载用例脚本：" + path)
			continue
		var suite: RefCounted = script.new()
		if suite == null or not suite.has_method("run"):
			report.error("用例脚本缺少 run(report)：" + path)
			continue
		report.begin(String(path).get_file())
		suite.run(report)

	var failures := report.finish()
	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TESTS FAILED: %d" % failures)
		quit(1)
