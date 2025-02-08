@tool
extends Control

var tree: Tree
var scan_button: Button
var autoload_references := {}
var script_icon: Texture2D
var folder_icon: Texture2D
var singleton_icon: Texture2D
var function_icon: Texture2D
var signal_icon: Texture2D
var property_icon: Texture2D

class AutoloadUsage:
	var file_path: String
	var line_number: int
	var usage_type: String
	var context: String
	
	func _init(p_path: String, p_line: int, p_type: String, p_context: String):
		file_path = p_path
		line_number = p_line
		usage_type = p_type
		context = p_context

func _ready() -> void:
	name = "Autoload Usage Tracker"
	
	# Load icons
	var editor_interface = EditorPlugin.new().get_editor_interface()
	var base_control = editor_interface.get_base_control()
	script_icon = base_control.get_theme_icon("Script", "EditorIcons")
	folder_icon = base_control.get_theme_icon("Folder", "EditorIcons")
	singleton_icon = base_control.get_theme_icon("Singleton", "EditorIcons")
	function_icon = base_control.get_theme_icon("MemberMethod", "EditorIcons")
	signal_icon = base_control.get_theme_icon("Signal", "EditorIcons")
	property_icon = base_control.get_theme_icon("MemberProperty", "EditorIcons")
	
	_setup_ui()
	_connect_signals()

func _setup_ui() -> void:
	var main_container = MarginContainer.new()
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	add_child(main_container)
	
	var vbox := VBoxContainer.new()
	main_container.add_child(vbox)
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Title with icon
	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)
	
	var title_icon = TextureRect.new()
	title_icon.texture = singleton_icon
	title_icon.custom_minimum_size = Vector2(24, 24)
	title_hbox.add_child(title_icon)
	
	var title = Label.new()
	title.text = "Autoload Usage Tracker"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title)
	
	# Controls bar
	var controls = HBoxContainer.new()
	vbox.add_child(controls)
	
	# Scan button
	scan_button = Button.new()
	scan_button.text = "Scan Project"
	scan_button.icon = folder_icon
	scan_button.custom_minimum_size.y = 32
	controls.add_child(scan_button)
	
	# Filter options
	var filter_options = OptionButton.new()
	filter_options.add_item("All Types")
	filter_options.add_item("Functions")
	filter_options.add_item("Properties")
	filter_options.add_item("Signals")
	controls.add_child(filter_options)
	
	# Stats container
	var stats_label = Label.new()
	stats_label.name = "stats_label"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(stats_label)
	
	# Tree view
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 200
	tree.select_mode = Tree.SELECT_ROW
	tree.columns = 3
	tree.set_column_title(0, "Name")
	tree.set_column_title(1, "Type")
	tree.set_column_title(2, "Usage Context")
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 100)
	tree.set_column_expand(2, true)
	tree.column_titles_visible = true
	vbox.add_child(tree)
	
	# Help text
	var help_label = Label.new()
	help_label.text = "Double-click to open file at usage location"
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(help_label)

func _connect_signals() -> void:
	scan_button.pressed.connect(_on_scan_pressed)
	tree.item_activated.connect(_on_item_activated)

func _on_scan_pressed() -> void:
	print("Starting scan...")
	scan_button.disabled = true
	scan_button.text = "Scanning..."
	
	autoload_references.clear()
	tree.clear()
	var root = tree.create_item()
	tree.hide_root = true
	
	var autoloads = _get_autoloads()
	var total_usages = 0
	print("Found autoloads: ", autoloads)
	
	for autoload in autoloads:
		var autoload_item = tree.create_item(root)
		autoload_item.set_text(0, autoload)
		autoload_item.set_icon(0, singleton_icon)
		
		# Get the actual path of the autoload script
		var autoload_path = ProjectSettings.get_setting("autoload/" + autoload)
		if autoload_path.begins_with("*"):
			autoload_path = autoload_path.substr(1)
		print("Scanning for autoload: ", autoload, " at path: ", autoload_path)
		
		autoload_references[autoload] = []
		_scan_directory("res://", autoload)
		
		for usage in autoload_references[autoload]:
			var usage_item = tree.create_item(autoload_item)
			usage_item.set_text(0, usage.file_path.get_file())
			usage_item.set_text(1, usage.usage_type)
			usage_item.set_text(2, usage.context)
			usage_item.set_icon(0, script_icon)
			
			match usage.usage_type:
				"function":
					usage_item.set_icon(1, function_icon)
				"property":
					usage_item.set_icon(1, property_icon)
				"signal":
					usage_item.set_icon(1, signal_icon)
			
			usage_item.set_metadata(0, {
				"path": usage.file_path,
				"line": usage.line_number
			})
			total_usages += 1
	
	# Update stats
	var stats_label = find_child("stats_label", true, false)
	if stats_label:
		stats_label.text = str(total_usages) + " usages across " + str(autoloads.size()) + " autoloads"
	
	scan_button.disabled = false
	scan_button.text = "Scan Project"
	print("Scan complete!")

func _on_item_activated() -> void:
	var selected = tree.get_selected()
	if selected and selected.get_metadata(0):
		var metadata = selected.get_metadata(0)
		var full_path = "res://" + metadata["path"]
		var editor_interface = EditorPlugin.new().get_editor_interface()
		var script_res = load(full_path)
		editor_interface.edit_resource(script_res)

func _get_autoloads() -> Array:
	var autoloads := []
	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"):
			var autoload_name = property.name.trim_prefix("autoload/")
			autoloads.append(autoload_name)
	return autoloads

func _scan_directory(path: String, autoload_name: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)
			
			if dir.current_is_dir():
				_scan_directory(full_path, autoload_name)
			elif file_name.ends_with(".gd"):
				_scan_file(full_path, autoload_name)
				
		file_name = dir.get_next()

func _scan_file(path: String, autoload_name: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
		
	var content = file.get_as_text()
	var lines = content.split("\n")
	var relative_path = path.trim_prefix("res://")
	
	for line_number in range(lines.size()):
		var line = lines[line_number].strip_edges()
		
		if line.contains(autoload_name):
			if line.begins_with("#") or line.begins_with("//"): 
				continue
				
			if line.contains(autoload_name + "."):
				var after_dot = line.split(autoload_name + ".")[1]
				
				if "(" in after_dot:
					var usage = AutoloadUsage.new(
						relative_path,
						line_number + 1,
						"function",
						line
					)
					autoload_references[autoload_name].append(usage)
				
				else:
					var usage = AutoloadUsage.new(
						relative_path,
						line_number + 1,
						"property",
						line
					)
					autoload_references[autoload_name].append(usage)
			
			elif line.contains("connect") and line.contains("signal"):
				var usage = AutoloadUsage.new(
					relative_path,
					line_number + 1,
					"signal",
					line
				)
				autoload_references[autoload_name].append(usage)
