extends Node2D

## 人物在画面中的 X 位置（距左像素，400 = 中间偏左）
const CHARACTER_SCREEN_X := 400

@onready var camera: Camera2D = $Camera2D
@onready var character: CharacterBody2D = $Character

## 舞者面具实例（可选，如果需要管理生命周期）
var dancer_mask: Node = null
var dancer_mask_active: bool = false  # 防止重复触发

func _process(_delta: float) -> void:
	if not is_instance_valid(character):
		return
	# 相机跟随：使人物始终在画面 x=CHARACTER_SCREEN_X 处（视口中心 800，故相机 = 人物 - 400）
	camera.global_position = character.global_position + Vector2(800 - CHARACTER_SCREEN_X, 0.0)

func _input(event: InputEvent) -> void:
	# 测试：按D键触发舞者面具界面（只触发一次）
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_D and key_event.pressed and not dancer_mask_active:
			dancer_mask_active = true
			use_dancer_mask()

## 使用舞者面具的示例函数
## 你的同学可以这样调用：get_node("/root/GameWorld").use_dancer_mask()
func use_dancer_mask(beat_count: int = 4) -> void:
	# 方法1：使用静态快速启动（推荐）
	var DancerMask = load("res://Script/dancer_mask.gd")
	DancerMask.quick_start(beat_count, _on_dancer_mask_completed)
	
	# 方法2：创建实例并管理（如果需要更多控制）
	# dancer_mask = load("res://Script/dancer_mask.gd").new()
	# get_tree().root.add_child(dancer_mask)
	# dancer_mask.rhythm_completed.connect(_on_dancer_mask_completed)
	# dancer_mask.start_rhythm_game(beat_count, 200.0, 30.0)

## 舞者面具完成回调
func _on_dancer_mask_completed(result: Dictionary) -> void:
	print("舞者面具节奏游戏完成！")
	print("成功: ", result.get("success", false))
	print("击中: ", result.get("hit_count", 0), "/", result.get("total_beats", 0))
	print("得分: ", result.get("score", 0.0), "%")
	
	# 重置标志，允许再次触发
	dancer_mask_active = false
	
	# 在这里添加你的后续逻辑
	if result.get("success", false):
		# 例如：激活舞者面具的特殊能力
		print("舞者面具能力激活成功！")
		# activate_dancer_mask_ability()
	else:
		print("舞者面具能力激活失败！")
