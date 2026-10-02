extends SceneTree
class Host extends Node:
 var garden: Node
 var menu_active:=false
 var loading:=false
 var village: Node
class Village extends Node:
 var paused:=true
class FakeGarden extends Node:
 var loading_complete:=true
 var ambience_muted:=false
 var guide:=Control.new()
 var valley_cycle={"elapsed":300.0,"FULL_CYCLE":2400.0}
 var northern_arrival={"active":false}
 var hedgehog_intro={"active":false}
func _initialize():run.call_deferred()
func run():
 var script=load('res://valley_music.gd')
 var host=Host.new();root.add_child(host)
 host.garden=FakeGarden.new();host.add_child(host.garden)
 host.garden.add_child(host.garden.guide);host.garden.guide.hide()
 var music=script.new();host.add_child(music);music.setup(host)
 assert(script.period(6)=='morning' and script.period(12)=='afternoon' and script.period(18)=='evening' and script.period(21)=='night')
 var seen={}
 for i in 3:
  var track=music.choose('afternoon');seen[track]=true;music.current_track=track
 assert(seen.size()==3,'Every afternoon track before refill')
 var last=music.current_track
 assert(music.choose('afternoon')!=last,'No immediate shuffle-repeat at refill')
 music._process(1)
 assert(music.band=='morning' and music.channels[music.active].playing)
 host.garden.northern_arrival.active=true;music._process(1)
 assert(music.current_track=='morning_in_the_vale','Arrival plays correct song')
 host.garden.northern_arrival.active=false;host.garden.valley_cycle.elapsed=900.0;music._process(1)
 assert(music.band=='afternoon')
 host.garden.hedgehog_intro.active=true;music._process(1)
 assert(music.mix==0,'Dialogue ducks music')
 host.menu_active=true;music._process(1)
 assert(music.suspended and music.channels[music.active].stream_paused)
 host.menu_active=false;host.garden.hedgehog_intro.active=false;music._process(1)
 assert(not music.suspended and not music.channels[music.active].stream_paused)
 host.garden.guide.show();music._process(1)
 assert(music.pause_player.playing and music.suspended,'Pause plays its song and suspends garden music')
 host.garden.guide.hide();music._process(1)
 assert(not music.pause_player.playing and not music.suspended,'Resume stops pause music')
 host.village=Village.new();host.add_child(host.village)
 music._process(1);assert(music.pause_player.playing,'Village pause plays its song')
 host.village.paused=false;music._process(1);assert(not music.pause_player.playing)
 host.loading=true;music._process(1);assert(music.suspended)
 print('MUSIC_PASS: periods, shuffle, no immediate repeat, arrival song, dialogue ducking, menu/loading pause and resume')
 music.silence()
 await create_timer(0.2).timeout
 host.queue_free()
 await create_timer(0.1).timeout
 quit()
