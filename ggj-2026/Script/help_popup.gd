extends Control

## 帮助弹窗控制器
## 显示帮助说明图片（help_img_1 到 help_img_7）

signal popup_closed

## 当前显示的图片索引（1-7）
var current_index: int = 1
## 总图片数量
const TOTAL_IMAGES: int = 7

@onready var overlay: ColorRect = $Overlay
@onready var help_image: TextureRect = $HelpImage
@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var close_button: Button = $CloseButton
@onready var page_label: Label = $PageLabel

## 预加载所有帮助图片
var help_images: Array[Texture2D] = []

func _ready() -> void:
	# 加载所有帮助图片
	for i in range(1, TOTAL_IMAGES + 1):
		var img_path := "res://Art/help_img_%d.png" % i
		var texture := load(img_path) as Texture2D
		if texture:
			help_images.append(texture)
		else:
			push_error("无法加载帮助图片: " + img_path)
	
	# 连接按钮信号
	prev_button.pressed.connect(_on_prev_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# 显示第一张图片
	_update_display()

## 显示上一张图片
func _on_prev_button_pressed() -> void:
	if current_index > 1:
		current_index -= 1
		_update_display()

## 显示下一张图片
func _on_next_button_pressed() -> void:
	if current_index < TOTAL_IMAGES:
		current_index += 1
		_update_display()

## 关闭弹窗
func _on_close_button_pressed() -> void:
	popup_closed.emit()
	queue_free()

## 更新显示的图片和页码
func _update_display() -> void:
	if current_index >= 1 and current_index <= help_images.size():
		help_image.texture = help_images[current_index - 1]
		page_label.text = "%d / %d" % [current_index, TOTAL_IMAGES]
		
		# 根据当前页码显示/隐藏按钮
		prev_button.visible = (current_index > 1)  # 第1张时隐藏"上一张"
		next_button.visible = (current_index < TOTAL_IMAGES)  # 第7张时隐藏"下一张"

## 支持键盘快捷键
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				_on_close_button_pressed()
			elif (key_event.keycode == KEY_LEFT or key_event.keycode == KEY_A) and current_index > 1:
				_on_prev_button_pressed()
			elif (key_event.keycode == KEY_RIGHT or key_event.keycode == KEY_D) and current_index < TOTAL_IMAGES:
				_on_next_button_pressed()
