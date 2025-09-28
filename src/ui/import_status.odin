package ui

import "../model_import"
import rl "vendor:raylib"
import "core:strings"
import "core:fmt"

// Import status display
Import_Status_State :: struct {
    visible: bool,
    import_report: string,
    display_timer: f32,
    display_duration: f32,
}

import_status_state: Import_Status_State

// Show import status
show_import_status :: proc(filepath: string, model: rl.Model) {
    import_status_state.visible = true
    import_status_state.import_report = model_import.generate_import_report(filepath, model)
    import_status_state.display_timer = 0
    import_status_state.display_duration = 5.0  // Show for 5 seconds
}

// Show import error
show_import_error :: proc(filepath: string, error_message: string) {
    import_status_state.visible = true
    import_status_state.import_report = fmt.aprintf("=== Import Error ===\nFile: %s\nError: %s\n\n=== End Report ===", 
                                                    filepath, error_message)
    import_status_state.display_timer = 0
    import_status_state.display_duration = 5.0  // Show for 5 seconds
}

// Update import status
update_import_status :: proc() {
    if import_status_state.visible {
        import_status_state.display_timer += rl.GetFrameTime()
        
        if import_status_state.display_timer >= import_status_state.display_duration {
            import_status_state.visible = false
            if import_status_state.import_report != "" {
                delete(import_status_state.import_report)
                import_status_state.import_report = ""
            }
        }
    }
}

// Draw import status overlay
draw_import_status :: proc() {
    if !import_status_state.visible || import_status_state.import_report == "" {
        return
    }
    
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())
    
    // Status panel dimensions
    panel_width := f32(400)
    panel_height := f32(300)
    panel_x := screen_width - panel_width - 20
    panel_y := f32(60)  // Below menu bar
    
    // Draw semi-transparent background
    rl.DrawRectangle(i32(panel_x), i32(panel_y), i32(panel_width), i32(panel_height), 
                    rl.Color{0, 0, 0, 180})
    rl.DrawRectangleLines(i32(panel_x), i32(panel_y), i32(panel_width), i32(panel_height), 
                         rl.Color{100, 100, 100, 255})
    
    // Draw report text
    lines := strings.split(import_status_state.import_report, "\n", context.temp_allocator)
    y_offset := panel_y + 10
    
    for line in lines {
        if y_offset > panel_y + panel_height - 20 {
            break  // Don't overflow panel
        }
        
        font_size := get_font_size(.SMALL)
        color := rl.WHITE
        
        // Use different colors for different line types
        if strings.contains(line, "===") {
            font_size = get_font_size(.HEADER)
            color = rl.YELLOW
            draw_text(.HEADER, strings.clone_to_cstring(line, context.temp_allocator),
                         {panel_x + 10, y_offset}, color)
        } else if strings.contains(line, "Warning") || strings.has_prefix(line, "- Missing") {
            color = rl.ORANGE
            draw_text(.SMALL, strings.clone_to_cstring(line, context.temp_allocator),
                         {panel_x + 10, y_offset}, color)
        } else if strings.contains(line, "Error") {
            color = rl.RED
            draw_text(.SMALL, strings.clone_to_cstring(line, context.temp_allocator),
                         {panel_x + 10, y_offset}, color)
        } else {
            draw_text(.SMALL, strings.clone_to_cstring(line, context.temp_allocator),
                         {panel_x + 10, y_offset}, color)
        }
        
        y_offset += font_size + 2
    }
    
    // Draw fade timer
    fade_progress := import_status_state.display_timer / import_status_state.display_duration
    timer_width := panel_width * (1.0 - fade_progress)
    rl.DrawRectangle(i32(panel_x), i32(panel_y + panel_height - 3), i32(timer_width), 3, rl.GREEN)
}