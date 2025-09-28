package ui

import "../resources"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

// Draw environment panel content
draw_environment_content :: proc(layout: ^Layout_Context, ui_state: ^UI_State, env: ^resources.Environment_State) -> bool {
    
    changes_made := false
    
    // Environment panel header
    header_rect := next_widget_rect_height(layout, 40)
    draw_section_header("Environment", header_rect)
    
    // Grid controls
    grid_rect := next_widget_rect(layout)
    if draw_checkbox("Grid Visible", &env.grid_visible, grid_rect) {
        changes_made = true
    }

    // Sky Color with preview
    sky_color_rect := next_widget_rect(layout)
    sky_color_label_rect := rl.Rectangle{sky_color_rect.x, sky_color_rect.y, sky_color_rect.width * 0.4, sky_color_rect.height}
    sky_color_value_rect := rl.Rectangle{sky_color_rect.x + sky_color_label_rect.width + 4, sky_color_rect.y, sky_color_rect.width * 0.6 - 4, sky_color_rect.height}
    
    draw_label("Sky Color:", sky_color_label_rect)
    color_display(env.sky_color, sky_color_value_rect)

    // RGB input on a new line
    sky_color_input_rect := next_widget_rect_height(layout, 42)
    if rgb_input(ui_state, &env.sky_color, sky_color_input_rect, get_font(.REGULAR)) == .CHANGED {
        changes_made = true
    }
    
    // Spacing before skybox section
    next_widget_rect(layout)
    
    // Skybox section
    skybox_header_rect := next_widget_rect_height(layout, 25)
    draw_subsection_header("Skybox", skybox_header_rect)
    
    // Only show skybox name if HDRI is loaded
    if env.enabled {
        // Current HDRI display
        info_rect := next_widget_rect(layout)
        current_text := filepath.base(env.source_path)
        draw_label(current_text, info_rect)
    }
    
    // Load HDRI button
    load_button_rect := next_widget_rect(layout)
    if draw_button("Load Skybox Image", load_button_rect) {
        request_hdri_dialog()
    }
    
    // Skybox controls (only show if HDRI loaded)
    if env.enabled {
        // Clear button (only clears skybox)
        clear_button_rect := next_widget_rect(layout)
        if draw_button("Clear Skybox", clear_button_rect) {
            request_hdri_clear()
        }
        
        // Skybox visibility toggle
        visibility_rect := next_widget_rect(layout)
        if draw_checkbox("Skybox Visible", &env.background_visible, visibility_rect) {
            changes_made = true
        }
        
        // Rotation control
        rotation_rect := next_widget_rect(layout)
        if draw_slider(ui_state, "Rotation", &env.rotation_y, 0.0, 360.0, rotation_rect) {
            changes_made = true
        }
        
        // Exposure control
        exposure_rect := next_widget_rect(layout)
        if draw_slider(ui_state, "Exposure (EV)", &env.exposure, -4.0, 4.0, exposure_rect) {
            changes_made = true
        }
        
        // Intensity control
        intensity_rect := next_widget_rect(layout)
        if draw_slider(ui_state, "Intensity", &env.intensity, 0.0, 2.0, intensity_rect) {
            changes_made = true
        }
    }
    
    return changes_made
}