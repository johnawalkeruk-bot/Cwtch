extends PanelContainer
var host: Node
var account: Node
var address: LineEdit
var username: LineEdit
var claim: Button
var password: LineEdit
var notice: Label
var actions: Array[Button]=[]
var upload: Button
var download: Button
var review: Button
var signout: Button
var confirmation: ConfirmationDialog
var pending := ""
func setup(owner_node: Node, client: Node) -> void:
 host=owner_node
 account=client
 set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 offset_left=-300;offset_right=300;offset_top=-330;offset_bottom=330
 add_theme_stylebox_override("panel",preload("res://cwtch_theme.gd").panel(Color("182e28")))
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation",10)
 add_child(box)
 var title := Label.new()
 title.text="YOUR VALLEY ACCOUNT"
 title.add_theme_font_size_override("font_size",25)
 box.add_child(title)
 address=LineEdit.new();address.placeholder_text="Email address";box.add_child(address)
 username=LineEdit.new();username.placeholder_text="Username (new accounts: 3–20 letters, numbers, _)";username.max_length=20;box.add_child(username)
 password=LineEdit.new();password.placeholder_text="Password";password.secret=true;box.add_child(password)
 button(box,"SIGN IN",func(): authenticate(false))
 button(box,"REGISTER",func(): authenticate(true))
 button(box,"RESET PASSWORD",func(): account.reset_password(address.text))
 claim=button(box,"CLAIM USERNAME",func(): account.claim_username(username.text))
 notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.y=75;box.add_child(notice)
 upload=button(box,"USE THIS COMPUTER'S GARDEN",func(): ask("upload"))
 download=button(box,"USE CLOUD GARDEN",func(): ask("download"))
 review=button(box,"REVIEW CLOUD / RETRY",func(): account.inspect())
 signout=button(box,"SIGN OUT",func(): account.logout())
 button(box,"BACK",func():
  hide();host.menu_buttons.show();host.heading.show();host._focus_menu())
 confirmation=ConfirmationDialog.new()
 add_child(confirmation)
 confirmation.confirmed.connect(confirm)
 account.changed.connect(refresh)
 refresh()
 hide()
func button(box: Node, caption: String, action: Callable) -> Button:
 var item := Button.new();item.text=caption;item.custom_minimum_size.y=34
 item.pressed.connect(action);box.add_child(item);actions.append(item)
 return item
func authenticate(register: bool) -> void:
 if not address.text.contains("@") or password.text.length()<8:
  account.status="Enter your email and a password of at least eight characters."
  refresh()
  return
 var secret := password.text
 password.clear()
 account.authenticate(address.text,secret,register,username.text)
func refresh() -> void:
 notice.text=account.status
 if not account.profile.is_empty():notice.text=str(account.profile.username)+"\n"+notice.text
 if not account.email.is_empty():notice.text=account.email+"\n"+notice.text
 if not account.remote.is_empty():
  var payload: Dictionary=account.remote.get("payload",{})
  notice.text+="\nCloud: %d coins · saved %s"%[int(payload.get("coins",0)),str(account.remote.get("updated_at","")).left(16)]
 for action in actions:action.disabled=account.busy
 var signed: bool=not account.token.is_empty()
 address.visible=not signed
 password.visible=not signed
 username.visible=not signed or account.profile.is_empty()
 claim.visible=signed and account.profile.is_empty()
 for i in 3:actions[i].visible=not signed
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
  account.sync(data,true)
 else:host.use_cloud_garden(account.remote.get("payload",{}))
