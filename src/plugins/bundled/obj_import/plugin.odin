package obj_import

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "../../../editor_state"

// Plugin runtime state (local copy to avoid circular dependency)
Plugin_State :: struct {
    enabled: bool,
    initialized: bool,
}

// Plugin interface (local copy to avoid circular dependency)
Plugin :: struct {
    name: string,
    version: string,
    author: string,
    
    // Required callbacks
    init: proc(editor_state: ^editor_state.State) -> bool,
    update: proc(editor_state: ^editor_state.State, dt: f32),
    cleanup: proc(editor_state: ^editor_state.State),
    
    // Optional callbacks
    on_menu_item: proc(menu_item: string) -> bool,
    on_import_format: proc(filepath: string) -> (model: rl.Model, success: bool),
    
    // Runtime state
    state: Plugin_State,
}

// Plugin information
plugin_info := Plugin{
    name = "OBJ Import Support",
    version = "0.1.0",
    author = "Alexander Glavan",
    init = plugin_init,
    cleanup = plugin_cleanup,
    on_import_format = handle_import,
}

@export
get_plugin :: proc() -> ^Plugin {
    return &plugin_info
}

plugin_init :: proc(editor_state: ^editor_state.State) -> bool {
    fmt.println("OBJ Import Plugin: Initializing...")
    // Plugin initialization logic here
    return true
}

plugin_cleanup :: proc(editor_state: ^editor_state.State) {
    fmt.println("OBJ Import Plugin: Cleaning up...")
    // Plugin cleanup logic here
}

handle_import :: proc(filepath: string) -> (model: rl.Model, success: bool) {
    if !strings.has_suffix(strings.to_lower(filepath), ".obj") {
        return {}, false  // Not our format
    }
    
    fmt.printf("OBJ Plugin: Loading %s\n", filepath)
    
    // Use the OBJ loading code (moved from core)
    return load_obj_model(filepath)
}