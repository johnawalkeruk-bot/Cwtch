extends SceneTree
func _initialize():run.call_deferred()
func run():
 var menu=load('res://main_menu.tscn').instantiate()
 root.add_child(menu)
 current_scene=menu
 await process_frame
 menu._open_account()
 assert(menu.account_panel.visible)
 await menu._begin_garden(true)
 var g=menu.garden
 assert(g.tool==4 and g.floating_tool.selected==4)
 assert(g.local_coop.second.floating_tool.selected==4)
 assert(is_equal_approx(g.northern_arrival.crossing.rotation.y,-PI/2))
 assert(menu._save_garden())
 var snapshot=JSON.parse_string(FileAccess.get_file_as_string(menu.SAVE_PATH))
 assert(preload('res://cloud_save_validator.gd').valid(snapshot))
 var bad=snapshot.duplicate(true)
 bad['player']={}
 assert(not preload('res://cloud_save_validator.gd').valid(bad))
 bad=snapshot.duplicate(true);bad['watered']=[[1]]
 assert(not preload('res://cloud_save_validator.gd').valid(bad))
 bad=snapshot.duplicate(true);bad['crops']=[{}]
 assert(not preload('res://cloud_save_validator.gd').valid(bad))
 menu.cloud.connected=false
 menu.use_cloud_garden(snapshot)
 assert(not is_instance_valid(menu.garden))
 assert(FileAccess.get_file_as_string(menu.SAVE_PATH).length()>100)
 menu.cloud.connected=false
 await menu._begin_garden(false)
 assert(menu.garden.tool==4)
 assert(menu._save_garden())
 var result=await menu.cloud._request('/auth/v1/settings',HTTPClient.METHOD_GET)
 assert(result.ok)
 print('CLOUD_HTTPS_SETTINGS: passed')
 var access=await menu.cloud._request('/rest/v1/cwtch_saves?select=revision',HTTPClient.METHOD_GET)
 assert(not access.ok and access.code==401)
 print('ANON_READ: denied')
 var write=await menu.cloud._request('/rest/v1/rpc/cwtch_put_save',HTTPClient.METHOD_POST,{'expected_revision':0,'garden':snapshot})
 assert(not write.ok and write.code==401)
 print('ANON_WRITE: denied')
 print('ACCOUNT_PASS: unequipped players, rabbit facing, local save, restore, backup, malformed saves rejected')
 menu.queue_free()
 await process_frame
 quit()
