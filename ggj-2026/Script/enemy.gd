extends StaticBody2D
class_name Enemy

## 敌人血量
@export var max_health: float = 100.0
## 刺杀该敌人后获得的面具类型（子类或场景中设置，如 "guard" "butler" "dancer" "princess"）
@export var mask_type: String = ""

var health: float

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

## 受到伤害；由角色攻击时调用
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()

## 受到刺杀时调用；返回面具类型并移除敌人（后续可在此播倒地动画）
func take_assassination() -> String:
	var mt := mask_type
	die()
	return mt

func die() -> void:
	queue_free()
