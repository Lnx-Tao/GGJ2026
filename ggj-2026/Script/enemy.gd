extends StaticBody2D
class_name Enemy

## 敌人血量
@export var max_health: float = 100.0

var health: float

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

## 受到伤害；由角色攻击时调用
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()

func die() -> void:
	queue_free()
