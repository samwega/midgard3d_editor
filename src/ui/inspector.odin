package ui

import "../scene"
import "../selection"
import "../core"
import "../resources"
import "../camera"
import "core:fmt"
import "core:strings"
import "core:path/filepath"
import rl "vendor:raylib"

// Inspector panel state
Inspector_Panel_State :: struct {
    // Cached object info to detect changes
    cached_object_id: int,
    cached_transform: core.Transform,
    cached_name: string,
    
    // Edit state
    name_being_edited: bool,
    name_edit_buffer: [128]u8,
    name_edit_length: int,
    
    // Undo/redo for transform changes (simple version)
    has_unsaved_changes: bool,
}

inspector_panel_state: Inspector_Panel_State

// Draw the inspector panel content
draw_inspector_content :: proc(layout: ^Layout_Context, ui_state: ^UI_State, selection_state: ^selection.State, scene_data: ^scene.Scene, camera_state: ^camera.State) -> bool {
    
    // Get selected object
    selected_object := selection.get_selected_object(selection_state, scene_data)
    
    // Inspector panel header
    header_rect := next_widget_rect_height(layout, 40)
    draw_section_header("Inspector", header_rect)
    
    changes_made := false
    
    if selected_object == nil {
        // No selection - show placeholder
        draw_no_selection_message(layout)
    } else {
        // Show object inspector
        if draw_object_inspector(ui_state, layout, selected_object) {
            changes_made = true
            inspector_panel_state.has_unsaved_changes = true
        }
    }
    
    return changes_made
}

// Draw message when no object is selected
draw_no_selection_message :: proc(layout: ^Layout_Context) {
    rect := next_widget_rect_height(layout, 60)
    
    message := "No Object Selected"
    sub_message := "Select an object in the scene\nto view its properties"
    
    // Main message - using regular font instead of title font
    text_width := measure_text(.REGULAR, strings.clone_to_cstring(message, context.temp_allocator)).x
    text_pos := rl.Vector2{
        rect.x + (rect.width - text_width) / 2,
        rect.y + 10,
    }
    draw_text(.REGULAR, strings.clone_to_cstring(message, context.temp_allocator), text_pos, UI_COLORS.TEXT_MUTED)
    
    // Sub message
    lines := strings.split(sub_message, "\n", context.temp_allocator)
    for line, i in lines {
        line_width := measure_text(.SMALL, strings.clone_to_cstring(line, context.temp_allocator)).x
        line_pos := rl.Vector2{
            rect.x + (rect.width - line_width) / 2,
            rect.y + 35 + f32(i * 20),
        }
        draw_text(.SMALL, strings.clone_to_cstring(line, context.temp_allocator), line_pos, UI_COLORS.TEXT_MUTED)
    }
}

// Draw the object inspector interface
draw_object_inspector :: proc(ui_state: ^UI_State, layout: ^Layout_Context, object: ^scene.Scene_Object) -> bool {
    changes_made := false
    
    // Object header section
    header_rect := next_widget_rect_height(layout, 25)
    draw_subsection_header("Object Properties", header_rect)
    
    // Object ID (read-only)
    id_rect := next_widget_rect(layout)
    label_rect := rl.Rectangle{id_rect.x, id_rect.y, id_rect.width * 0.4, id_rect.height}
    value_rect := rl.Rectangle{id_rect.x + label_rect.width + 4, id_rect.y, id_rect.width * 0.6 - 4, id_rect.height}
    
    draw_label("ID:", label_rect)
    id_text := fmt.tprintf("%d", object.id)
    defer delete(id_text, context.temp_allocator)
    draw_label(id_text, value_rect, UI_COLORS.TEXT_MUTED)
    
    // Object name (editable in future - for now just display)
    name_rect := next_widget_rect(layout)
    name_label_rect := rl.Rectangle{name_rect.x, name_rect.y, name_rect.width * 0.4, name_rect.height}
    name_value_rect := rl.Rectangle{name_rect.x + name_label_rect.width + 4, name_rect.y, name_rect.width * 0.6 - 4, name_rect.height}
    
    draw_label("Name:", name_label_rect)
    rl.DrawRectangleRec(name_value_rect, UI_COLORS.INPUT_BG)
    rl.DrawRectangleLinesEx(name_value_rect, 1, UI_COLORS.BORDER)
    draw_label(object.name, name_value_rect)
    
    // Object type (read-only)
    type_rect := next_widget_rect(layout)
    type_label_rect := rl.Rectangle{type_rect.x, type_rect.y, type_rect.width * 0.4, type_rect.height}
    type_value_rect := rl.Rectangle{type_rect.x + type_label_rect.width + 4, type_rect.y, type_rect.width * 0.6 - 4, type_rect.height}
    
    draw_label("Type:", type_label_rect)
    object_type_display(int(object.object_type), type_value_rect)
    
    // Spacing before transform
    next_widget_rect(layout)
    
    // Transform section header
    transform_header_rect := next_widget_rect_height(layout, 25)
    draw_subsection_header("Transform", transform_header_rect)
    
    // Position (taller widget to accommodate X/Y/Z labels)
    pos_rect := next_widget_rect_height(layout, 42)
    pos_label_rect := rl.Rectangle{pos_rect.x, pos_rect.y + 10, pos_rect.width * 0.25, pos_rect.height - 10}
    pos_value_rect := rl.Rectangle{pos_rect.x + pos_label_rect.width + 4, pos_rect.y, pos_rect.width * 0.75 - 4, pos_rect.height}
    
    draw_label("Position:", pos_label_rect)
    if vector3_input(ui_state, &object.transform.position, pos_value_rect, get_font(.REGULAR)) == Widget_Result.CHANGED {
        changes_made = true
    }
    
    // Rotation (taller widget to accommodate X/Y/Z labels)
    rot_rect := next_widget_rect_height(layout, 42)
    rot_label_rect := rl.Rectangle{rot_rect.x, rot_rect.y + 10, rot_rect.width * 0.25, rot_rect.height - 10}
    rot_value_rect := rl.Rectangle{rot_rect.x + rot_label_rect.width + 4, rot_rect.y, rot_rect.width * 0.75 - 4, rot_rect.height}
    
    draw_label("Rotation:", rot_label_rect)
    if vector3_input(ui_state, &object.transform.rotation, rot_value_rect, get_font(.REGULAR)) == Widget_Result.CHANGED {
        changes_made = true
    }
    
    // Scale (taller widget to accommodate X/Y/Z labels)
    scale_rect := next_widget_rect_height(layout, 42)
    scale_label_rect := rl.Rectangle{scale_rect.x, scale_rect.y + 10, scale_rect.width * 0.25, scale_rect.height - 10}
    scale_value_rect := rl.Rectangle{scale_rect.x + scale_label_rect.width + 4, scale_rect.y, scale_rect.width * 0.75 - 4, scale_rect.height}
    
    draw_label("Scale:", scale_label_rect)
    if vector3_input(ui_state, &object.transform.scale, scale_value_rect, get_font(.REGULAR)) == Widget_Result.CHANGED {
        changes_made = true
    }
    
    // Spacing before color
    next_widget_rect(layout)
    
    // Appearance section header
    appearance_header_rect := next_widget_rect_height(layout, 25)
    draw_subsection_header("Appearance", appearance_header_rect)
    
    // Color display
    color_rect := next_widget_rect(layout)
    color_label_rect := rl.Rectangle{color_rect.x, color_rect.y, color_rect.width * 0.4, color_rect.height}
    color_value_rect := rl.Rectangle{color_rect.x + color_label_rect.width + 4, color_rect.y, color_rect.width * 0.6 - 4, color_rect.height}
    
    draw_label("Color:", color_label_rect)
    color_display(object.color, color_value_rect)
    
    // RGBA input widget
    rgba_rect := next_widget_rect_height(layout, 42)
    if rgba_input(ui_state, &object.color, rgba_rect, get_font(.REGULAR)) == Widget_Result.CHANGED {
        changes_made = true
    }
    
    return changes_made
}

// Handle inspector input (like keyboard shortcuts)
// Returns true if inspector visibility was toggled
handle_inspector_input :: proc(ui_state: ^UI_State) -> bool {
    // Toggle inspector visibility with 'I' key (but not when Ctrl+I is pressed for import)
    if rl.IsKeyPressed(rl.KeyboardKey.I) && !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
        toggle_right_panel(ui_state)
        return true
    }
    return false
}

// Note: should_block_scene_input moved to ui_state.odin for centralized logic

// Reset cached state (call when selection changes)
reset_inspector_cache :: proc() {
    inspector_panel_state.cached_object_id = -1
    inspector_panel_state.has_unsaved_changes = false
}

// Global variables for UI requests (to be handled by main editor)
hdri_dialog_requested := false
hdri_clear_requested := false

request_hdri_dialog :: proc() {
    hdri_dialog_requested = true
}

request_hdri_clear :: proc() {
    hdri_clear_requested = true
}

// Check and reset request flags (called by main editor)
check_hdri_dialog_request :: proc() -> bool {
    if hdri_dialog_requested {
        hdri_dialog_requested = false
        return true
    }
    return false
}

check_hdri_clear_request :: proc() -> bool {
    if hdri_clear_requested {
        hdri_clear_requested = false
        return true
    }
    return false
}
