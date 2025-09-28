package rendering

import "../editor"
import "../serialization"
import "../selection"
import "../ui"
import "../plugins"
import rl "vendor:raylib"

KEYMAP_COL_1 :: `OBJECT
- 1/2/3: Create Cube/Sphere/Cylinder
- 4/Ctrl+I: Import Model
- Delete/Ctrl+C: Delete
- Ctrl+D: Duplicate
- Ctrl+A: Cycle Objects
- Esc: Deselect`

KEYMAP_COL_2 :: `GIZMO
- Q: Hide Gizmo
- W: Translate
- R: Rotate
- E: Scale
- T: Transform
- X/Y/Z: Constrain Axis
- Shift or Ctrl +X/Y/Z: Contraint Modifiers
- G: Toggle Grid Snap`

KEYMAP_COL_3 :: `CAMERA
- RMB+WASD: Fly
- RMB+EQ: Fly Up/Down
- RMB+Mouse: Look
- MMB: Orbit
- Shift+MMB: Pan
- Wheel: Zoom`

KEYMAP_COL_4 :: `UI / FILE
- H: Toggle Hierarchy
- I: Toggle Inspector
- P: Toggle Plugins
- M: Toggle Controls
- Ctrl+N: New Scene
- Ctrl+O: Open Scene
- Ctrl+S: Save Scene`

KEYMAP_COL_5 :: `Property Inspector
- Left/Right Arrows: Navigate Properties
- Up/Down Arrow: Increase/Decrease Value
- Shift + Up/Down Arrow: Small Step Modifier
- Ctrl + Up/Down Arrow: Large Step Modifier
- Enter: Keyboard Edit Mode and Confirm`

draw_keymap_panel :: proc(ui_state: ^ui.UI_State, font: rl.Font) {
    // Hint text is always drawn, but panel is conditional
    

    if ui_state.keymap_visible {
        // Panel settings
        panel_height := f32(192)
        panel_y := f32(rl.GetScreenHeight()) - panel_height - 20 // A bit above the hint
        
        left_bound := ui.is_hierarchy_visible() ? ui.get_hierarchy_width() : 0
        right_bound := ui_state.right_panel.visible ? ui_state.right_panel.panel_rect.x : f32(rl.GetScreenWidth())
        
        panel_x := left_bound + 20
        panel_width := right_bound - left_bound - 40

        background_color := rl.Color{17, 26, 40, 200}
        text_color := rl.Color{67, 176, 188, 255}
        
        // Draw background
        rl.DrawRectangle(i32(panel_x), i32(panel_y), i32(panel_width), i32(panel_height), background_color)
        rl.DrawRectangleLines(i32(panel_x), i32(panel_y), i32(panel_width), i32(panel_height), {100, 100, 100, 255})

        // Draw text in columns
        col_width := panel_width / 5
        text_y := panel_y + 10
        
        ui.draw_text(.REGULAR, KEYMAP_COL_1, {panel_x + 10, text_y}, text_color)
        ui.draw_text(.REGULAR, KEYMAP_COL_2, {panel_x + col_width, text_y}, text_color)
        ui.draw_text(.REGULAR, KEYMAP_COL_3, {panel_x + col_width * 2, text_y}, text_color)
        ui.draw_text(.REGULAR, KEYMAP_COL_4, {panel_x + col_width * 3, text_y}, text_color)
        ui.draw_text(.REGULAR, KEYMAP_COL_5, {panel_x + col_width * 4, text_y}, text_color)
    }
}

render_ui :: proc(editor_state: ^editor.State) {
    // Draw menu bar at top
    ui.draw_menu_bar(&editor_state.ui_state)
    
    // Get menu bar height for layout adjustment
    menu_height := ui.get_menu_bar_height()
    
    // Draw hierarchy panel (left side)
    ui.draw_hierarchy(&editor_state.ui_state, 
                     &editor_state.selection_state,
                     &editor_state.scene,
                     &editor_state.camera_state)
    
    // Draw the right panel (environment and inspector)
    env_changed, inspector_changed := ui.draw_right_panel(&editor_state.ui_state, 
                                                    &editor_state.selection_state, 
                                                    &editor_state.scene, 
                                                    &editor_state.environment, 
                                                    &editor_state.camera_state)
    
    // Mark scene as unsaved if either panel made changes
    if env_changed || inspector_changed {
        serialization.mark_unsaved()
    }
    
    // Center branding in the middle of the window, regardless of panels
    screen_width := f32(rl.GetScreenWidth())
    left_bound := ui.is_hierarchy_visible() ? ui.get_hierarchy_width() : 0
    right_bound := editor_state.ui_state.right_panel.visible ? editor_state.ui_state.right_panel.panel_rect.x : screen_width
    available_width := right_bound - left_bound
    brand_width :: 480
    brand_x := left_bound + (available_width - brand_width) / 2
    
    ui.draw_text(.LOGO, "0", {brand_x-25, menu_height + 20}, rl.Color{112, 29, 35, 255})

    ui.draw_text(.TITLE, "Midgard 3D Editor", {brand_x + 52, menu_height + 30}, rl.Color{112, 29, 35, 255})

    ui.draw_text(.TITLE, "in Odin with Raylib", {brand_x + 120, menu_height + 72}, rl.Color{198, 132, 109, 255})

    
    
    // Draw the new keymap panel
    draw_keymap_panel(&editor_state.ui_state, ui.get_font(.REGULAR))

    // Draw file dialog on top of everything
    serialization.draw_file_dialog()

    // Draw menu dropdowns last to ensure they appear on top
    ui.draw_menu_dropdowns(&editor_state.ui_state)
    
    // Draw plugin panel if visible
    plugins.draw_plugin_panel(editor_state)
    
    // Draw import status overlay (render last so it's on top)
    ui.draw_import_status()
}