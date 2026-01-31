extends Node

## 舞者面具 - 节奏判定系统
## 
## 使用方法：
## 1. 调用 start_rhythm_game(beat_count, callback) 开始节奏游戏
## 2. 系统会自动显示UI并处理输入
## 3. 完成后通过回调函数返回结果
##
## 示例：
##   DancerMask.start_rhythm_game(4, func(result): print("结果: ", result))

signal rhythm_completed(result: Dictionary)

## 节奏判定UI场景路径
const UI_SCENE_PATH = "res://UI/dancer_mask_ui.tscn"

## 当前UI实例
var ui_instance: Control = null
## CanvasLayer实例（用于屏幕空间显示）
var canvas_layer: CanvasLayer = null

## 开始节奏游戏
## beat_count: 需要击中的节奏点数量（默认4个）
## speed: 指针移动速度（像素/秒，默认200）
## tolerance: 判定容差范围（像素，默认30）
func start_rhythm_game(beat_count: int = 4, speed: float = 200.0, tolerance: float = 30.0) -> void:
	# 如果已有UI在运行，先清理
	if canvas_layer != null:
		canvas_layer.queue_free()
		canvas_layer = null
		ui_instance = null
	
	# 加载UI场景
	var ui_scene = load(UI_SCENE_PATH)
	if ui_scene == null:
		push_error("无法加载舞者面具UI场景: " + UI_SCENE_PATH)
		return
	
	# 暂停游戏
	get_tree().paused = true
	
	# 创建CanvasLayer（屏幕空间，不受相机影响）
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DancerMaskCanvasLayer"
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas_layer)
	
	# 创建UI实例
	ui_instance = ui_scene.instantiate()
	# 设置UI在暂停时也能处理输入
	ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.add_child(ui_instance)
	
	# 连接完成信号
	if ui_instance.has_signal("rhythm_completed"):
		ui_instance.rhythm_completed.connect(_on_rhythm_completed)
	
	# 初始化UI
	if ui_instance.has_method("start_game"):
		ui_instance.start_game(beat_count, speed, tolerance)

## 停止节奏游戏（如果正在运行）
func stop_rhythm_game() -> void:
	# 恢复游戏
	get_tree().paused = false
	
	# 清理CanvasLayer（会自动清理其子节点）
	if canvas_layer != null:
		canvas_layer.queue_free()
		canvas_layer = null
		ui_instance = null

## 检查是否正在运行
func is_active() -> bool:
	return canvas_layer != null and is_instance_valid(canvas_layer) and ui_instance != null and is_instance_valid(ui_instance)

## 内部回调：节奏游戏完成
func _on_rhythm_completed(result: Dictionary) -> void:
	rhythm_completed.emit(result)
	stop_rhythm_game()

## 静态方法：快速启动（最简单的方式）
## 在其他脚本中可以直接调用：DancerMask.quick_start(callback)
static func quick_start(beat_count: int = 4, callback: Callable = Callable()) -> void:
	var script = load("res://Script/dancer_mask.gd")
	var instance = script.new()
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		tree.root.add_child(instance)
		if callback.is_valid():
			instance.rhythm_completed.connect(callback)
		instance.start_rhythm_game(beat_count)

