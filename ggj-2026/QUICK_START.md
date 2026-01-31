# 舞者面具功能 - 快速开始指南

## 🎯 功能说明
舞者面具是一个节奏判定小游戏，玩家需要在指针移动到节奏点（紫色圆圈）内时点击鼠标来触发判定。

## 📁 文件清单
- `Script/dancer_mask.gd` - 主控制器（调用接口）
- `Script/dancer_mask_ui.gd` - UI控制器
- `UI/dancer_mask_ui.tscn` - UI场景
- `Script/dancer_mask_example.gd` - 使用示例
- `Script/DANCER_MASK_README.md` - 详细文档

## 🚀 最简单的调用方式

在你的脚本中（比如 `character.gd` 或其他主逻辑脚本）：

```gdscript
# 方法1：最简单（推荐）
func activate_dancer_mask() -> void:
    var DancerMask = load("res://Script/dancer_mask.gd")
    DancerMask.quick_start(4, func(result): 
        if result.get("success"):
            print("成功！可以执行后续逻辑")
            # 在这里添加你的成功处理代码
        else:
            print("失败")
    )
```

## 📝 完整示例

```gdscript
extends CharacterBody2D

func use_dancer_mask_ability() -> void:
    # 加载舞者面具脚本
    var DancerMask = load("res://Script/dancer_mask.gd")
    
    # 启动节奏游戏
    # 参数：节奏点数量(4), 指针速度(200), 判定容差(30)
    DancerMask.quick_start(4, _on_rhythm_completed)

func _on_rhythm_completed(result: Dictionary) -> void:
    var success = result.get("success", false)
    var score = result.get("score", 0.0)
    
    if success:
        print("舞者面具激活成功！得分: ", score, "%")
        # 执行成功后的能力效果
    else:
        print("舞者面具激活失败")
```

## 🎮 测试方法

1. 在 `GameWorld.gd` 中已经添加了示例函数 `use_dancer_mask()`
2. 你可以在任何地方调用它来测试：
   ```gdscript
   get_node("/root/GameWorld").use_dancer_mask()
   ```
3. 或者按某个键触发（在 `_input` 或 `_process` 中）：
   ```gdscript
   if Input.is_action_just_pressed("ui_accept"):  # 空格键
       use_dancer_mask()
   ```

## ⚙️ 自定义参数

```gdscript
# 创建实例以自定义参数
var dancer_mask = load("res://Script/dancer_mask.gd").new()
get_tree().root.add_child(dancer_mask)
dancer_mask.rhythm_completed.connect(_on_completed)
dancer_mask.start_rhythm_game(
    6,      # 节奏点数量
    150.0,  # 指针速度（更慢）
    40.0    # 判定容差（更宽松）
)
```

## 📊 返回值说明

回调函数会收到一个字典，包含：
- `success` (bool): 是否成功完成所有节奏点
- `hit_count` (int): 击中的节奏点数量
- `total_beats` (int): 总节奏点数量  
- `score` (float): 得分百分比 (0-100)

## 💡 提示

- 指针从左侧开始向右移动
- 当指针进入紫色圆圈范围内时，点击鼠标左键或右键
- 成功击中的圆圈会变成绿色
- 需要击中所有节奏点才能成功

## ❓ 常见问题

**Q: 如何判断游戏是否正在进行？**
A: 使用 `dancer_mask.is_active()` 方法

**Q: 如何提前停止游戏？**
A: 使用 `dancer_mask.stop_rhythm_game()` 方法

**Q: 可以同时运行多个实例吗？**
A: 不可以，系统会自动清理之前的实例

## 📚 更多信息

查看 `Script/DANCER_MASK_README.md` 获取完整文档。

