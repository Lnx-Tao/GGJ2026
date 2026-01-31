extends Control

## 帷幕控制器
## 负责控制帷幕的撤掉动画

## 帷幕节点引用
@onready var curtain_left_top: TextureRect = $CurtainLeftTop
@onready var curtain_top: TextureRect = $CurtainTop
@onready var curtain_right_top: TextureRect = $CurtainRightTop
@onready var curtain_left: TextureRect = $CurtainLeft
@onready var curtain_right: TextureRect = $CurtainRight

## 动画状态
var is_curtain_open: bool = false
var curtain_animation_duration: float = 6.0  # 动画时长（秒）

## 原始位置（用于存储初始位置）
var original_positions: Dictionary = {}

## 初始化
func _ready() -> void:
	# 保存原始位置
	_save_original_positions()

## 保存原始位置
func _save_original_positions() -> void:
	if curtain_left_top != null:
		# 保存offset值（Control节点使用offset）
		original_positions["left_top"] = {
			"offset_left": curtain_left_top.offset_left,
			"offset_top": curtain_left_top.offset_top,
			"offset_right": curtain_left_top.offset_right,
			"offset_bottom": curtain_left_top.offset_bottom
		}
	if curtain_top != null:
		original_positions["top"] = {
			"offset_left": curtain_top.offset_left,
			"offset_top": curtain_top.offset_top,
			"offset_right": curtain_top.offset_right,
			"offset_bottom": curtain_top.offset_bottom
		}
	if curtain_right_top != null:
		original_positions["right_top"] = {
			"offset_left": curtain_right_top.offset_left,
			"offset_top": curtain_right_top.offset_top,
			"offset_right": curtain_right_top.offset_right,
			"offset_bottom": curtain_right_top.offset_bottom
		}
	if curtain_left != null:
		original_positions["left"] = {
			"offset_left": curtain_left.offset_left,
			"offset_top": curtain_left.offset_top,
			"offset_right": curtain_left.offset_right,
			"offset_bottom": curtain_left.offset_bottom
		}
	if curtain_right != null:
		original_positions["right"] = {
			"offset_left": curtain_right.offset_left,
			"offset_top": curtain_right.offset_top,
			"offset_right": curtain_right.offset_right,
			"offset_bottom": curtain_right.offset_bottom
		}

## 撤掉帷幕（向上和向两边）
func open_curtains() -> void:
	if is_curtain_open:
		return
	
	is_curtain_open = true
	
	# 创建Tween用于平滑动画
	var tween = create_tween()
	tween.set_parallel(true)  # 并行执行所有动画
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)  # 使用三次缓动，更自然
	
	# 顶部三个帷幕向上移动（移出屏幕）
	if curtain_left_top != null:
		var start_top = curtain_left_top.offset_top
		var target_top = -1000.0  # 向上移出屏幕（足够远）
		tween.tween_property(curtain_left_top, "offset_top", target_top, curtain_animation_duration)
		tween.tween_property(curtain_left_top, "offset_bottom", target_top + (curtain_left_top.offset_bottom - start_top), curtain_animation_duration)
	
	if curtain_top != null:
		var start_top = curtain_top.offset_top
		var target_top = -1000.0
		tween.tween_property(curtain_top, "offset_top", target_top, curtain_animation_duration)
		tween.tween_property(curtain_top, "offset_bottom", target_top + (curtain_top.offset_bottom - start_top), curtain_animation_duration)
	
	if curtain_right_top != null:
		var start_top = curtain_right_top.offset_top
		var target_top = -1000.0
		tween.tween_property(curtain_right_top, "offset_top", target_top, curtain_animation_duration)
		tween.tween_property(curtain_right_top, "offset_bottom", target_top + (curtain_right_top.offset_bottom - start_top), curtain_animation_duration)
	
	# 左右垂直帷幕向两边移动（移出屏幕）
	if curtain_left != null:
		var start_left = curtain_left.offset_left
		var start_right = curtain_left.offset_right
		var width = start_right - start_left
		var target_left = -2000.0  # 向左移出屏幕（足够远）
		tween.tween_property(curtain_left, "offset_left", target_left, curtain_animation_duration)
		tween.tween_property(curtain_left, "offset_right", target_left + width, curtain_animation_duration)
	
	if curtain_right != null:
		var start_left = curtain_right.offset_left
		var start_right = curtain_right.offset_right
		var width = start_right - start_left
		var viewport_size = get_viewport_rect().size
		var target_right = viewport_size.x + 2000.0  # 向右移出屏幕（足够远）
		tween.tween_property(curtain_right, "offset_right", target_right, curtain_animation_duration)
		tween.tween_property(curtain_right, "offset_left", target_right - width, curtain_animation_duration)

## 恢复帷幕（可选，如果需要的话）
func close_curtains() -> void:
	if not is_curtain_open:
		return
	
	is_curtain_open = false
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# 恢复到原始位置
	if curtain_left_top != null and original_positions.has("left_top"):
		var pos = original_positions["left_top"]
		tween.tween_property(curtain_left_top, "offset_left", pos.offset_left, curtain_animation_duration)
		tween.tween_property(curtain_left_top, "offset_top", pos.offset_top, curtain_animation_duration)
		tween.tween_property(curtain_left_top, "offset_right", pos.offset_right, curtain_animation_duration)
		tween.tween_property(curtain_left_top, "offset_bottom", pos.offset_bottom, curtain_animation_duration)
	
	if curtain_top != null and original_positions.has("top"):
		var pos = original_positions["top"]
		tween.tween_property(curtain_top, "offset_left", pos.offset_left, curtain_animation_duration)
		tween.tween_property(curtain_top, "offset_top", pos.offset_top, curtain_animation_duration)
		tween.tween_property(curtain_top, "offset_right", pos.offset_right, curtain_animation_duration)
		tween.tween_property(curtain_top, "offset_bottom", pos.offset_bottom, curtain_animation_duration)
	
	if curtain_right_top != null and original_positions.has("right_top"):
		var pos = original_positions["right_top"]
		tween.tween_property(curtain_right_top, "offset_left", pos.offset_left, curtain_animation_duration)
		tween.tween_property(curtain_right_top, "offset_top", pos.offset_top, curtain_animation_duration)
		tween.tween_property(curtain_right_top, "offset_right", pos.offset_right, curtain_animation_duration)
		tween.tween_property(curtain_right_top, "offset_bottom", pos.offset_bottom, curtain_animation_duration)
	
	if curtain_left != null and original_positions.has("left"):
		var pos = original_positions["left"]
		tween.tween_property(curtain_left, "offset_left", pos.offset_left, curtain_animation_duration)
		tween.tween_property(curtain_left, "offset_top", pos.offset_top, curtain_animation_duration)
		tween.tween_property(curtain_left, "offset_right", pos.offset_right, curtain_animation_duration)
		tween.tween_property(curtain_left, "offset_bottom", pos.offset_bottom, curtain_animation_duration)
	
	if curtain_right != null and original_positions.has("right"):
		var pos = original_positions["right"]
		tween.tween_property(curtain_right, "offset_left", pos.offset_left, curtain_animation_duration)
		tween.tween_property(curtain_right, "offset_top", pos.offset_top, curtain_animation_duration)
		tween.tween_property(curtain_right, "offset_right", pos.offset_right, curtain_animation_duration)
		tween.tween_property(curtain_right, "offset_bottom", pos.offset_bottom, curtain_animation_duration)

