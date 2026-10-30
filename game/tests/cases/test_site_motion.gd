extends RefCounted
## 相机基与行走方向：W 必须朝屏幕深处（远离相机），而不是朝镜头走。


func run(report: TestReport) -> void:
	report.begin("site_motion")

	var camera := Node3D.new()
	var axes := SiteMotion.camera_axes(camera)
	report.ok((axes[0] as Vector3).is_equal_approx(Vector3(1, 0, 0)), "相机右轴是 +X")
	report.ok((axes[1] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "前进轴指向 -Z（远离相机）")

	# 按 W（dz=+1）时位置应朝 -Z 移动。
	var start := Vector2(0, 0)
	var walked := SiteMotion.walk(start, 0.0, 1.0, 0.5, axes[0], axes[1])
	report.ok((walked["position"] as Vector2).y < start.y, "W 向屏幕上方移动")
	report.ok((walked["position"] as Vector2).x == 0.0, "W 不产生横向偏移")

	# 按 D（dx=+1）时朝 +X 移动。
	var strafed := SiteMotion.walk(start, 1.0, 0.0, 0.5, axes[0], axes[1])
	report.ok((strafed["position"] as Vector2).x > start.x, "D 向右移动")
	camera.free()
