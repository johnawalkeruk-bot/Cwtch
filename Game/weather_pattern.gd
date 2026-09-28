extends RefCounted
## Weighted fronts: variable lengths, occasional persistence, no fixed itinerary.
const LENGTHS := [Vector2(210,480),Vector2(90,300),Vector2(60,180),Vector2(70,240),Vector2(40,120),Vector2(35,90),Vector2(90,240)]
const WEIGHTS := [
	[25,60,15,0,0,0,0],
	[20,15,35,20,0,0,10],
	[0,20,15,35,5,0,25],
	[0,10,25,15,25,5,20],
	[0,0,15,40,10,20,15],
	[0,0,5,45,30,0,20],
	[50,25,15,0,0,0,10]
]
var rng := RandomNumberGenerator.new()
var scheduled_index := 0
var duration := 300.0

func _init() -> void:
	rng.randomize()
	_schedule(0)

func _schedule(index: int) -> void:
	scheduled_index=clampi(index,0,6)
	var limits: Vector2=LENGTHS[scheduled_index]
	duration=rng.randf_range(limits.x,limits.y)

func advance(index: int, age: float, delta: float) -> Array:
	index=clampi(index,0,6)
	if index!=scheduled_index:_schedule(index)
	age=maxf(0,age)+maxf(0,delta)
	while age>=duration:
		age-=duration
		var pick := rng.randf()*100.0
		var weights: Array=WEIGHTS[index]
		for candidate in weights.size():
			pick-=float(weights[candidate])
			if pick<0:
				index=candidate
				break
		_schedule(index)
	return [index,age]

func save_data() -> Dictionary:
	# String avoids JSON floating-point rounding of the 64-bit random state.
	return {"index":scheduled_index,"duration":duration,"rng":str(rng.state)}

func restore(data: Dictionary, index: int, age: float) -> float:
	_schedule(index)
	if int(data.get("index",-1))==index:
		var restored := float(data.get("duration",duration))
		if is_finite(restored):duration=clampf(restored,LENGTHS[index].x,LENGTHS[index].y)
		var state_text := str(data.get("rng",""))
		if state_text.is_valid_int():rng.state=state_text.to_int()
	return clampf(age,0,duration-0.001) if is_finite(age) else 0.0
