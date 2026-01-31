@tool
extends EditorScript
## 从 Art 里傀儡师动画 30–120 中选取若干帧，生成 SpriteFrames 资源。
## 用法：在编辑器菜单 文件 -> 运行 中选本脚本，或在场景里放一个节点挂此脚本（@tool）后运行一次。
## 生成后的 .tres 可赋给 Supervisor 的 AnimatedSprite2D。

const ART_DIR := "res://Art/"
const FILE_PREFIX := "傀儡师动画_"
const FILE_SUFFIX := ".jpg"
const FRAME_START := 30
const FRAME_END := 120
const OUTPUT_PATH := "res://Art/傀儡师_sprite_frames.tres"

func _run() -> void:
	# 选取方式：step=1 用全部 30–120；step=2 用 30,32,34,...；step=3 用 30,33,36,...
	var step: int = 1
	# 可选：只取某一段，例如 50–80；设为 -1 表示用 FRAME_START/FRAME_END
	var range_start: int = -1
	var range_end: int = -1

	var paths: PackedStringArray = _collect_frame_paths(step, range_start, range_end)
	if paths.is_empty():
		print("未找到傀儡师帧图，请检查 Art 目录下是否有 傀儡师动画_0030_*.jpg 等文件。")
		return

	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	var duration: float = 1.0
	var fps: float = 10.0
	duration = 1.0 / fps
	for path in paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			sf.add_frame("idle", tex, duration)

	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", fps)

	var err: Error = ResourceSaver.save(sf, OUTPUT_PATH)
	if err == OK:
		print("已生成: ", OUTPUT_PATH, " (共 ", paths.size(), " 帧)。请将该 SpriteFrames 赋给 Supervisor 的 AnimatedSprite2D。")
	else:
		print("保存失败: ", OUTPUT_PATH, " error=", err)

func _collect_frame_paths(step: int, range_start: int, range_end: int) -> PackedStringArray:
	var list: Array = []
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return PackedStringArray()

	var use_start: int = FRAME_START if range_start < 0 else range_start
	var use_end: int = FRAME_END if range_end < 0 else range_end

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not file_name.begins_with(FILE_PREFIX) or not file_name.ends_with(FILE_SUFFIX):
			file_name = dir.get_next()
			continue
		# 傀儡师动画_0030_图层 91.jpg -> 取 0030
		var rest: String = file_name.trim_prefix(FILE_PREFIX)
		var num_str: String = ""
		for i in rest.length():
			var c: String = rest[i]
			if c >= "0" and c <= "9":
				num_str += c
			elif num_str.length() > 0:
				break
		if num_str.is_valid_int():
			var frame_num: int = int(num_str)
			if frame_num >= use_start and frame_num <= use_end:
				if (frame_num - use_start) % step == 0:
					list.append(ART_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	# 按帧号排序
	list.sort_custom(func(a: String, b: String) -> bool:
		return _frame_num_from_path(a) < _frame_num_from_path(b)
	)
	var out := PackedStringArray()
	for s in list:
		out.append(s)
	return out

func _frame_num_from_path(path: String) -> int:
	var file_name: String = path.get_file()
	var rest: String = file_name.trim_prefix(FILE_PREFIX)
	var num_str: String = ""
	for i in rest.length():
		var c: String = rest[i]
		if c >= "0" and c <= "9":
			num_str += c
		elif num_str.length() > 0:
			break
	return int(num_str) if num_str.is_valid_int() else 0
