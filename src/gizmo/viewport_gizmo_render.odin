package gizmo

import rl "vendor:raylib"
import "core:math"
import "core:strings"
import "../ui" // Import ui package

VIEWPORT_COLORS := struct {
    X_AXIS: rl.Color,
    Y_AXIS: rl.Color,
    Z_AXIS: rl.Color,
    BACKGROUND: rl.Color,
    BORDER: rl.Color,
    HOVER: rl.Color,
    DRAG_CIRCLE: rl.Color,
}{
    X_AXIS = {220, 74, 102, 255}, // Red
    Y_AXIS = {145, 230, 100, 255}, // Green
    Z_AXIS = {50, 100, 220, 255}, // Blue
    BACKGROUND = ui.UI_COLORS.BACKGROUND,
    BORDER = ui.UI_COLORS.BORDER,
    HOVER = ui.UI_COLORS.TEXT,
    DRAG_CIRCLE = ui.UI_COLORS.ACCENT,
}

draw_viewport_gizmo :: proc(state: ^Viewport_Gizmo_State, camera: rl.Camera3D, ui_font: rl.Font = {}) {
    if !state.visible {
        return
    }
    
    update_viewport_screen_positions(state, camera)
    
    if state.drag_circle_hovered {
        draw_drag_circle(state)
    }
    
    draw_gizmo_background(state)
    draw_connecting_lines(state)  // Add lines from axes to center like Blender
    draw_octahedron_points(state, ui_font)
    // Removed draw_center_point - no more orthographic toggle
}

update_viewport_screen_positions :: proc(state: ^Viewport_Gizmo_State, camera: rl.Camera3D) {
    state.center_screen = state.screen_position
    
    camera_forward := rl.Vector3Normalize(camera.target - camera.position)
    camera_right := rl.Vector3Normalize(rl.Vector3CrossProduct(camera_forward, camera.up))
    camera_up := rl.Vector3Normalize(rl.Vector3CrossProduct(camera_right, camera_forward))
    
    for point, i in state.octahedron_points {
        screen_x := rl.Vector3DotProduct(point, camera_right)
        screen_y := -rl.Vector3DotProduct(point, camera_up)
        
        scale := state.radius * 0.8
        state.screen_points[i] = state.center_screen + rl.Vector2{screen_x * scale, screen_y * scale}
    }
}

draw_gizmo_background :: proc(state: ^Viewport_Gizmo_State) {
    background_color := VIEWPORT_COLORS.BACKGROUND
    background_color.a = 100 // Semi-transparent
    rl.DrawCircleV(state.center_screen, state.radius, background_color)
    rl.DrawCircleLinesV(state.center_screen, state.radius, VIEWPORT_COLORS.BORDER)
}

draw_drag_circle :: proc(state: ^Viewport_Gizmo_State) {
    drag_circle_color := VIEWPORT_COLORS.DRAG_CIRCLE
    drag_circle_color.a = 120 // Semi-transparent
    rl.DrawCircleLinesV(state.center_screen, state.radius + 5, drag_circle_color)
}

// Draw connecting lines from axis points to center (like Blender)
draw_connecting_lines :: proc(state: ^Viewport_Gizmo_State) {
    line_color := ui.UI_COLORS.ACCENT
    line_color.a = 160 // Semi-transparent
    
    axes := []Viewport_Axis{.POSITIVE_X, .NEGATIVE_X, .POSITIVE_Y, .NEGATIVE_Y, .POSITIVE_Z, .NEGATIVE_Z}
    
    for axis, i in axes {
        // Only draw lines for visible axes (not behind the camera)
        screen_pos := state.screen_points[i]
        
        // Simple line from center to axis point
        rl.DrawLineV(state.center_screen, screen_pos, line_color)
    }
}

draw_octahedron_points :: proc(state: ^Viewport_Gizmo_State, ui_font: rl.Font = {}) {
    point_radius := f32(19.0)
    
    axes := []Viewport_Axis{.POSITIVE_X, .NEGATIVE_X, .POSITIVE_Y, .NEGATIVE_Y, .POSITIVE_Z, .NEGATIVE_Z}
    
    for axis, i in axes {
        screen_pos := state.screen_points[i]
        is_hovered := state.hovered_axis == axis
        is_positive := is_positive_axis(axis)
        
        color := get_axis_color(axis)
        if is_hovered {
            color = VIEWPORT_COLORS.HOVER
        }
        
        if is_positive {
            rl.DrawCircleV(screen_pos, point_radius, color)
            rl.DrawCircleLinesV(screen_pos, point_radius, VIEWPORT_COLORS.BORDER)
            
            letter := get_axis_letter(axis)
            
            // Simple black text like Blender - perfectly visible on all colors
            if ui_font.texture.id != 0 {
                text_size := ui.measure_text(.GIZMO, strings.clone_to_cstring(letter, context.temp_allocator))
                letter_pos := rl.Vector2{
                    screen_pos.x - text_size.x/2,
                    screen_pos.y - text_size.y/2,
                }
                ui.draw_text(.GIZMO, strings.clone_to_cstring(letter, context.temp_allocator), 
                             letter_pos, rl.BLACK) // Black text for visibility on colored backgrounds
            } else {
                text_width := rl.MeasureText(strings.clone_to_cstring(letter, context.temp_allocator), 18)
                letter_pos := rl.Vector2{
                    screen_pos.x - f32(text_width)/2,
                    screen_pos.y - 9.0,
                }
                rl.DrawText(strings.clone_to_cstring(letter, context.temp_allocator), 
                           i32(letter_pos.x), i32(letter_pos.y), 18, rl.BLACK) // Black text for visibility on colored backgrounds
            }
        } else {
            rl.DrawCircleLinesV(screen_pos, point_radius, color)
            if is_hovered {
                rl.DrawCircleLinesV(screen_pos, point_radius - 2, color)
            }
        }
    }
}

get_axis_color :: proc(axis: Viewport_Axis) -> rl.Color {
    switch axis {
    case .POSITIVE_X, .NEGATIVE_X: return VIEWPORT_COLORS.X_AXIS
    case .POSITIVE_Y, .NEGATIVE_Y: return VIEWPORT_COLORS.Y_AXIS
    case .POSITIVE_Z, .NEGATIVE_Z: return VIEWPORT_COLORS.Z_AXIS
    case .CENTER, .NONE: return ui.UI_COLORS.TEXT // Themed color
    }
    return ui.UI_COLORS.TEXT // Themed color
}
