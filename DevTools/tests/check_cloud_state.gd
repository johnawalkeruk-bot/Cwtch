extends SceneTree
class FakeAccount extends "res://cloud_account.gd":
 var calls: Array=[]
 var replies: Array=[]
 func _request(path: String, _method: int, body: Dictionary={}, _authorized: bool=false) -> Dictionary:
  calls.append({"path":path,"body":body})
  await get_tree().process_frame
  return replies.pop_front()
func _initialize():run.call_deferred()
func run():
 var a=FakeAccount.new()
 root.add_child(a)
 a.token='fake';a.expires=Time.get_unix_time_from_system()+600
 a.revision=0
 a.sync({'version':1})
 assert(a.calls.is_empty(),'First sync needs a choice')
 a.replies=[{'ok':true,'data':{'revision':1,'updated_at':'test'}}]
 var parsed=JSON.parse_string('{"version":1}')
 await a.sync(parsed,true)
 assert(typeof(a.calls[-1].body.garden.version)==TYPE_INT,'Upload normalizes parsed version')
 assert(JSON.stringify(a.calls[-1].body).contains('"version":1}'),'Server must receive version 1, not 1.0')
 assert(a.connected and a.revision==1 and a.remote.revision==1)
 a.replies=[{'ok':false,'code':409,'error':'Cloud garden changed'}]
 await a.sync({'version':1})
 assert(not a.connected and a.revision==1)
 a.replies=[{'ok':false,'code':503,'error':'Offline'}]
 await a.inspect()
 assert(a.revision==-1 and a.remote.is_empty(),'Failed review must disable stale writes')
 a.replies=[{'ok':false,'code':400,'error':'Invalid login'}]
 await a.authenticate('fixture@example.invalid','not-a-real-password',false)
 assert(a.token.is_empty() and a.email.is_empty())
 a.queue_free()
 print('CLOUD_STATE_PASS: first-sync choice, revisions, conflict pause, failed review, account switch')
 await process_frame
 quit()
