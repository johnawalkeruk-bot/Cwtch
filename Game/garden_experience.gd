extends RefCounted
## Shared garden progression. Repeating one action on one tile cannot farm XP.
var total := 0
var award_day := 1
var worked: Dictionary = {}

func level() -> int:
	return 1+total/100

func progress() -> float:
	return float(total%100)/100.0

func gardening(cell: Vector2i, action: String, day: int, points: int) -> void:
	if day!=award_day:
		award_day=day
		worked.clear()
	var key := "%d,%d:%s"%[cell.x,cell.y,action]
	if worked.has(key):return
	worked[key]=true
	total+=points

func wildlife(kind: String, _species: String, _day: int) -> void:
	total+=int({"visit":25,"resident":50,"birth":30}.get(kind,0))

func save_data() -> Dictionary:
	return {"total":total,"day":award_day,"worked":worked.duplicate()}

func restore(data: Dictionary) -> void:
	total=maxi(0,int(data.get("total",0)))
	award_day=maxi(1,int(data.get("day",1)))
	worked=data.get("worked",{}).duplicate() if data.get("worked",{}) is Dictionary else {}
