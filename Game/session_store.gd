extends Node
## Windows DPAPI: only the current Windows user can decrypt the remembered login.
var generation:=0
var writing:=false
const PATH := "user://account_session.bin"
const COMMAND := """$ErrorActionPreference='Stop';try{Add-Type -AssemblyName System.Security;$r=[Console]::ReadLine()|ConvertFrom-Json;$b=[Convert]::FromBase64String($r.data);if($r.mode -eq 'protect'){$v=[Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)}else{$v=[Security.Cryptography.ProtectedData]::Unprotect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)};[Console]::WriteLine([Convert]::ToBase64String($v))}catch{[Console]::WriteLine('FAILED');exit 1}"""

func crypt(data: PackedByteArray, mode: String) -> PackedByteArray:
 if OS.get_name()!="Windows":return PackedByteArray()
 var exe:=OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
 var process:=OS.execute_with_pipe(exe,PackedStringArray(["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-Command",COMMAND]),false)
 if process.is_empty():return PackedByteArray()
 var pipe: FileAccess=process.stdio
 pipe.store_line(JSON.stringify({"mode":mode,"data":Marshalls.raw_to_base64(data)}))
 var deadline:=Time.get_ticks_msec()+10000
 while OS.is_process_running(process.pid) and Time.get_ticks_msec()<deadline:await get_tree().process_frame
 if OS.is_process_running(process.pid):
  OS.kill(process.pid)
  return PackedByteArray()
 var reply:=pipe.get_line().strip_edges()
 pipe.close()
 if reply=="FAILED" or reply.is_empty():return PackedByteArray()
 return Marshalls.base64_to_raw(reply)

func save(data: Dictionary) -> bool:
 var epoch:=generation
 while writing:await get_tree().process_frame
 if epoch!=generation:return false
 writing=true
 var protected:=await crypt(JSON.stringify(data).to_utf8_buffer(),"protect")
 writing=false
 if epoch!=generation or protected.is_empty():return false
 var file:=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
 if not file:return false
 file.store_buffer(protected);file.flush()
 var ok:=file.get_error()==OK
 file.close()
 return ok and DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH+".tmp"),ProjectSettings.globalize_path(PATH))==OK

func read() -> Dictionary:
 if not FileAccess.file_exists(PATH):return {}
 var bytes:=await crypt(FileAccess.get_file_as_bytes(PATH),"unprotect")
 var value=JSON.parse_string(bytes.get_string_from_utf8()) if not bytes.is_empty() else null
 return value if value is Dictionary else {}

func clear() -> void:
 generation+=1
 for name in [PATH,PATH+".tmp"]:
  if FileAccess.file_exists(name):DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
