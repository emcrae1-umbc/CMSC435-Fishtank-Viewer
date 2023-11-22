extends MeshInstance3D

@export var fps: int = 30
@export var fish: PackedScene
@export var food: PackedScene

# Node references
var _file_dialog
var _text_file
var _loading_container
var _loading_bar
var _error_box
var _pause_button
var _curr_time_label
var _total_time_label
var _timeline
# Frame storage
var _fish = [[]]
var _food = [[]]
# Runtime variables
var _tank_paused = true
var _has_fish = false
var _current_time: float = 0.0
var _current_frame: int = 0
var _total_time: float = 0.0
var _total_frames: int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	_file_dialog = get_node("../UserInterface/FileDialog")
	_file_dialog.hide()
	_text_file = get_node("../UserInterface/FileInput/SelectedFile")
	_text_file.set_text("")
	_loading_container = get_node("../UserInterface/LoadingBackground")
	_loading_bar = get_node("../UserInterface/LoadingBackground/LoadingContainer/ProgressBar")
	_loading_container.hide()
	_error_box = get_node("../UserInterface/ErrorDialog")
	_pause_button = get_node("../UserInterface/Timeline/PauseButton")
	_curr_time_label = get_node("../UserInterface/Timeline/TimelineContainer/CurrentTime")
	_total_time_label = get_node("../UserInterface/Timeline/TimelineContainer/TotalTime")
	_timeline = get_node("../UserInterface/Timeline/TimelineContainer/Slider")
	# set target fps
	Engine.set_max_fps(fps)


# Called every frame. 'delta' is the elapsed time since the previous frame.
# delta is in seconds
func _process(delta):
	if _has_fish:
		_clean_tank()
		_show_fish(_current_frame)
		_show_food(_current_frame)
		_update_timeline(_current_frame)
		if  not _tank_paused:
			_current_time += delta
			_current_frame += 1
			if _current_frame >= _total_frames:
				_current_time = 0
				_current_frame = 1


# Open File button pressed
func _on_open_file_pressed():
	_tank_paused = true
	_file_dialog.show()


# File selected in file dialog
func _on_file_dialog_file_selected(path):
	_text_file.set_text(path)
	_file_dialog.hide()
	_tank_paused = false


# Load File button pressed
func _on_load_file_pressed():
	# TODO: error handling for each line grab and regex parsing
	if not _text_file.get_text().is_empty():
		print("Loading ", _text_file.get_text())
		var thread := Thread.new()
		var err = thread.start(_load_file_threadwork.bind(_text_file.get_text()))
		if err:
			push_error("Couldn't start file loading thread. Error code = %d" % [ err ])
			return
#		var _error = await self.file_load_finished
		var _error = thread.wait_to_finish()
		if _error[0]:
			_error_box.set_text(_error[1] + "\nError Code = " + str(_error[0]))
			_error_box.show()
			pass
		else:
			_setup_timeline()
			_current_frame = 1
			_current_time = 0


func _setup_timeline():
	_timeline.set_max(_total_frames)
	_timeline.set_value_no_signal(0)
	var time = float(_total_frames) / fps
	var total_string = "%.1f Sec\n%3d Frames" % [time, _total_frames]
	_total_time_label.set_text(total_string)


func _update_timeline(frame):
	_timeline.set_value_no_signal(frame)
#	var time = float(frame) / fps
	var total_string = "%.1f Sec\nFrame %03d" % [_current_time, frame]
	_curr_time_label.set_text(total_string)


func _clean_tank():
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _show_fish(frame):
	for f in _fish[frame]:
		# Spawn instance of fish
		var fish_inst = fish.instantiate()
		# Adjust cone length to z*10*sqrt(vel.norm())
		var curr = fish_inst.get_child(1).get_scale()
		var axis = f.velocity
		var speed_sq = axis.length_squared()
		var dir = f.position + Vector3(0, 0, 1)
		if speed_sq > 1e-4:
			var speed = sqrt(speed_sq)
			axis /= speed
			# Cone is the second node in the scene
			fish_inst.get_child(1).set_scale(Vector3(curr.x, curr.y, curr.z*10*sqrt(speed)))
			# Rotate to same direction as vel
			dir = f.position - axis
		# Move to position
		fish_inst.look_at_from_position(f.position, dir)
		add_child(fish_inst)


func _show_food(frame):
	for f in _food[frame]:
		# Spawn instance of food
		var food_inst = food.instantiate()
		# Move to position
		food_inst.set_position(f.position)
		add_child(food_inst)


# Does all the actual loading in a thread so the loading bar can be updated
# returns an array of the form [Error, err_string]
func _load_file_threadwork(file) -> Array:
	# Clear out arrays incase fish already exist (reloading file)
	_fish = [[]]
	_food = [[]]
	# open file
	var f = FileAccess.open(file, FileAccess.READ)
	# first line of file is the number of frames
	var nframes = f.get_line().to_int()
	_total_frames = nframes
	# set loading bar info
	call_deferred("_setup_load_progress", nframes)
	for frame in range(nframes):
		var fish_array = []
		var food_array = []
		if f.eof_reached():
			# show error message here
			var err_str = "Only able read in " + str(frame) + " of " + str(nframes) + " frames."
			return [ERR_FILE_EOF, err_str]
		# get the number of fish for the current frame
		var num_fish = f.get_line().to_int()
		if f.eof_reached():
			# show error message here
			var err_str = "No more fish after specifying " + str(num_fish) + " for frame " + str(frame)
			return [ERR_FILE_EOF, err_str]
		for i in range(num_fish):
			var fish_string = f.get_line()
			if f.eof_reached():
				# show error message here
				var err_str = "Only able read in " + str(i) + " of " + str(num_fish) + " fish for frame " + str(frame) + "."
				return [ERR_FILE_EOF, err_str]
			# Tried using regex to test for correctness as well, but was too complicated to be able 
			# to match all forms of decimal numbers and exponentials
			var fish_str = fish_string.replace("[", " ")
			fish_str = fish_str.replace("]", " ")
			fish_str = fish_str.replace(",", " ")
			var fish_arr = fish_str.split_floats(" ", false)
			# Do the error checking here, should be 6 floats
			if fish_arr.size() != 6:
				var err_str = "Invalid input: Fish " + str(i) + " in frame " + str(frame) + ": " + fish_string
				return [ERR_INVALID_DATA, err_str]
			var new_fish = Fish.new()
			new_fish.position = Vector3(fish_arr[0], fish_arr[1], fish_arr[2])
			new_fish.velocity = Vector3(fish_arr[3], fish_arr[4], fish_arr[5])
			fish_array.push_back(new_fish)
		var num_food = f.get_line().to_int()
		for i in range(num_food):
			var food_string = f.get_line()
			if f.eof_reached():
				# show error message here
				var err_str = "Only able read in " + str(i) + " of " + str(num_food) + " food for frame " + str(frame) + "."
				return [ERR_FILE_EOF, err_str]
			var food_str = food_string.replace("[", " ")
			food_str = food_str.replace("]", " ")
			food_str = food_str.replace(",", " ")
			var food_arr = food_str.split_floats(" ", false)
			if food_arr.size() != 3:
				var err_str = "Invalid input: Food " + str(i) + " in frame " + str(frame) + ": " + food_string
				return [ERR_INVALID_DATA, err_str]
			var new_food = Food.new()
			new_food.position = Vector3(food_arr[0], food_arr[1], food_arr[2])
			food_array.push_back(new_food)
		_fish.push_back(fish_array)
		_food.push_back(food_array)
#		await get_tree().create_timer(0.1).timeout
		call_deferred("_file_load_progress_changed", frame)
#		emit_signal("file_load_progress_changed", frame)
#	emit_signal("file_load_finished", OK)
	call_deferred("_finish_load_progress")
	print("load done")
	return [OK, "OK"]


func _setup_load_progress(num_frames):
	_loading_bar.set_max(num_frames)
	_total_time = num_frames * (1.0 / fps)
	_loading_bar.set_value(0)
	_loading_container.show()


func _file_load_progress_changed(progress):
	_loading_bar.set_value(progress)


func _finish_load_progress():
	_loading_container.hide()
	_tank_paused = false
	_has_fish = true


func _pause_tank():
	_tank_paused = true
	_pause_button.set_pressed(true)


func _on_pause_button_toggled(button_pressed):
	_tank_paused = button_pressed


func _on_slider_value_changed(value):
	_pause_tank()
	_current_frame = value
	_current_time = float(_current_frame) / fps


func _on_skip_first_pressed():
	_current_frame = 1
	_current_time = 0.0
	_pause_tank()


func _on_skip_last_pressed():
	_current_frame = _total_frames
	_current_time = _total_time
	_pause_tank()


func _on_step_back_pressed():
	if _current_frame > 1:
		_current_frame -= 1
		_current_time -= 1.0 / fps
		_pause_tank()


func _on_step_forward_pressed():
	if _current_frame < _total_frames:
		_current_frame += 1
		_current_time += 1.0 / fps
		_pause_tank()


class Fish:
	var position: Vector3 = Vector3.ZERO:
		set(new_position):
			position = new_position
		get:
			return position
	var velocity: Vector3 = Vector3.ZERO:
		set(new_velocity):
			velocity = new_velocity
		get:
			return velocity
	
	func _to_string():
		return "Position: " + str(position) + ", Velocity: " + str(velocity)


class Food:
	var position: Vector3 = Vector3.ZERO:
		set(new_position):
			position = new_position
		get:
			return position
