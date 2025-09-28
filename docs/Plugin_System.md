# Plugin System

## Overview

The Midgard Plugin System provides extensible functionality through build-time configurable plugins. The architecture follows handmade principles with static compilation and runtime management capabilities.

## Architecture

```
src/plugins/
├── plugins.odin                     # Core plugin system
├── bundled/                         # Bundled plugins (shipped with editor)
│   └── obj_import/                  # OBJ Import Plugin
│       ├── plugin.odin              # Plugin interface
│       ├── loader.odin              # Loading logic
│       ├── validation.odin          # Safety validation
│       └── mtl_processing.odin      # Material processing
└── community/                       # Community plugins directory
```

## Plugin Interface

```odin
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
```

## Build-Time Configuration

### Default Build (All Enabled Plugins)
```bash
odin build src -out:midgard.exe
```

### Disable Specific Plugins
```bash
# Disable OBJ import plugin
odin build src -out:midgard.exe -define:PLUGIN_OBJ_IMPORT=false

# Disable multiple plugins
odin build src -out:midgard.exe -define:PLUGIN_OBJ_IMPORT=false -define:PLUGIN_TERRAIN_GENERATOR=false

# Enable normally disabled plugins
odin build src -out:midgard.exe -define:PLUGIN_PERFORMANCE_TOOLS=true
```

### Plugin Configuration Constants
```odin
OBJ_IMPORT_ENABLED :: #config(PLUGIN_OBJ_IMPORT, true)           // Default: enabled
TERRAIN_GENERATOR_ENABLED :: #config(PLUGIN_TERRAIN_GENERATOR, false)  // Default: disabled  
PERFORMANCE_TOOLS_ENABLED :: #config(PLUGIN_PERFORMANCE_TOOLS, false)  // Default: disabled
```

## Runtime Management

- **P Key**: Toggle plugin panel
- **Plugin Panel**: Enable/disable individual plugins
- **Visual Status**: Green=enabled, Red=disabled, "FAILED"=initialization error

## Creating Plugins

### 1. Directory Structure
Create plugin directory under `plugins/bundled/your_plugin/`

### 2. Plugin Interface
```odin
package your_plugin

// Local plugin types (avoid circular dependencies)
Plugin_State :: struct {
    enabled: bool,
    initialized: bool,
}

Plugin :: struct {
    // ... (copy interface from existing plugins)
}

plugin_info := Plugin{
    name = "Your Plugin Name",
    version = "1.0.0", 
    author = "Your Name",
    init = plugin_init,
    cleanup = plugin_cleanup,
    // Optional callbacks...
}

@export
get_plugin :: proc() -> ^Plugin {
    return &plugin_info
}
```

### 3. Registration
Add to `plugins/plugins.odin`:
```odin
// Import
import your_plugin "./bundled/your_plugin"

// Configuration
YOUR_PLUGIN_ENABLED :: true

// Registration
when YOUR_PLUGIN_ENABLED {
    your_p := your_plugin.get_plugin()
    plugin := Plugin{ /* convert types */ }
    register_plugin(plugin)
}
```

## Import Format Plugins

Plugins can handle custom file formats via `on_import_format` callback:

```odin
handle_import :: proc(filepath: string) -> (model: rl.Model, success: bool) {
    if !strings.has_suffix(strings.to_lower(filepath), ".your_format") {
        return {}, false  // Not our format
    }
    
    // Load your format
    return load_your_format(filepath)
}
```

## Lifecycle

1. **Build-time**: Plugins conditionally compiled based on configuration
2. **Startup**: `register_all_plugins()` → `init_all_plugins()`
3. **Runtime**: `update_plugins()` called per frame
4. **Shutdown**: `cleanup_plugins()` called on exit

## Best Practices

- **Isolated Directories**: Each plugin in own directory
- **Local Types**: Avoid circular dependencies with local type definitions
- **Error Handling**: Return false from init on failure
- **File Extensions**: Check file extensions in import handlers
- **Documentation**: Document plugin functionality and usage

## Debugging

- Plugin initialization status shown in console
- Plugin panel shows real-time enable/disable state
- Failed plugins marked as "FAILED" in UI
- Build-time configuration prevents compilation of disabled plugins

## Examples

See `plugins/bundled/obj_import/` for complete working example implementing OBJ file import with MTL material processing and safety validation.