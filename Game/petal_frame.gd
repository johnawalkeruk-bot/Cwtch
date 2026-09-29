extends Control
const Petals=preload("res://petal_shapes.gd")
func _ready() -> void:
	top_level=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	global_position=get_parent().global_position
	size=get_parent().size

func _draw() -> void:
	for axis in 2:
		var length: float=size.x if axis==0 else size.y
		var count:=maxi(2,int(length/28))
		for side in 2:
			for i in count:
				var distance:=lerpf(18,length-18,float(i)/maxi(1,count-1))
				var at:=Vector2(distance,0 if side==0 else size.y) if axis==0 else Vector2(0 if side==0 else size.x,distance)
				var angle:=(-PI/2 if side==0 else PI/2) if axis==0 else (PI if side==0 else 0.0)
				Petals.petal(self,at,angle+(-0.12 if i%2==0 else 0.12),15,19,Petals.GOLD if i%2==0 else Color("dcb54e"))
