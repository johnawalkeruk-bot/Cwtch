extends SceneTree
class MemoryStore extends Node:
 var data={"refresh_token":"fixture","email":"player@example.invalid","username":"Gardener","revision":7,"connected":true}
 func read():return data.duplicate()
 func save(value):data=value.duplicate();return true
 func clear():data={}
class Account extends "res://cloud_account.gd":
 var calls=[]
 var replies=[]
 func _request(path,method,body={},authorized=false):
  calls.append({"path":path,"body":body})
  await get_tree().process_frame
  return replies.pop_front()
func _initialize():run.call_deferred()
func run():
 var a=Account.new();root.add_child(a)
 a.store.queue_free();a.store=MemoryStore.new();a.add_child(a.store)
 a.replies=[{'ok':true,'data':{'access_token':'fixture-access','refresh_token':'rotated','expires_in':3600,'user':{'email':'player@example.invalid'}}},{'ok':true,'data':{'username':'Gardener'}}]
 await a.restore_login()
 assert(a.connected and a.revision==7 and a.profile.username=='Gardener')
 assert(a.store.data.refresh_token=='rotated','Rotating refresh token is remembered')
 assert(a.calls.size()==2,'Restore must not fetch a newer revision and silently overwrite another device')
 a.replies=[{'ok':false,'code':409,'error':'Cloud garden changed'}]
 await a.sync({'version':1})
 assert(a.calls[-1].body.expected_revision==7 and not a.connected)
 assert(not a.store.data.connected,'Conflict remains paused after restart')
 a.replies=[{'ok':true,'data':{}}]
 await a.logout()
 assert(a.store.data.is_empty() and a.token.is_empty())
 a.queue_free();await process_frame
 print('REMEMBERED_ACCOUNT_PASS: restore, refresh rotation, revision protection, conflict and signout');quit()
