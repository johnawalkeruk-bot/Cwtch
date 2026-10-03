extends SceneTree
func _initialize():run.call_deferred()
func run():
 var store=load('res://session_store.gd').new();root.add_child(store)
 var sample={"refresh_token":"fixture-refresh-only","email":"fixture@example.invalid","revision":7,"connected":true}
 assert(await store.save(sample),'DPAPI protect writes a remembered login')
 var bytes=FileAccess.get_file_as_bytes(store.PATH)
 assert(not bytes.get_string_from_ascii().contains('fixture-refresh-only'),'No plaintext token on disk')
 var restored=await store.read()
 assert(restored.get('refresh_token')==sample.refresh_token and int(restored.get('revision',-1))==7 and restored.get('connected')==true,'DPAPI unprotect restores the session')
 store.clear();assert(not FileAccess.file_exists(store.PATH),'Signout removes remembered login')
 store.queue_free();await process_frame
 print('SESSION_STORE_PASS: encrypted roundtrip and removal');quit()
