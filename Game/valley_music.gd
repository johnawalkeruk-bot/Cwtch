extends Node
## One shared soundtrack for garden and village; follows the simulation clock.
const PATH := "res://audio/music/"
const WELCOME := PATH+"morning_in_the_vale.mp3"
const TRACKS := {
 "morning":["morning_in_the_vale","beautiful_day"],
 "afternoon":["afternoon_stroll","afternoon_in_the_garden","beautiful_day"],
 "evening":["twilight_pastoral"],
 "night":["twilight_pastoral"]
}
var host: Node
var channels: Array[AudioStreamPlayer]=[]
var active := 0
var band := ""
var current_track := ""
var bags: Dictionary={}
var fade: Tween
var next_track := false
var rng:=RandomNumberGenerator.new()
var suspended := true
var pause_player: AudioStreamPlayer
var mix := 0.0
var gains := [0.0,0.0]

func setup(menu: Node) -> void:
 host=menu
 rng.randomize()
 pause_player=AudioStreamPlayer.new()
 pause_player.bus="Music"
 pause_player.stream=load(PATH+"pause_and_look.mp3")
 pause_player.volume_db=-17
 add_child(pause_player)
 pause_player.finished.connect(func():
  if is_paused():pause_player.play())
 for index in 2:
  var player:=AudioStreamPlayer.new()
  player.bus="Music"
  player.volume_db=-80
  add_child(player)
  channels.append(player)
  player.finished.connect(func():
   if index==active:next_track=true)

static func period(hours: float) -> String:
 if hours>=6 and hours<12:return "morning"
 if hours>=12 and hours<18:return "afternoon"
 if hours>=18 and hours<21:return "evening"
 return "night"

func choose(group: String) -> String:
 var pool: Array=TRACKS[group]
 if not bags.has(group) or bags[group].is_empty():
  var bag: Array=pool.duplicate()
  # Fisher-Yates makes every eligible track play once before refilling.
  for i in range(bag.size()-1,0,-1):
   var j:=rng.randi_range(0,i)
   var temp=bag[i];bag[i]=bag[j];bag[j]=temp
  if bag.size()>1 and bag.back()==current_track:
   var temp=bag[0];bag[0]=bag[-1];bag[-1]=temp
  bags[group]=bag
 return str(bags[group].pop_back())

func _process(delta: float) -> void:
 if not is_instance_valid(host):return
 var pause_now:=is_paused()
 if pause_now and not pause_player.playing:pause_player.play()
 elif not pause_now and pause_player.playing:pause_player.stop()
 if is_instance_valid(host.garden):pause_player.volume_db=-80 if host.garden.ambience_muted else -17
 var enabled: bool=not pause_now and is_instance_valid(host.garden) and not host.menu_active and not host.loading
 if not enabled:
  if not suspended:
   for channel in channels:channel.stream_paused=true
   suspended=true
  return
 var garden: Node=host.garden
 if not garden.loading_complete:return
 if suspended:
  for channel in channels:channel.stream_paused=false
  suspended=false
 var hours:=fposmod(6.0+float(garden.valley_cycle.elapsed)*24.0/float(garden.valley_cycle.FULL_CYCLE),24.0)
 var desired := "arrival" if garden.northern_arrival.active else period(hours)
 if desired!=band:
  band=desired
  if band=="arrival":
   if ResourceLoader.exists(WELCOME):play_track("morning_in_the_vale")
   else:silence()
  else:play_track(choose(band))
 elif next_track:
  next_track=false
  if band!="arrival":play_track(choose(band))
 var target := 0.0 if garden.hedgehog_intro.active else 1.0
 if garden.ambience_muted:target=0
 mix=move_toward(mix,target,delta*1.7)
 var db := -27.0 if band=="night" else (-19.0 if band=="arrival" else -24.0)
 for i in 2:
  channels[i].volume_db=db+linear_to_db(maxf(float(gains[i])*mix,0.0001))

func play_track(track: String) -> void:
 var incoming:=1-active
 var outgoing:=active
 if fade and fade.is_running():fade.kill()
 channels[incoming].stop()
 channels[incoming].stream=load(PATH+track+".mp3")
 channels[incoming].stream_paused=false
 channels[incoming].play()
 gains[incoming]=0.0
 active=incoming
 current_track=track
 next_track=false
 fade=create_tween().set_parallel(true)
 fade.tween_method(func(value: float):gains[incoming]=value,0.0,1.0,2.0)
 fade.tween_method(func(value: float):gains[outgoing]=value,float(gains[outgoing]),0.0,1.2)
 fade.chain().tween_callback(channels[outgoing].stop)

func silence() -> void:
 if fade and fade.is_running():fade.kill()
 for channel in channels:channel.stop()
 gains=[0.0,0.0]
 current_track=""
 next_track=false

func _exit_tree() -> void:
 if fade:fade.kill()
 fade=null
 for channel in channels:
  if is_instance_valid(channel):channel.stop()

func is_paused() -> bool:
 if not is_instance_valid(host) or host.loading or host.menu_active or not is_instance_valid(host.garden):return false
 if not host.garden.loading_complete:return false
 if is_instance_valid(host.get("village")):return bool(host.village.paused)
 var guide=host.garden.get("guide")
 var intro=host.garden.get("hedgehog_intro")
 return (is_instance_valid(guide) and guide.visible) or (intro is Node and intro.get("paused")==true)
