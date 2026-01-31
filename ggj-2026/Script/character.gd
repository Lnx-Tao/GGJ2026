extends CharacterBody2D

## 移动速度（像素/秒）
@export var move_speed: float = 300.0
## 为 true 时无法移动（如戴上守卫面具时由 game_world 设置）
var movement_locked: bool = false

@onready var assassination_range: Area2D = $AttackRange
## 刺杀检测距离（若 Area2D 未检测到则用此距离找最近敌人）
const ASSASSINATION_DISTANCE: float = 120.0

func _physics_process(_delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 0.0
	if not movement_locked and Input.is_action_pressed("ui_select"):  # 空格键
		velocity.x = move_speed
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			try_assassinate()

func try_assassinate() -> void:
	var gw = get_tree().current_scene
	if gw == null or not gw.has_method("can_gain_mask_from_assassination") or not gw.has_method("add_mask_from_assassination"):
		return
	var bodies := assassination_range.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if not body.is_in_group("enemy"):
			continue
		if not body.has_method("take_assassination"):
			continue
		var mask_type_str: String = body.mask_type if "mask_type" in body else ""
		if mask_type_str.is_empty():
			continue
		if not gw.can_gain_mask_from_assassination(mask_type_str):
			continue
		var mt: String = body.take_assassination()
		gw.add_mask_from_assassination(mt)
		return
	# 若范围内没有重叠：用距离再找一次（防止碰撞未刷新）
	var char_pos := global_position
	var nearest: Node2D = null
	var nearest_d: float = ASSASSINATION_DISTANCE
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var n: Node2D = node as Node2D
		if not n.has_method("take_assassination"):
			continue
		var d: float = char_pos.distance_to(n.global_position)
		if d < nearest_d:
			var mt_str: String = n.mask_type if "mask_type" in n else ""
			if mt_str.is_empty():
				continue
			if not gw.can_gain_mask_from_assassination(mt_str):
				continue
			nearest_d = d
			nearest = n
	if nearest != null:
		var mt: String = nearest.take_assassination()
		gw.add_mask_from_assassination(mt)