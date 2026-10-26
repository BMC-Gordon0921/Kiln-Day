class_name TestReport
extends RefCounted
## 极简断言收集器。刻意不引入第三方测试框架：S0 只需要"能失败、能定位"。

var passed := 0
var failed := 0

var _suite := ""

func begin(suite_name: String) -> void:
	_suite = suite_name
	print("\n== %s ==" % suite_name)

func ok(condition: bool, label: String, detail: String = "") -> bool:
	if condition:
		passed += 1
		print("  ok   %s" % label)
		return true
	failed += 1
	print("  FAIL %s%s" % [label, "" if detail.is_empty() else "  <- " + detail])
	return false

func eq(actual: Variant, expected: Variant, label: String) -> bool:
	return ok(_same(actual, expected), label, "期望 %s，实际 %s" % [str(expected), str(actual)])

func error(label: String) -> void:
	ok(false, label)

func finish() -> int:
	print("\n通过 %d，失败 %d" % [passed, failed])
	return failed

func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var na := ta == TYPE_INT or ta == TYPE_FLOAT
	var nb := tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb:
		return is_equal_approx(float(a), float(b))
	if ta != tb:
		return false
	return a == b
