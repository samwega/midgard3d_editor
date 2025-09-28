package plugins

import "../editor_state"
import "../core"
import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

// Plugin imports
import obj_plugin "./bundled/obj_import"

// Build-time plugin configuration via -define flags
// Default values (can be overridden with -define:PLUGIN_OBJ_IMPORT=false etc.)
OBJ_IMPORT_ENABLED :: #config(PLUGIN_OBJ_IMPORT, true)
TERRAIN_GENERATOR_ENABLED :: #config(PLUGIN_TERRAIN_GENERATOR, false) 
PERFORMANCE_TOOLS_ENABLED :: #config(PLUGIN_PERFORMANCE_TOOLS, false)

// Plugin runtime state
Plugin_State :: struct {
    enabled: bool,
    initialized: bool,
}

// Plugin interface
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

// Global plugin registry
registered_plugins: [dynamic]Plugin

// Plugin management functions
register_plugin :: proc(plugin: Plugin) {
    fmt.printf("Registering plugin: %s v%s by %s\n", plugin.name, plugin.version, plugin.author)
    append(&registered_plugins, plugin)
}

init_all_plugins :: proc(editor_state: ^editor_state.State) {
    for &plugin in registered_plugins {
        if plugin.init != nil {
            success := plugin.init(editor_state)
            plugin.state.initialized = success
            plugin.state.enabled = success  // Default: enabled if init succeeded
            
            if success {
                fmt.printf("✓ Plugin initialized: %s\n", plugin.name)
            } else {
                fmt.printf("✗ Plugin failed to initialize: %s\n", plugin.name)
            }
        }
    }
}

update_plugins :: proc(editor_state: ^editor_state.State, dt: f32) {
    for &plugin in registered_plugins {
        if plugin.state.enabled && plugin.update != nil {
            plugin.update(editor_state, dt)
        }
    }
}

cleanup_plugins :: proc(editor_state: ^editor_state.State) {
    for &plugin in registered_plugins {
        if plugin.cleanup != nil {
            plugin.cleanup(editor_state)
        }
    }
}

// Handle import format through plugins
handle_import_via_plugins :: proc(filepath: string) -> (model: rl.Model, success: bool) {
    for &plugin in registered_plugins {
        if plugin.state.enabled && plugin.on_import_format != nil {
            if model, ok := plugin.on_import_format(filepath); ok {
                return model, true
            }
        }
    }
    return {}, false
}

// Initialize plugin panel
init_plugin_panel :: proc(editor_state: ^editor_state.State) {
    // Plugin panel state will be added to UI_State
}

// Draw plugin management panel
draw_plugin_panel :: proc(editor_state: ^editor_state.State) {
    if !editor_state.ui_state.plugin_panel_visible {
        return
    }
    
    panel_rect := rl.Rectangle{10, 100, 350, 250}
    rl.DrawRectangleRec(panel_rect, {40, 40, 40, 240})
    rl.DrawRectangleLinesEx(panel_rect, 2, rl.WHITE)
    
    // Panel title
    title_y := panel_rect.y + 10
    rl.DrawText(cstring("Plugin Manager (P to close)"), i32(panel_rect.x + 10), i32(title_y), 18, rl.WHITE)
    
    y_offset := panel_rect.y + 40
    for &plugin in registered_plugins {
        if y_offset > panel_rect.y + panel_rect.height - 30 {
            break  // Don't overflow panel
        }
        
        // Checkbox for enable/disable
        checkbox_rect := rl.Rectangle{panel_rect.x + 10, y_offset, 20, 20}
        
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), checkbox_rect) {
            if rl.IsMouseButtonPressed(.LEFT) {
                plugin.state.enabled = !plugin.state.enabled
                fmt.printf("Plugin %s: %s\n", plugin.name, plugin.state.enabled ? "enabled" : "disabled")
            }
        }
        
        // Draw checkbox
        color := plugin.state.enabled ? rl.GREEN : rl.RED
        rl.DrawRectangleRec(checkbox_rect, color)
        rl.DrawRectangleLinesEx(checkbox_rect, 1, rl.WHITE)
        
        // Plugin name and status
        status_text := plugin.state.initialized ? (plugin.state.enabled ? "ON" : "OFF") : "FAILED"
        plugin_text := fmt.ctprintf("%s (%s)", plugin.name, status_text)
        rl.DrawText(plugin_text, i32(checkbox_rect.x + 30), i32(y_offset + 2), 16, rl.WHITE)
        
        y_offset += 30
    }
    
    // Instructions
    instruction_text := fmt.ctprintf("Click checkbox to enable/disable plugins")
    rl.DrawText(instruction_text, i32(panel_rect.x + 10), i32(panel_rect.y + panel_rect.height - 25), 12, rl.GRAY)
}

// Plugin registration - conditionally compile based on ENABLED_PLUGINS
register_all_plugins :: proc(editor_state: ^editor_state.State) {
    fmt.println("=== Registering Plugins ===")
    
    // Register plugins based on build-time configuration
    when OBJ_IMPORT_ENABLED {
        obj_p := obj_plugin.get_plugin()
        // Convert plugin types (avoiding circular dependencies)
        plugin := Plugin{
            name = obj_p.name,
            version = obj_p.version,
            author = obj_p.author,
            init = obj_p.init,
            update = obj_p.update,
            cleanup = obj_p.cleanup,
            on_menu_item = obj_p.on_menu_item,
            on_import_format = obj_p.on_import_format,
            state = Plugin_State{
                enabled = obj_p.state.enabled,
                initialized = obj_p.state.initialized,
            },
        }
        register_plugin(plugin)
        fmt.println("✓ OBJ Import plugin registered")
    }
    
    // Future plugins would be registered here:
    // when TERRAIN_GENERATOR_ENABLED {
    //     import terrain_plugin "bundled/terrain_generator"
    //     register_plugin(terrain_generator.get_plugin()^)
    // }
    // when PERFORMANCE_TOOLS_ENABLED {
    //     import perf_plugin "bundled/performance_tools"
    //     register_plugin(perf_plugin.get_plugin()^)
    // }
    
    fmt.printf("Total plugins registered: %d\n", len(registered_plugins))
    fmt.println("=== Plugin Registration Complete ===")
}