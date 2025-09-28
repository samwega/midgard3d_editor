package gizmo

import "../camera"
import "../selection"
import "../scene"
import rl "vendor:raylib"
import "core:math"

update_viewport_gizmo :: proc(state: ^Viewport_Gizmo_State, camera_state: ^camera.State, 
                             mouse_pos: rl.Vector2, mouse_clicked: bool, 
                             selection_state: ^selection.State, scene_data: ^scene.Scene) -> bool {
    if !state.visible {
        return false
    }
    
    state.hovered_axis = check_viewport_collision(state, mouse_pos)
    state.drag_circle_hovered = check_drag_circle_collision(state, mouse_pos)
    
    view_changed := false
    
    if mouse_clicked {
        if state.hovered_axis != .NONE {
            view_changed = handle_axis_click(state, camera_state, state.hovered_axis, selection_state, scene_data)
        } else if state.drag_circle_hovered {
            // Optional drag mode - could be implemented later
        }
    }
    
    return view_changed
}

check_viewport_collision :: proc(state: ^Viewport_Gizmo_State, mouse_pos: rl.Vector2) -> Viewport_Axis {
    click_radius := f32(20.0)  // Increased from 15.0 for larger gizmo (easier clicking)
    
    // No center circle collision anymore - removed the center toggle
    
    axes := []Viewport_Axis{.POSITIVE_X, .NEGATIVE_X, .POSITIVE_Y, .NEGATIVE_Y, .POSITIVE_Z, .NEGATIVE_Z}
    
    for axis, i in axes {
        if rl.Vector2Distance(mouse_pos, state.screen_points[i]) <= click_radius {
            return axis
        }
    }
    
    return .NONE
}

check_drag_circle_collision :: proc(state: ^Viewport_Gizmo_State, mouse_pos: rl.Vector2) -> bool {
    distance := rl.Vector2Distance(mouse_pos, state.center_screen)
    return distance <= state.radius && distance > 20.0
}

handle_axis_click :: proc(state: ^Viewport_Gizmo_State, camera_state: ^camera.State, clicked_axis: Viewport_Axis, 
                          selection_state: ^selection.State, scene_data: ^scene.Scene) -> bool {
    // Ignore center clicks - we removed the center circle
    if clicked_axis == .CENTER || clicked_axis == .NONE {
        return false
    }
    
    target_axis := clicked_axis
    if clicked_axis == state.current_view {
        target_axis = get_opposite_axis(clicked_axis)
    }
    
    // Always use perspective projection - no orthographic switching
    camera_state.camera.projection = .PERSPECTIVE
    camera_state.camera.fovy = 75.0
    
    // Position camera looking along the axis direction
    // Use selected object position as center, fallback to world origin
    scene_center := rl.Vector3{0, 0, 0}  // Default to world origin
    selected_object := selection.get_selected_object(selection_state, scene_data)
    if selected_object != nil {
        scene_center = selected_object.transform.position
    }
    
    axis_direction := get_axis_direction(target_axis)
    
    // Even with quaternions, we need tiny offset to avoid up/forward vector parallelism
    if target_axis == .POSITIVE_Y {
        // Y label should put you above looking down
        axis_direction = rl.Vector3Normalize({0.01, -1, 0})
    } else if target_axis == .NEGATIVE_Y {
        // Empty circle should put you below looking up  
        axis_direction = rl.Vector3Normalize({0.01, 1, 0})
    }
    
    camera_distance := f32(15.0)  // Fixed distance for axis views
    new_camera_pos := scene_center - axis_direction * camera_distance
    new_target := scene_center
    
    // With tiny offset, we can safely use world Y+ as up for consistency with quaternion camera system
    new_up := rl.Vector3{0, 1, 0}
    
    // Apply the new camera transform
    camera_state.camera.position = new_camera_pos
    camera_state.camera.target = new_target
    camera_state.camera.up = new_up
    
    state.current_view = target_axis
    
    return true
}