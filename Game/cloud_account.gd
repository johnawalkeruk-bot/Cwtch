extends Node
## Tokens live in memory only. First sync is always an explicit local/cloud choice.
signal changed
const Config = preload("res://cloud_config.gd")
var token := ""
var refresh_token := ""
var email := ""
var expires := 0.0
var revision := -1
var connected := false
var busy := false
var status := "Play offline, or sign in to keep a garden in the cloud."
var remote: Dictionary = {}
var queued: Dictionary = {}

func _request(path: String, method: int, body: Dictionary={}, authorized: bool=false) -> Dictionary:
 var http := HTTPRequest.new()
 http.timeout=15
 http.body_size_limit=4000000
 add_child(http)
 var headers := PackedStringArray(["apikey: "+Config.KEY,"Content-Type: application/json"])
 if authorized:headers.append("Authorization: Bearer "+token)
 var err := http.request(Config.URL+path,headers,method,JSON.stringify(body) if method!=HTTPClient.METHOD_GET else "")
 if err!=OK:
  http.queue_free()
  return {"ok":false,"error":"Could not connect. Your local garden is safe."}
 var reply: Array=await http.request_completed
 http.queue_free()
 var parsed: Variant=JSON.parse_string(reply[3].get_string_from_utf8())
 var code: int=reply[1]
 if reply[0]!=HTTPRequest.RESULT_SUCCESS:return {"ok":false,"error":"Connection interrupted. Your local garden is safe."}
 if code<200 or code>=300:
  var message := "Cloud service unavailable (%d)."%code
  if parsed is Dictionary:message=str(parsed.get("msg",parsed.get("message",parsed.get("error_description",message))))
  return {"ok":false,"error":message,"code":code}
 return {"ok":true,"data":parsed}

func _session(data: Dictionary) -> void:
 token=str(data.get("access_token",""))
 refresh_token=str(data.get("refresh_token",""))
 expires=Time.get_unix_time_from_system()+float(data.get("expires_in",3600))-60
 email=str(data.get("user",{}).get("email",""))

func _refresh() -> bool:
 if token.is_empty():return false
 if Time.get_unix_time_from_system()<expires:return true
 var result := await _request("/auth/v1/token?grant_type=refresh_token",HTTPClient.METHOD_POST,{"refresh_token":refresh_token})
 if result.ok:
  _session(result.data)
  return true
 status="Session expired. Sign in again. Your local save is safe."
 connected=false
 return false

func authenticate(address: String, password: String, register: bool) -> void:
 if busy:return
 busy=true
 token=""
 refresh_token=""
 email=""
 connected=false
 queued={}
 status="Creating account…" if register else "Signing in…"
 changed.emit()
 var endpoint := "/auth/v1/signup?redirect_to="+Config.RETURN_URL.uri_encode() if register else "/auth/v1/token?grant_type=password"
 var result := await _request(endpoint,HTTPClient.METHOD_POST,{"email":address.strip_edges(),"password":password})
 connected=false
 revision=-1
 remote={}
 if not result.ok:status=result.error
 elif result.data is Dictionary and result.data.has("access_token"):
  _session(result.data)
  await _inspect()
 else:status="Check your email to confirm your account, then sign in."
 busy=false
 changed.emit()

func _inspect() -> void:
 revision=-1
 remote={}
 if not await _refresh():return
 var result := await _request("/rest/v1/cwtch_saves?select=payload,revision,updated_at",HTTPClient.METHOD_GET,{},true)
 if not result.ok:status=result.error;return
 remote={}
 revision=0
 if result.data is Array and not result.data.is_empty():
  remote=result.data[0]
  revision=int(remote.revision)
 status="Choose which garden to keep. Cloud revision: %d."%revision if revision>0 else "No cloud garden yet. Upload your local garden to begin syncing."

func inspect() -> void:
 if busy:return
 busy=true
 connected=false
 queued={}
 await _inspect()
 busy=false
 changed.emit()

func sync(data: Dictionary, explicit: bool=false) -> void:
 if token.is_empty() or (not connected and not explicit):return
 if busy:
  if connected:queued=data.duplicate(true)
  return
 if revision<0:return
 busy=true
 status="Syncing garden…"
 changed.emit()
 if not await _refresh():
  busy=false
  changed.emit()
  return
 # JSON.parse_string represents numbers as floats. Keep the wire version an
 # integer: the deployed RPC compares the extracted version text with '1'.
 var upload := data.duplicate(true)
 upload["version"]=int(upload.get("version",0))
 var result := await _request("/rest/v1/rpc/cwtch_put_save",HTTPClient.METHOD_POST,{"expected_revision":revision,"garden":upload},true)
 if result.ok:
  revision=int(result.data.revision)
  connected=true
  remote={"payload":data.duplicate(true),"revision":revision,"updated_at":result.data.get("updated_at","")}
  status="Garden synced · revision %d"%revision
 else:
  status=result.error+" Local save kept. Review cloud to retry."
  connected=false
  queued={}
 busy=false
 changed.emit()
 if connected and not queued.is_empty():
  var next := queued
  queued={}
  sync(next)

func logout() -> void:
 if busy:return
 busy=true
 changed.emit()
 if not token.is_empty():await _request("/auth/v1/logout?scope=local",HTTPClient.METHOD_POST,{},true)
 token=""
 refresh_token=""
 email=""
 remote={}
 queued={}
 revision=-1
 connected=false
 busy=false
 status="Signed out. Your garden remains on this computer."
 changed.emit()

func reset_password(address: String) -> void:
 if busy:return
 busy=true
 changed.emit()
 var result := await _request("/auth/v1/recover?redirect_to="+Config.RETURN_URL.uri_encode(),HTTPClient.METHOD_POST,{"email":address.strip_edges()})
 status="If that account exists, check your email for a reset link." if result.ok else result.error
 busy=false
 changed.emit()
