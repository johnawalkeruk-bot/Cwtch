extends RefCounted
## Reject malformed network data before the existing local restore routines see it.
static func valid(data: Variant) -> bool:
 if not data is Dictionary or data.get("version") != 1:return false
 if not data.get("terrain") is Array or data.terrain.size()!=1296:return false
 for tile in data.terrain:
  if not number(tile) or tile!=int(tile) or tile<0 or tile>7:return false
 if not pair(data.get("player")):return false
 var schema := {
  "version":0,"terrain":[0],"player":[0],"player_position":[0],
  "coins":0,"elapsed":0,"harvested":0,"weather":0,"weather_elapsed":0,"wetness":0,
  "crops":[{"x":0,"z":0,"age":0,"watered":false}],"watered":[[0]],
  "purchases":[{"id":"","x":0,"z":0,"yaw":0}],
  "experience":{"total":0,"day":0,"worked":{}},
  "weather_pattern":{"index":0,"duration":0,"rng":""},
  "local_coop":{"position":[0],"tool":0,"mode":0,"yaw":0,"pitch":0},
  "deformation":{"profile_version":0,"samples":[0],"heights":[[0]],"seed_holes":[[0]]},
  "wildlife":{"records":{},"life_events":[{"kind":"","species":"","individual_id":"","day":0}],"wild_hedgehog_enabled":false,"patrol_corner":0,"robin_patrol_corner":0,"hedgehog_position":[0],"robin_position":[0]},
  "hedgehog_intro":{},"summary":{}
 }
 if not shape(data,schema):return false
 for crop in data.get("crops",[]):
  if not crop.has_all(["x","z","age","watered"]):return false
 for wet in data.get("watered",[]):
  if wet.size()!=3:return false
 for record in data.get("purchases",[]):
  if not record.has_all(["id","x","z"]):return false
 var wildlife: Dictionary=data.get("wildlife",{})
 for entry in wildlife.get("records",{}).values():
  if not entry is Dictionary or not number(entry.get("visit_day",0)) or not number(entry.get("resident_day",0)):return false
 for point in [data.get("player_position",[0,0]),data.get("local_coop",{}).get("position",[0,0]),wildlife.get("hedgehog_position",[0,0]),wildlife.get("robin_position",[0,0])]:
  if not pair(point):return false
 return true

static func number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<1e12

static func pair(value: Variant) -> bool:
 return value is Array and value.size()==2 and number(value[0]) and number(value[1])

static func shape(value: Variant, model: Variant, depth: int=0) -> bool:
 if depth>12:return false
 if model is Dictionary:
  if not value is Dictionary:return false
  for key in model:
   if value.has(key) and not shape(value[key],model[key],depth+1):return false
  return true
 if model is Array:
  if not value is Array or value.size()>50000:return false
  for item in value:
   if not shape(item,model[0],depth+1):return false
  return true
 if model is String:return value is String and value.length()<1024
 if model is bool:return value is bool
 return number(value)
