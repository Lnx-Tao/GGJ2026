extends CharacterBody2D

## 移动速度（像素/秒）
@export var move_speed: float = 300.0
## 攻击伤害
@export var attack_damage: float = 25.0
## 攻击冷却时间（秒）
@export var attack_cooldown: float = 0.5

@onready var attack_range: Area2D = $AttackRange
var attack_timer: float = 0.0

func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 0.0
	if Input.is_action_pressed("ui_select"):  # 空格键
		velocity.x = move_speed

	move_and_slide()

	# 攻击冷却
	if attack_timer > 0.0:
		attack_timer -= delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			try_attack()

func try_attack() -> void:
	if attack_timer > 0.0:
		return
	attack_timer = attack_cooldown
	for body in attack_range.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
