package gizmo

import rl "vendor:raylib"

Viewport_Gizmo_State :: struct {
    screen_position: rl.Vector2,
    radius: f32,
    
    octahedron_points: [6]rl.Vector3,
    screen_points: [6]rl.Vector2,
    center_screen: rl.Vector2,
    visible: bool,
    
    hovered_axis: Viewport_Axis,
    drag_circle_hovered: bool,
    
    current_view: Viewport_Axis,
    view_distance: f32,  // Distance for axis-aligned views
    
    transition_speed: f32,
}

Viewport_Axis :: enum {
    NONE,
    POSITIVE_X,
    NEGATIVE_X,
    POSITIVE_Y,
    NEGATIVE_Y,
    POSITIVE_Z,
    NEGATIVE_Z,
    CENTER,
}

init_viewport_gizmo :: proc() -> Viewport_Gizmo_State {
    return Viewport_Gizmo_State{
        radius = 85.0,  // Increased from 65.0 for better visibility
        octahedron_points = {
            {1, 0, 0},
            {-1, 0, 0},
            {0, 1, 0},
            {0, -1, 0},
            {0, 0, 1},
            {0, 0, -1},
        },
        current_view = .NONE,
        view_distance = 15.0,
        transition_speed = 5.0,
        visible = true,
    }
}

update_viewport_gizmo_position :: proc(state: ^Viewport_Gizmo_State, inspector_visible: bool = false, inspector_width: f32 = 0) {
    margin := f32(80)
    vertical_margin := f32(120)  // Move down from the very top
    
    // Adjust horizontal position based on inspector panel - add extra spacing when inspector is visible
    horizontal_offset := inspector_visible ? (inspector_width + margin + 10) : (margin + 10)  // -30 when hidden to prevent off-screen
    
    state.screen_position = rl.Vector2{
        f32(rl.GetScreenWidth()) - horizontal_offset,
        vertical_margin,
    }
}

get_axis_direction :: proc(axis: Viewport_Axis) -> rl.Vector3 {
    switch axis {
    case .POSITIVE_X: return {1, 0, 0}
    case .NEGATIVE_X: return {-1, 0, 0}
    case .POSITIVE_Y: return {0, 1, 0}
    case .NEGATIVE_Y: return {0, -1, 0}
    case .POSITIVE_Z: return {0, 0, 1}
    case .NEGATIVE_Z: return {0, 0, -1}
    case .CENTER, .NONE: return {0, 0, 0}
    }
    return {0, 0, 0}
}

get_opposite_axis :: proc(axis: Viewport_Axis) -> Viewport_Axis {
    switch axis {
    case .POSITIVE_X: return .NEGATIVE_X
    case .NEGATIVE_X: return .POSITIVE_X
    case .POSITIVE_Y: return .NEGATIVE_Y
    case .NEGATIVE_Y: return .POSITIVE_Y
    case .POSITIVE_Z: return .NEGATIVE_Z
    case .NEGATIVE_Z: return .POSITIVE_Z
    case .CENTER, .NONE: return .CENTER
    }
    return .NONE
}

is_positive_axis :: proc(axis: Viewport_Axis) -> bool {
    return axis == .POSITIVE_X || axis == .POSITIVE_Y || axis == .POSITIVE_Z
}

get_axis_letter :: proc(axis: Viewport_Axis) -> string {
    switch axis {
    case .POSITIVE_X, .NEGATIVE_X: return "X"
    case .POSITIVE_Y, .NEGATIVE_Y: return "Y" 
    case .POSITIVE_Z, .NEGATIVE_Z: return "Z"
    case .CENTER, .NONE: return ""
    }
    return ""
}