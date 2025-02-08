@tool
extends EditorPlugin

const AutoloadTrackerDock = preload("autoload_tracker_dock.gd")
var dock_instance: Control
var toolbar_button: Button

func _enter_tree() -> void:
	dock_instance = AutoloadTrackerDock.new()
	add_control_to_bottom_panel(dock_instance, "Autoloads")
	
	toolbar_button = Button.new()
	toolbar_button.text = "Autoloads"
	toolbar_button.toggle_mode = true
	toolbar_button.icon = get_editor_interface().get_base_control().get_theme_icon("Singleton", "EditorIcons")
	toolbar_button.pressed.connect(_on_toolbar_button_pressed)
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
	
func _exit_tree() -> void:
	if dock_instance:
		remove_control_from_bottom_panel(dock_instance)
		dock_instance.free()
	if toolbar_button:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
		toolbar_button.free()

func _on_toolbar_button_pressed() -> void:
	if toolbar_button.button_pressed:
		make_bottom_panel_item_visible(dock_instance)
	else:
		hide_bottom_panel()
	
func _handles(object) -> bool:
	return false

func _get_plugin_name() -> String:
	return "Autoloads"

func _make_visible(visible: bool) -> void:
	if visible:
		make_bottom_panel_item_visible(dock_instance)
	else:
		hide_bottom_panel()
	if toolbar_button:
		toolbar_button.button_pressed = visible
