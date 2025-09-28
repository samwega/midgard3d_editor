package ui

import "../scene"
import "../selection"
import "../core"
import "../camera"
import "../operations"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// Hierarchy panel state
Hierarchy_Panel_State :: struct {
    visible: bool,
    panel_rect: rl.Rectangle,
    scroll_offset: f32,
    content_height: f32,
    
    // Panel dimensions
    panel_width: f32,
    panel_x: f32,
}

hierarchy_state: Hierarchy_Panel_State

// Initialize hierarchy panel (left side of screen)
init_hierarchy :: proc() -> Hierarchy_Panel_State {
    panel_width := f32(250)
    
    return Hierarchy_Panel_State{
        visible = true,
        panel_rect = rl.Rectangle{
            x = 0,
            y = 0,
            width = panel_width,
            height = f32(rl.GetScreenHeight()),
        },
        scroll_offset = 0,
        content_height = 0,
        panel_width = panel_width,
        panel_x = 0,
    }
}

// Draw hierarchy panel
draw_hierarchy :: proc(ui_state: ^UI_State, 
                      selection_state: ^selection.State,
                      scene_data: ^scene.Scene,
                      camera_state: ^camera.State) {
    
    if !hierarchy_state.visible {
        return
    }
    
    // Draw panel background
    rl.DrawRectangleRec(hierarchy_state.panel_rect, UI_COLORS.BACKGROUND)
    rl.DrawRectangleLinesEx(hierarchy_state.panel_rect, 1, UI_COLORS.BORDER)
    
    // --- Layout --- 
    padding := f32(10)
    y_pos := padding

    // Reserve space for debug info at bottom (4 lines: 3 debug lines + padding)
    debug_info_height := f32(80)  // 3 * 20 + extra padding
    panel_content_height := hierarchy_state.panel_rect.height - padding - debug_info_height

    // Scene hierarchy header (aligned with Environment header positioning)
    header_rect := rl.Rectangle{
        x = padding,
        y = y_pos,
        width = hierarchy_state.panel_width - (padding * 2),
        height = 40,
    }
    draw_section_header("Scene Hierarchy", header_rect)
    y_pos += 45

    // Object count
    count_text := fmt.tprintf("Objects: %d", len(scene_data.objects))
    defer delete(count_text, context.temp_allocator)
    draw_text(.SMALL, strings.clone_to_cstring(count_text, context.temp_allocator), {padding, y_pos}, UI_COLORS.TEXT_MUTED)
    y_pos += 25

    // --- Object List ---
    list_y_start := y_pos
    list_y_end := hierarchy_state.panel_rect.height - debug_info_height - 15  // Stop 15px before debug area
    y_pos -= hierarchy_state.scroll_offset
    item_height := f32(25)
    
    for &obj in scene_data.objects {
        if y_pos + item_height < list_y_start {
            y_pos += item_height
            continue
        }
        if y_pos > list_y_end {  // Stop rendering if we'd overlap debug info
            break
        }
        
        item_rect := rl.Rectangle{
            hierarchy_state.panel_x + padding,
            y_pos,
            hierarchy_state.panel_width - padding * 2,
            item_height - 2,
        }
        
        mouse_pos := rl.GetMousePosition()
        is_hovered := rl.CheckCollisionPointRec(mouse_pos, item_rect)
        is_selected := obj.id == selection_state.selected_id
        
        // Draw background
        if is_selected {
            rl.DrawRectangleRec(item_rect, UI_COLORS.HOVER)
        } else if is_hovered {
            rl.DrawRectangleRec(item_rect, UI_COLORS.HOVER)
        }
        
        // Draw object type indicator (mini shape representation)
        type_color := operations.get_default_color(obj.object_type)
        if is_selected {
            // Brighter version when selected
            type_color = rl.ColorBrightness(type_color, 0.3)
        }
        
        // Calculate center position for the icon
        icon_center_x := item_rect.x + 10
        icon_center_y := item_rect.y + item_rect.height / 2
        
        switch obj.object_type {
        case .CUBE:
            // 12x12 square for cube
            square_size := f32(11 )
            rl.DrawRectangle(i32(icon_center_x - square_size/2), i32(icon_center_y - square_size/2), 
                           i32(square_size), i32(square_size), type_color)
        case .SPHERE:
            // 6 radius circle for sphere
            rl.DrawCircle(i32(icon_center_x), i32(icon_center_y), 6, type_color)
        case .CYLINDER:
            // Rectangle representing cylinder (shorter and wider than cube)
            cyl_width := f32(8)
            cyl_height := f32(14)
            rl.DrawRectangle(i32(icon_center_x - cyl_width/2), i32(icon_center_y - cyl_height/2), 
                           i32(cyl_width), i32(cyl_height), type_color)
        case .MESH:
            // Two triangles exactly as shown: left up /\, right down \/
            triangle_size := f32(4)
            offset := f32(3)
            
            // Left triangle pointing UP /\ - filled
            left_x := icon_center_x - offset
            left_top := rl.Vector2{left_x, icon_center_y - triangle_size}
            left_bottom_left := rl.Vector2{left_x - triangle_size, icon_center_y + triangle_size}
            left_bottom_right := rl.Vector2{left_x + triangle_size, icon_center_y + triangle_size}
            rl.DrawTriangle(left_top, left_bottom_left, left_bottom_right, type_color)
            
            // Right triangle pointing DOWN \/
            right_x := icon_center_x + offset
            right_top_left := rl.Vector2{right_x - triangle_size, icon_center_y - triangle_size}
            right_top_right := rl.Vector2{right_x + triangle_size, icon_center_y - triangle_size}
            right_bottom := rl.Vector2{right_x, icon_center_y + triangle_size}
            rl.DrawLineV(right_top_left, right_bottom, type_color)
            rl.DrawLineV(right_top_right, right_bottom, type_color)
            rl.DrawLineV(right_top_left, right_top_right, type_color)
        }
        
        // Draw object name (positioned after icon)
        draw_text(.SMALL, strings.clone_to_cstring(obj.name, context.temp_allocator), {item_rect.x + 22, item_rect.y + 4}, 
                     is_selected ? UI_COLORS.TEXT : UI_COLORS.TEXT)
        
        // Handle click
        if is_hovered && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            selection_state.selected_id = obj.id
            selection_state.selection_changed = true
        }
        
        y_pos += item_height
    }
    
    // Update content height for scrolling (account for reserved debug area)
    hierarchy_state.content_height = y_pos + hierarchy_state.scroll_offset
    
    // Handle scrolling (only for object list area)
    mouse_pos := rl.GetMousePosition()
    scroll_area := rl.Rectangle{
        hierarchy_state.panel_rect.x,
        hierarchy_state.panel_rect.y,
        hierarchy_state.panel_rect.width,
        panel_content_height,
    }
    if rl.CheckCollisionPointRec(mouse_pos, scroll_area) {
        wheel := rl.GetMouseWheelMove()
        if wheel != 0 {
            hierarchy_state.scroll_offset -= wheel * 30
            
            // Clamp scroll (account for reserved debug area)
            max_scroll := hierarchy_state.content_height - panel_content_height
            if max_scroll > 0 {
                hierarchy_state.scroll_offset = clamp(hierarchy_state.scroll_offset, 0, max_scroll)
            } else {
                hierarchy_state.scroll_offset = 0
            }
        }
    }

    // --- Debug Info at Bottom ---
    debug_y_start := hierarchy_state.panel_rect.height - debug_info_height + padding
    debug_y_pos := debug_y_start

    pos := camera_state.camera.position
    target := camera_state.camera.target
    distance := rl.Vector3Length(target - pos)

    // Position info
    pos_text := fmt.tprintf("Pos:   %.1f, %.1f, %.1f", pos.x, pos.y, pos.z)
    defer delete(pos_text, context.temp_allocator)
    draw_text(.SMALL, strings.clone_to_cstring(pos_text, context.temp_allocator), {padding, debug_y_pos}, UI_COLORS.TEXT_MUTED)
    debug_y_pos += 20
    
    // Speed info
    speed_text := fmt.tprintf("Speed: %.1f m/s", camera_state.movement_speed)
    defer delete(speed_text, context.temp_allocator)
    draw_text(.SMALL, strings.clone_to_cstring(speed_text, context.temp_allocator), {padding, debug_y_pos}, UI_COLORS.TEXT_MUTED)
    debug_y_pos += 20
    
    // Zoom info
    zoom_text := fmt.tprintf("Zoom:  %.1f m", distance)
    defer delete(zoom_text, context.temp_allocator)
    draw_text(.SMALL, strings.clone_to_cstring(zoom_text, context.temp_allocator), {padding, debug_y_pos}, UI_COLORS.TEXT_MUTED)
}

// Get hierarchy visibility
is_hierarchy_visible :: proc() -> bool {
    return hierarchy_state.visible
}

// Get hierarchy width
get_hierarchy_width :: proc() -> f32 {
    return hierarchy_state.panel_width
}

// Check if mouse is over hierarchy panel
is_mouse_over_hierarchy :: proc() -> bool {
    if !hierarchy_state.visible {
        return false
    }
    mouse_pos := rl.GetMousePosition()
    return rl.CheckCollisionPointRec(mouse_pos, hierarchy_state.panel_rect)
}

// Handle window resize for hierarchy
handle_hierarchy_resize :: proc() {
    hierarchy_state.panel_rect.y = 0
    hierarchy_state.panel_rect.height = f32(rl.GetScreenHeight())
}

// Toggle hierarchy visibility
toggle_hierarchy :: proc() {
    hierarchy_state.visible = !hierarchy_state.visible
}
