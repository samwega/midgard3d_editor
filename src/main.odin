package main

import "editor"
import "rendering"
import "plugins"
import rl "vendor:raylib"

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    editor_state := editor.init()
    defer editor.cleanup(&editor_state)
    
    // Initialize plugin system after editor init
    plugins.register_all_plugins(&editor_state)
    plugins.init_all_plugins(&editor_state)
    defer plugins.cleanup_plugins(&editor_state)
    
    for !rl.WindowShouldClose() {
        editor.update(&editor_state)
        plugins.update_plugins(&editor_state, rl.GetFrameTime())
        rendering.render(&editor_state)
    }
}