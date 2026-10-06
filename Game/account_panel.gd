extends PanelContainer
var host: Node
var account: Node
var address: LineEdit
var password: LineEdit
var register_address: LineEdit
var register_password: LineEdit
var username: LineEdit
var claim_name: LineEdit
var claim_box: VBoxContainer
var notice: Label
var login_box: VBoxContainer
var register_box: VBoxContainer
var tabs: HBoxContainer
var login_tab: Button
var register_tab: Button
var registration:=false
var actions: Array[Button]=[]
var upload: Button
var download: Button
var review: Button
var signout: Button
var confirmation: ConfirmationDialog
var pending := ""
var auth_feedback:=false
var upload_feedback:=false
func setup(owner_node: Node, client: Node) -> void:
 host=owner_node;account=client
 set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 offset_left=-300;offset_right=300;offset_top=-325;offset_bottom=325
 add_theme_stylebox_override("panel",preload("res://cwtch_theme.gd").panel(Color("182e28")))
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);add_child(box)
 var title:=Label.new();title.text="YOUR VALLEY ACCOUNT";title.add_theme_font_size_override("font_size",25);box.add_child(title)
 tabs=HBoxContainer.new();box.add_child(tabs)
 login_tab=button(tabs,"SIGN IN",func(): set_registration(false))
 register_tab=button(tabs,"CREATE ACCOUNT",func(): set_registration(true))
 login_box=VBoxContainer.new();box.add_child(login_box)
 address=field(login_box,"Email address")
 password=field(login_box,"Password",true)
 button(login_box,"SIGN IN",func(): authenticate(false))
 button(login_box,"RESET PASSWORD",func(): account.reset_password(address.text))
 register_box=VBoxContainer.new();box.add_child(register_box)
 username=field(register_box,"Username · 3–20 letters, numbers or underscores");username.max_length=20
 register_address=field(register_box,"Email address")
 register_password=field(register_box,"Password · at least eight characters",true)
 button(register_box,"CREATE ACCOUNT",func(): authenticate(true))
 claim_box=VBoxContainer.new();box.add_child(claim_box)
 claim_name=field(claim_box,"Choose your username");claim_name.max_length=20
 button(claim_box,"CLAIM USERNAME",func(): account.claim_username(claim_name.text))
 notice=Label.new();notice.uppercase=true;notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.y=80;box.add_child(notice)
 upload=button(box,"USE THIS COMPUTER'S GARDEN",func(): ask("upload"))
 download=button(box,"USE CLOUD GARDEN",func(): ask("download"))
 review=button(box,"REVIEW CLOUD / RETRY",func(): account.inspect())
 signout=button(box,"SIGN OUT",func(): account.logout())
 button(box,"BACK",func(): hide();host.menu_buttons.show();host.heading.show();host._focus_menu())
 confirmation=ConfirmationDialog.new();add_child(confirmation);confirmation.confirmed.connect(confirm)
 confirmation.get_cancel_button().text="CANCEL"
 confirmation.title="CONFIRM CLOUD SAVE"
 account.changed.connect(refresh)
 account.auth_finished.connect(func(ok: bool):
  if auth_feedback and is_visible_in_tree():UISounds.play("success" if ok else "error")
  auth_feedback=false)
 account.sync_finished.connect(func(ok: bool, _message: String):
  if upload_feedback and is_visible_in_tree():UISounds.play("success" if ok else "error")
  upload_feedback=false)
 visibility_changed.connect(func():
  if not visible:auth_feedback=false;upload_feedback=false)
 refresh();hide()
func field(parent: Node, hint: String, secret:=false) -> LineEdit:
 var item:=LineEdit.new();item.placeholder_text=hint.to_upper();item.secret=secret;parent.add_child(item);return item
func button(box: Node, caption: String, action: Callable) -> Button:
 var item:=Button.new();item.text=caption.to_upper();item.custom_minimum_size.y=34;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 item.pressed.connect(action);box.add_child(item);actions.append(item);return item
func set_registration(value: bool) -> void:
 if registration!=value:UISounds.play("select")
 registration=value;password.clear();register_password.clear();refresh()
 ControllerInput.focus_first.call_deferred(register_box if value else login_box)
func authenticate(register: bool) -> void:
 var mail:=register_address.text if register else address.text
 var secret:=register_password.text if register else password.text
 if not mail.contains("@") or secret.is_empty() or (register and secret.length()<8):
  account.status="Enter your email and a password of at least eight characters." if register else "Enter your email and password."
  UISounds.play("error");refresh();return
 auth_feedback=true
 password.clear();register_password.clear()
 account.authenticate(mail,secret,register,username.text if register else "")
func refresh() -> void:
 notice.text=account.status
 if not account.profile.is_empty():notice.text=str(account.profile.get("username",""))+"\n"+notice.text
 if not account.remote.is_empty():
  var payload: Dictionary=account.remote.get("payload",{})
  notice.text+="\nCloud: %d coins · saved %s"%[int(payload.get("coins",0)),str(account.remote.get("updated_at","")).left(16)]
 for action in actions:action.disabled=account.busy
 var signed: bool=not account.token.is_empty()
 tabs.visible=not signed;login_box.visible=not signed and not registration;register_box.visible=not signed and registration
 login_tab.disabled=account.busy or not registration;register_tab.disabled=account.busy or registration
 claim_box.visible=signed and account.profile.is_empty()
 upload.visible=signed;download.visible=signed;review.visible=signed;signout.visible=signed
 upload.disabled=account.busy or account.revision<0 or not FileAccess.file_exists(host.SAVE_PATH)
 download.disabled=account.busy or account.remote.is_empty()
func ask(choice: String) -> void:
 pending=choice
 confirmation.dialog_text="Replace the cloud garden with this computer's garden?" if choice=="upload" else "Replace this computer's garden with the cloud garden? A local backup will be kept."
 confirmation.popup_centered()
func confirm() -> void:
 if account.busy:return
 if pending=="upload":
  account.connected=false
  if not host._save_garden():account.status="Local save failed. Nothing uploaded.";refresh();return
  var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(host.SAVE_PATH))
  if not preload("res://cloud_save_validator.gd").valid(data):account.status="This save cannot be synced safely.";refresh();return
  upload_feedback=true
  account.sync(data,true)
 else:host.use_cloud_garden(account.remote.get("payload",{}))
