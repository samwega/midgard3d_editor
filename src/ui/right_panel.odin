package ui

import "../scene"
import "../selection"
// import "../core"
import "../resources"
import "../camera"
// import "core:fmt"
// import "core:strings"
import rl "vendor:raylib"

// Draw the entire right panel, including environment and inspector sections
draw_right_panel :: proc(ui_state: ^UI_State, selection_state: ^selection.State, scene_data: ^scene.Scene, env: ^resources.Environment_State, camera_state: ^camera.State) -> (env_changed: bool, inspector_changed: bool) {
    if !ui_state.right_panel.visible {
        return false, false
    }
    
    // Draw panel background
    rl.DrawRectangleRec(ui_state.right_panel.panel_rect, UI_COLORS.BACKGROUND)
    rl.DrawRectangleLinesEx(ui_state.right_panel.panel_rect, 1, UI_COLORS.BORDER)
    
    // Initialize layout for the entire right panel
    layout := Layout_Context{
        current_rect = rl.Rectangle{
            x = ui_state.right_panel.panel_rect.x + ui_state.panel_padding,
            y = ui_state.right_panel.panel_rect.y + ui_state.panel_padding - ui_state.right_panel.scroll_offset,
            width = ui_state.right_panel.panel_rect.width - (ui_state.panel_padding * 2),
            height = ui_state.widget_height,
        },
        y_offset = ui_state.right_panel.panel_rect.y + ui_state.panel_padding - ui_state.right_panel.scroll_offset,
        available_width = ui_state.right_panel.panel_rect.width - (ui_state.panel_padding * 2),
        widget_height = ui_state.widget_height,
        spacing = ui_state.spacing,
    }
    
    // --- Draw Environment Section ---
    env_result := draw_environment_content(&layout, ui_state, env)
    
    // --- Draw Inspector Section ---
    inspector_result := draw_inspector_content(&layout, ui_state, selection_state, scene_data, camera_state)

    // Update content height for scrolling
    ui_state.right_panel.content_height = layout.y_offset + ui_state.panel_padding
    
    // Handle scrolling for the entire panel
    mouse_pos := rl.GetMousePosition()
    if rl.CheckCollisionPointRec(mouse_pos, ui_state.right_panel.panel_rect) {
        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            ui_state.right_panel.scroll_offset -= wheel * 30
            
            // Clamp scroll
            max_scroll := ui_state.right_panel.content_height - ui_state.right_panel.panel_rect.height + ui_state.panel_padding
            if max_scroll > 0 {
                ui_state.right_panel.scroll_offset = clamp(ui_state.right_panel.scroll_offset, 0, max_scroll)
            } else {
                ui_state.right_panel.scroll_offset = 0
            }
        }
    }
    
    return env_result, inspector_result
}
