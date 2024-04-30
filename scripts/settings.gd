extends MenuButton

@export var fishtank: MeshInstance3D
@export var fps_box: ConfirmationDialog
@export var poop_box: ConfirmationDialog
@export var poop_toggle: CheckButton

var _fps_input
var _refresh_rate
var _poop_enabled

# Called when the node enters the scene tree for the first time.
func _ready():
	get_popup().id_pressed.connect(_on_id_pressed.bind())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_id_pressed(id: int):
	var option_str = get_popup().get_item_text(get_popup().get_item_index(id))
	print("Menu Pressed: ", option_str)
	if option_str == "FPS":
		print("Max fps: ", Engine.get_max_fps())
#		_fps_input.get_line_edit().set_text(str(Engine.get_max_fps()))
		_fps_input.set_value(Engine.get_max_fps())
		fps_box.popup()
	elif option_str == "Poop":
		poop_toggle.button_pressed = fishtank.poop_enabled
		poop_box.popup()

func _on_fps_input_text_submitted(new_text):
	var new_fps = int(new_text)
	print("Setting new fps to ", new_fps)
	Engine.set_max_fps(new_fps)
	fishtank.fps = new_fps
	fishtank._setup_timeline()


func _on_fps_box_confirmed():
	var new_fps = int(_fps_input.get_line_edit().get_text())
	print("Setting new fps to ", new_fps)
	Engine.set_max_fps(new_fps)
	fishtank.fps = new_fps
	fishtank._setup_timeline()

func _on_tank_ready():
	_fps_input = fps_box.get_node("FpsInput")
	_refresh_rate = ceil(DisplayServer.screen_get_refresh_rate())
#	_fps_input.get_line_edit().set_text(str(_refresh_rate))
	_fps_input.set_value(_refresh_rate)
	_fps_input.set_tooltip_text(str("Value must be between 1 and ", _refresh_rate, " (monitor refresh rate)"))
	_fps_input.get_line_edit().text_submitted.connect(_on_fps_input_text_submitted.bind())


func _on_poop_toggle_toggled(toggled_on):
	_poop_enabled = toggled_on


func _on_poop_box_confirmed():
	print("Poop enabled: ", _poop_enabled)
	fishtank.poop_enabled = _poop_enabled
