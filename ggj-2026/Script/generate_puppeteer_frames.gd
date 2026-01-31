@tool
extends EditorScript

## 在编辑器中运行此脚本（文件 -> 运行，或 Ctrl+Shift+X），
## 会从 Art 文件夹中的傀儡师动画图片（0030～0120）里按“选帧”规则生成 SpriteFrames 资源。
##
## 选帧规则（在 _run 里可改）：
##   start_frame = 30  起始帧号（含）
##   end_frame = 120   结束帧号（含）
##   step = 1         取帧步长：1=全部，2=每隔一帧，3=每隔两帧……
##
## 生成文件：res://Art/puppeteer_sprite_frames.tres

const ART_DIR := "res://Art/"
const OUTPUT_PATH := "res://Art/puppeteer_sprite_frames.tres"
const ANIM_NAME := "idle"
const FRAME_DURATION := 1.0 / 15.0  # 约 15 帧/秒
const ANIM_SPEED := 5.0
const ANIM_LOOP := true

func _run() -> void:
	var start_frame: int = 30
	var end_frame: int = 46
	var step: int = 1  # 1=全部约91帧，2=约45帧，3=约30帧

	var paths: Array[String] = _collect_puppeteer_frames(start_frame, end_frame, step)
	if paths.is_empty():
		print("未找到傀儡师动画图片，请确认 Art 下有 傀儡师动画_0030_图层 xx.jpg ～ 傀儡师动画_0120_图层 xx.jpg")
		return

	var sf := SpriteFrames.new()
	sf.add_animation(ANIM_NAME)
	sf.set_animation_speed(ANIM_NAME, ANIM_SPEED)
	sf.set_animation_loop(ANIM_NAME, ANIM_LOOP)

	for path in paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			sf.add_frame(ANIM_NAME, tex, FRAME_DURATION)
		else:
			print("加载失败: ", path)

	var err := ResourceSaver.save(sf, OUTPUT_PATH)
	if err != OK:
		print("保存失败 ", OUTPUT_PATH, " 错误码: ", err)
		return
	print("已生成 ", OUTPUT_PATH, " 共 ", paths.size(), " 帧。可在 AnimatedSprite2D 的 Sprite Frames 中选用。")
	if step > 1:
		print("（当前 step=%d，仅使用部分帧；要全部帧请将 step 改为 1）" % step)

func _collect_puppeteer_frames(start_frame: int, end_frame: int, step: int) -> Array[String]:
	var prefix := "傀儡师动画_"
	var suffix := ".jpg"
	var by_number: Dictionary = {}  # frame_num -> file_path

	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		print("无法打开目录: ", ART_DIR)
		return []

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.ends_with(suffix) or not file_name.begins_with(prefix):
			file_name = dir.get_next()
			continue
		# 傀儡师动画_0030_图层 91.jpg -> 取 0030
		var mid := file_name.substr(prefix.length(), 4)
		if mid.is_valid_int():
			var num: int = int(mid)
			if num >= start_frame and num <= end_frame:
				by_number[num] = ART_DIR.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	var ordered: Array[String] = []
	var nums: Array = by_number.keys()
	nums.sort()
	var i := 0
	for num in nums:
		if i % step == 0:
			ordered.append(by_number[num])
		i += 1
	return ordered
