## 舞者面具使用示例
## 
## 这个文件展示了如何在其他脚本中调用舞者面具功能
## 你可以参考这个示例来集成到你的主逻辑中

extends Node

## 方法1: 使用单例方式（推荐）
func use_dancer_mask_method1() -> void:
	# 获取舞者面具实例
	var dancer_mask = load("res://Script/dancer_mask.gd").new()
	add_child(dancer_mask)
	
	# 连接完成信号
	dancer_mask.rhythm_completed.connect(_on_rhythm_completed)
	
	# 开始节奏游戏
	# 参数：节奏点数量(4), 指针速度(200), 判定容差(30)
	dancer_mask.start_rhythm_game(4, 200.0, 30.0)

## 方法2: 直接在GameWorld中使用
func use_dancer_mask_method2() -> void:
	# 在GameWorld脚本中，你可以这样调用：
	var dancer_mask = preload("res://Script/dancer_mask.gd").new()
	get_tree().root.add_child(dancer_mask)
	
	# 开始游戏，并设置回调
	dancer_mask.start_rhythm_game(4, 200.0, 30.0)
	dancer_mask.rhythm_completed.connect(_on_rhythm_completed)

## 方法3: 作为节点添加到场景中
## 在GameWorld.tscn中添加一个DancerMask节点，然后：
func use_dancer_mask_method3() -> void:
	var dancer_mask = get_node("DancerMask")
	if dancer_mask != null:
		dancer_mask.start_rhythm_game(4, 200.0, 30.0)
		dancer_mask.rhythm_completed.connect(_on_rhythm_completed)

## 节奏游戏完成回调
func _on_rhythm_completed(result: Dictionary) -> void:
	print("节奏游戏完成！")
	print("成功: ", result.get("success", false))
	print("击中数: ", result.get("hit_count", 0), "/", result.get("total_beats", 0))
	print("得分: ", result.get("score", 0.0), "%")
	
	# 根据结果执行后续逻辑
	if result.get("success", false):
		# 成功时的处理
		print("舞者面具能力激活成功！")
	else:
		# 失败时的处理
		print("舞者面具能力激活失败！")
