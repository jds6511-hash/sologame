extends Node2D
## 복구 투자 5단계는 관리인 주변의 길·건물·울타리·광장·기념물로 표시한다.
var level := 0


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	if level >= 1:
		draw_rect(Rect2(300, 500, 100, 12), Color("a89070"))
		for x in range(304, 400, 12):
			draw_line(Vector2(x, 500), Vector2(x, 512), Color("c2b49c"))
	if level >= 2:
		draw_rect(Rect2(312, 462, 20, 14), Color("786447"))
		draw_colored_polygon(
			PackedVector2Array([Vector2(308, 462), Vector2(322, 448), Vector2(336, 462)]),
			Color("677a4a")
		)
	if level >= 3:
		for x in range(300, 406, 14):
			draw_rect(Rect2(x, 516, 3, 8), Color("9b7554"))
		draw_line(Vector2(300, 520), Vector2(404, 520), Color("b99166"), 2)
	if level >= 4:
		draw_circle(Vector2(408, 490), 15, Color("69747e"))
		draw_circle(Vector2(408, 490), 11, Color("989a92"))
	if level >= 5:
		draw_rect(Rect2(403, 469, 10, 17), Color("b5b8aa"))
		draw_circle(Vector2(408, 465), 6, Color("dac896"))
