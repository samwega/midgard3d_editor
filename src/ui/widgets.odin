package ui

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"


// Widget result for interaction feedback
Widget_Result :: enum {
    NONE,
    CLICKED,
    CHANGED,
    HOVERED,
}

// Layout helper for widgets
Layout_Context :: struct {
    current_rect: rl.Rectangle,
    y_offset: f32,
    available_width: f32,
    widget_height: f32,
    spacing: f32,
}



next_widget_rect :: proc(layout: ^Layout_Context) -> rl.Rectangle {
    rect := layout.current_rect
    layout.current_rect.y += layout.widget_height + layout.spacing
    layout.y_offset += layout.widget_height + layout.spacing
    return rect
}

next_widget_rect_height :: proc(layout: ^Layout_Context, height: f32) -> rl.Rectangle {
    rect := layout.current_rect
    rect.height = height
    layout.current_rect.y += height + layout.spacing
    layout.y_offset += height + layout.spacing
    return rect
}

// Basic label widget
draw_label :: proc(text: string, rect: rl.Rectangle, color: rl.Color = UI_COLORS.TEXT) {
    text_width := measure_text(.REGULAR, strings.clone_to_cstring(text, context.temp_allocator)).x
    text_pos := rl.Vector2{
        rect.x + 4,
        rect.y + (rect.height - get_font_size(.REGULAR)) / 2,
    }
    draw_text(.REGULAR, strings.clone_to_cstring(text, context.temp_allocator), text_pos, color)
}

// Main section header widget (for Environment, Inspector, Scene Hierarchy)
draw_section_header :: proc(text: string, rect: rl.Rectangle) {
    // Draw background
    rl.DrawRectangleRec(rect, UI_COLORS.SECONDARY)
    rl.DrawRectangleLinesEx(rect, 1, UI_COLORS.SELECTION)
    
    // Draw text centered both horizontally and vertically
    text_width := measure_text(.HEADER, strings.clone_to_cstring(text, context.temp_allocator)).x
    text_pos := rl.Vector2{
        rect.x + (rect.width - text_width) / 2,  // Center horizontally
        rect.y + (rect.height - get_font_size(.HEADER)) / 2,  // Center vertically
    }
    draw_text(.HEADER, strings.clone_to_cstring(text, context.temp_allocator), text_pos, UI_COLORS.TEXT)
}

// Subsection header widget (for Skybox, Object Properties, Transform, Appearance)
draw_subsection_header :: proc(text: string, rect: rl.Rectangle) {
    // No background for subsections - just text with subtle styling
    
    // Draw text left-aligned with slight padding
    text_pos := rl.Vector2{
        rect.x + 8,  // Left padding
        rect.y + (rect.height - get_font_size(.REGULAR)) / 2,  // Center vertically
    }
    draw_text(.REGULAR, strings.clone_to_cstring(text, context.temp_allocator), text_pos, UI_COLORS.TEXT_MUTED)
}

// Float input widget - returns true if value changed
// display_as_integer: if true, displays value as integer without decimal places
float_input :: proc(ui_state: ^UI_State, value: ^f32, rect: rl.Rectangle, font_18: rl.Font, min_val: f32 = -1000, max_val: f32 = 1000, step: f32 = 0.1, display_as_integer: bool = false) -> Widget_Result {
    widget_id := generate_widget_id(ui_state)
    mouse_pos := rl.GetMousePosition()
    is_over := rl.CheckCollisionPointRec(mouse_pos, rect)
    is_active := ui_state.active_widget == widget_id
    result := Widget_Result.NONE
    
    // Update hot widget
    if is_over {
        ui_state.hot_widget = widget_id
        result = Widget_Result.HOVERED
    }
    
    // Handle clicking to make active
    if is_over && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        ui_state.active_widget = widget_id
    }
    
    // Handle scroll wheel for fine adjustment when hovered
    if is_over {
        wheel_move := rl.GetMouseWheelMove()
        if wheel_move != 0 {
            old_value := value^
            value^ += wheel_move * step
            value^ = clamp(value^, min_val, max_val)
            if value^ != old_value {
                result = Widget_Result.CHANGED
            }
        }
    }
    
    // Handle keyboard input when active
    if is_active {
        key_step := step
        
        // Fine adjustment with Shift
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) || rl.IsKeyDown(rl.KeyboardKey.RIGHT_SHIFT) {
            key_step *= 0.1
        }
        
        // Coarse adjustment with Ctrl
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) || rl.IsKeyDown(rl.KeyboardKey.RIGHT_CONTROL) {
            key_step *= 10
        }
        
        old_value := value^
        
        // Up/Down arrow keys adjust values
        if rl.IsKeyPressed(rl.KeyboardKey.UP) {
            value^ += key_step
        }
        if rl.IsKeyPressed(rl.KeyboardKey.DOWN) {
            value^ -= key_step
        }
        
        // Navigation is handled in ui_state.handle_navigation_input()
        // This keeps widgets focused only on their specific functionality
        
        // Clamp and check for changes
        value^ = clamp(value^, min_val, max_val)
        if value^ != old_value {
            result = Widget_Result.CHANGED
        }
    }
    
    // Draw background
    bg_color := is_active ? UI_COLORS.SELECTION : UI_COLORS.INPUT_BG
    rl.DrawRectangleRec(rect, bg_color)
    rl.DrawRectangleLinesEx(rect, 1, is_over ? UI_COLORS.HOVER : UI_COLORS.BORDER)
    
    // Draw value text
    value_text := display_as_integer ? fmt.tprintf("%.0f", value^) : fmt.tprintf("%.2f", value^)
    defer delete(value_text, context.temp_allocator)
    
    font_size := get_font_size(.REGULAR)
    text_pos := rl.Vector2{
        rect.x + 4,
        rect.y + (rect.height - font_size) / 2,
    }
    draw_text(.REGULAR, strings.clone_to_cstring(value_text, context.temp_allocator), text_pos, UI_COLORS.TEXT)
    
    return result
}

// Vector3 input widget - shows X, Y, Z inputs horizontally
vector3_input :: proc(ui_state: ^UI_State, value: ^rl.Vector3, rect: rl.Rectangle, font: rl.Font) -> Widget_Result {
    labels: [3]string = {"X", "Y", "Z"}
    result := Widget_Result.NONE
    
    field_width := (rect.width - 8) / 3  // -8 for spacing, 3 fields
    label_height := f32(16)
    
    // X component
    x_rect := rl.Rectangle{rect.x, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    x_label_rect := rl.Rectangle{rect.x, rect.y, field_width, label_height}
    
    draw_label(labels[0], x_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &value.x, x_rect, font, -1000, 1000, 0.1, false) == Widget_Result.CHANGED {
        result = Widget_Result.CHANGED
    }
    
    // Y component
    y_rect := rl.Rectangle{rect.x + field_width + 4, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    y_label_rect := rl.Rectangle{rect.x + field_width + 4, rect.y, field_width, label_height}
    
    draw_label(labels[1], y_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &value.y, y_rect, font, -1000, 1000, 0.1, false) == Widget_Result.CHANGED {
        result = Widget_Result.CHANGED
    }
    
    // Z component
    z_rect := rl.Rectangle{rect.x + (field_width + 4) * 2, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    z_label_rect := rl.Rectangle{rect.x + (field_width + 4) * 2, rect.y, field_width, label_height}
    
    draw_label(labels[2], z_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &value.z, z_rect, font, -1000, 1000, 0.1, false) == Widget_Result.CHANGED {
        result = Widget_Result.CHANGED
    }
    
    return result
}

// Color picker widget - shows a checkerboard for alpha
color_display :: proc(color: rl.Color, rect: rl.Rectangle) {
    // Draw checkerboard background
    rl.DrawRectangleRec(rect, UI_COLORS.BACKGROUND)
    check_size := 5
    num_checks_x := int(rect.width) / check_size
    num_checks_y := int(rect.height) / check_size
    for y in 0..<num_checks_y {
        for x in 0..<num_checks_x {
            if (x + y) % 2 == 0 {
                check_rect := rl.Rectangle{rect.x + f32(x * check_size), rect.y + f32(y * check_size), f32(check_size), f32(check_size)}
                rl.DrawRectangleRec(check_rect, {200, 200, 200, 255})
            } else {
                check_rect := rl.Rectangle{rect.x + f32(x * check_size), rect.y + f32(y * check_size), f32(check_size), f32(check_size)}
                rl.DrawRectangleRec(check_rect, {150, 150, 150, 255})
            }
        }
    }

    // Draw the actual color with its alpha on top
    rl.DrawRectangleRec(rect, color)
    rl.DrawRectangleLinesEx(rect, 2, UI_COLORS.BORDER)
}


// Helper function to clamp integer values
clamp_int :: proc(value: int, min_val: int, max_val: int) -> int {
    if value < min_val {
        return min_val
    }
    if value > max_val {
        return max_val
    }
    return value
}

// RGB input widget - shows R, G, B inputs horizontally (no alpha)
rgb_input :: proc(ui_state: ^UI_State, color: ^rl.Color, rect: rl.Rectangle, font: rl.Font) -> Widget_Result {
    result := Widget_Result.NONE
    field_width := (rect.width - 16) / 3  // Space for 3 fields with small gaps
    label_height := f32(16)
    
    // Convert color components to floats for editing
    r_float := f32(color.r)
    g_float := f32(color.g)
    b_float := f32(color.b)

    // R component
    r_rect := rl.Rectangle{rect.x, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    r_label_rect := rl.Rectangle{rect.x, rect.y, field_width, label_height}
    
    draw_label("R", r_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &r_float, r_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.r = u8(clamp_int(int(r_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    // G component
    g_rect := rl.Rectangle{rect.x + field_width + 8, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    g_label_rect := rl.Rectangle{rect.x + field_width + 8, rect.y, field_width, label_height}
    
    draw_label("G", g_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &g_float, g_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.g = u8(clamp_int(int(g_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    // B component
    b_rect := rl.Rectangle{rect.x + (field_width + 8) * 2, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    b_label_rect := rl.Rectangle{rect.x + (field_width + 8) * 2, rect.y, field_width, label_height}
    
    draw_label("B", b_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &b_float, b_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.b = u8(clamp_int(int(b_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    return result
}

// RGBA input widget - shows R, G, B, A inputs horizontally
rgba_input :: proc(ui_state: ^UI_State, color: ^rl.Color, rect: rl.Rectangle, font: rl.Font) -> Widget_Result {
    result := Widget_Result.NONE
    field_width := (rect.width - 24) / 4  // Space for 4 fields with small gaps
    label_height := f32(16)
    
    // Convert color components to floats for editing
    r_float := f32(color.r)
    g_float := f32(color.g)
    b_float := f32(color.b)
    a_float := f32(color.a)

    // R component
    r_rect := rl.Rectangle{rect.x, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    r_label_rect := rl.Rectangle{rect.x, rect.y, field_width, label_height}
    
    draw_label("R", r_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &r_float, r_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.r = u8(clamp_int(int(r_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    // G component
    g_rect := rl.Rectangle{rect.x + field_width + 8, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    g_label_rect := rl.Rectangle{rect.x + field_width + 8, rect.y, field_width, label_height}
    
    draw_label("G", g_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &g_float, g_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.g = u8(clamp_int(int(g_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    // B component
    b_rect := rl.Rectangle{rect.x + (field_width + 8) * 2, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    b_label_rect := rl.Rectangle{rect.x + (field_width + 8) * 2, rect.y, field_width, label_height}
    
    draw_label("B", b_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &b_float, b_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.b = u8(clamp_int(int(b_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    // A component
    a_rect := rl.Rectangle{rect.x + (field_width + 8) * 3, rect.y + label_height + 2, field_width, rect.height - label_height - 2}
    a_label_rect := rl.Rectangle{rect.x + (field_width + 8) * 3, rect.y, field_width, label_height}
    
    draw_label("A", a_label_rect, UI_COLORS.ACCENT)
    if float_input(ui_state, &a_float, a_rect, font, 0, 255, 1, true) == Widget_Result.CHANGED {
        color.a = u8(clamp_int(int(a_float), 0, 255))
        result = Widget_Result.CHANGED
    }
    
    return result
}


// Object type display widget - shows the object type name
object_type_display :: proc(object_type: int, rect: rl.Rectangle) {
    type_names := []string{
        "Cube", "Sphere", "Cylinder", "Mesh",
    }
    
    type_name := "Unknown"
    
    if object_type >= 0 && object_type < len(type_names) {
        type_name = type_names[object_type]
    }
    
    // Draw background
    rl.DrawRectangleRec(rect, UI_COLORS.INPUT_BG)
    rl.DrawRectangleLinesEx(rect, 1, UI_COLORS.BORDER)
    
    // Draw text
    draw_label(type_name, rect)
}

// Helper to draw a property row with label and value
draw_property_row :: proc(ui_state: ^UI_State, layout: ^Layout_Context, label: string, draw_value: proc()) {
    rect := next_widget_rect(layout)
    
    // Split into label and value areas
    label_width := rect.width * 0.4
    value_width := rect.width * 0.6 - 4
    
    label_rect := rl.Rectangle{rect.x, rect.y, label_width, rect.height}
    value_rect := rl.Rectangle{rect.x + label_width + 4, rect.y, value_width, rect.height}
    
    draw_label(label, label_rect)
    
    // Call the provided drawing procedure for the value
    draw_value()
}

// Button widget
draw_button :: proc(text: string, rect: rl.Rectangle) -> bool {
    mouse_pos := rl.GetMousePosition()
    is_over := rl.CheckCollisionPointRec(mouse_pos, rect)
    is_clicked := is_over && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    
    // Draw background
    bg_color := is_over ? UI_COLORS.SELECTION : UI_COLORS.HOVER // 1st color is background when hover; 2nd color is background not hovered
    rl.DrawRectangleRec(rect, bg_color)
    rl.DrawRectangleLinesEx(rect, 1, is_over ? UI_COLORS.TEXT : UI_COLORS.TEXT) //border same as background
    
    // Draw text centered
    text_width := measure_text(.REGULAR, strings.clone_to_cstring(text, context.temp_allocator)).x
    text_pos := rl.Vector2{
        rect.x + (rect.width - text_width) / 2,
        rect.y + (rect.height - get_font_size(.REGULAR)) / 2,
    }
    draw_text(.REGULAR, strings.clone_to_cstring(text, context.temp_allocator), text_pos, UI_COLORS.TEXT)
    
    return is_clicked
}

// Slider widget with proper drag handling
draw_slider :: proc(ui_state: ^UI_State, label: string, value: ^f32, min_val: f32, max_val: f32, rect: rl.Rectangle) -> bool {
    widget_id := generate_widget_id(ui_state)
    mouse_pos := rl.GetMousePosition()
    is_over := rl.CheckCollisionPointRec(mouse_pos, rect)
    is_active := ui_state.active_widget == widget_id
    changed := false
    
    // Update hot widget when hovering
    if is_over {
        ui_state.hot_widget = widget_id
    }
    
    // Handle clicking to start dragging
    if is_over && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        ui_state.active_widget = widget_id
    }
    
    // Handle dragging - continues even when mouse leaves the slider area
    if is_active && rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
        // Calculate relative position based on mouse X coordinate
        relative_pos := (mouse_pos.x - rect.x) / rect.width
        relative_pos = clamp(relative_pos, 0, 1)
        new_value := min_val + relative_pos * (max_val - min_val)
        if new_value != value^ {
            value^ = new_value
            changed = true
        }
    }
    
    // Stop dragging when mouse button is released
    if is_active && rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
        ui_state.active_widget = 0
    }
    
    // Draw track
    track_rect := rl.Rectangle{rect.x, rect.y + rect.height * 0.4, rect.width, rect.height * 0.2}
    rl.DrawRectangleRec(track_rect, UI_COLORS.INPUT_BG)
    rl.DrawRectangleLinesEx(track_rect, 1, UI_COLORS.BORDER)
    
    // Draw handle
    handle_pos := (value^ - min_val) / (max_val - min_val)
    handle_x := rect.x + handle_pos * rect.width - 4
    handle_rect := rl.Rectangle{handle_x, rect.y + rect.height * 0.3, 8, rect.height * 0.4}
    
    // Visual feedback: different colors for active, hovered, or normal state
    handle_color := UI_COLORS.TEXT
    if is_active {
        handle_color = UI_COLORS.SELECTION
    } else if is_over {
        handle_color = UI_COLORS.ACCENT
    }
    rl.DrawRectangleRec(handle_rect, handle_color)
    
    // Draw label
    label_pos := rl.Vector2{rect.x, rect.y}
    draw_text(.SMALL, strings.clone_to_cstring(label, context.temp_allocator), label_pos, UI_COLORS.TEXT)
    
    // Draw value text (right-aligned)
    value_text := fmt.tprintf("%.2f", value^)
    defer delete(value_text, context.temp_allocator)
    value_width := measure_text(.SMALL, strings.clone_to_cstring(value_text, context.temp_allocator)).x
    value_pos := rl.Vector2{rect.x + rect.width - value_width, rect.y}
    draw_text(.SMALL, strings.clone_to_cstring(value_text, context.temp_allocator), value_pos, UI_COLORS.TEXT)
    
    return changed
}

// Checkbox widget
draw_checkbox :: proc(label: string, checked: ^bool, rect: rl.Rectangle) -> bool {
    mouse_pos := rl.GetMousePosition()
    is_over := rl.CheckCollisionPointRec(mouse_pos, rect)
    is_clicked := is_over && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)
    
    if is_clicked {
        checked^ = !checked^
    }
    
    // Draw checkbox
    checkbox_rect := rl.Rectangle{rect.x, rect.y + 2, 16, 16}
    rl.DrawRectangleLinesEx(checkbox_rect, 1, UI_COLORS.ACCENT)
    
    if checked^ {
        rl.DrawRectangle(i32(checkbox_rect.x + 3), i32(checkbox_rect.y + 3), i32(checkbox_rect.width - 6), i32(checkbox_rect.height - 6), UI_COLORS.ACCENT)
    }
    
    // Draw label
    label_rect := rl.Rectangle{rect.x + 20, rect.y, rect.width - 20, rect.height}
    draw_label(label, label_rect)
    
    return is_clicked
}