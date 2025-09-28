package gizmo

import "../scene"
import rl "vendor:raylib"
import "core:math"

// --- Drag Handling Functions ---

// Handle ongoing drag with robust 3D transformation
handle_drag :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object,
                   mouse_pos: rl.Vector2, camera: rl.Camera3D) -> bool {
    
    
    
    // Calculate mouse movement delta
    mouse_delta := mouse_pos - state.drag_start_mouse
    ray := rl.GetScreenToWorldRay(mouse_pos, camera)
    new_position := state.drag_start_world

    #partial switch state.drag_handle {
    case .X_AXIS, .Y_AXIS, .Z_AXIS:
        // Single axis transformation
        axis_vector: rl.Vector3
        #partial switch state.drag_handle {
        case .X_AXIS: axis_vector = {1, 0, 0}
        case .Y_AXIS: axis_vector = {0, 1, 0}
        case .Z_AXIS: axis_vector = {0, 0, 1}
        }
        
        // Project current mouse ray onto the world axis  
        t := project_ray_on_line(ray, object.transform.position, axis_vector)
        current_world_point := object.transform.position + axis_vector * t
        
        // Calculate movement by subtracting the grab offset
        new_position = current_world_point - state.grab_offset
        
    case .XY_PLANE, .XZ_PLANE, .YZ_PLANE:
        // Plane transformation
        plane_normal: rl.Vector3
        #partial switch state.drag_handle {
        case .XY_PLANE: plane_normal = {0, 0, 1}  // Z normal
        case .XZ_PLANE: plane_normal = {0, 1, 0}  // Y normal  
        case .YZ_PLANE: plane_normal = {1, 0, 0}  // X normal
        }
        
        // Intersect ray with the constraint plane through object center
        if hit, distance := get_ray_collision_plane(ray, object.transform.position, plane_normal); hit {
            current_world_point := ray.position + ray.direction * distance
            // Calculate movement by subtracting the grab offset
            new_position = current_world_point - state.grab_offset
        }
    }
    
    // Apply grid snapping if enabled
    if state.snap_enabled {
        new_position = snap_to_grid(new_position, state.snap_increment)
    }
    
    object.transform.position = new_position
    return true
}

// Handle translation drag (existing functionality)
handle_translation_drag :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object,
                               mouse_pos: rl.Vector2, camera: rl.Camera3D) -> bool {
    return handle_drag(state, object, mouse_pos, camera)
}

// Restored working rotation implementation (has jumping but all 4 circles work)
// NEW: Quaternion-based rotation implementation (no jumping, proper world-space)
handle_rotation_drag :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object,
                            mouse_pos: rl.Vector2, camera: rl.Camera3D) -> bool {
    
    center := state.center_2d
    
    #partial switch state.drag_handle {
    case .X_ROTATION:
        // Rotate around WORLD X-axis using radial motion in YZ plane
        initial_angle := calculate_ring_angle(state, state.drag_start_mouse, 1, 2) // YZ plane
        current_angle := calculate_ring_angle(state, mouse_pos, 1, 2)
        
        delta_rotation := (current_angle - initial_angle)  // Keep in radians
        
        // Create rotation quaternion around world X-axis
        rotation_quat := rl.QuaternionFromAxisAngle({1, 0, 0}, delta_rotation)
        
        // Apply rotation: new_quat = rotation_quat * initial_quat
        new_quaternion := rotation_quat * state.initial_quaternion
        
        // Convert back to Euler for object (only at final interface point)
        object.transform.rotation = rl.QuaternionToEuler(new_quaternion) * 180.0 / math.PI
        
    case .Y_ROTATION:
        // Rotate around WORLD Y-axis using radial motion in XZ plane
        initial_angle := calculate_ring_angle(state, state.drag_start_mouse, 0, 2) // XZ plane
        current_angle := calculate_ring_angle(state, mouse_pos, 0, 2)
        
        delta_rotation := (current_angle - initial_angle)  // Keep in radians
        
        // Create rotation quaternion around world Y-axis
        rotation_quat := rl.QuaternionFromAxisAngle({0, 1, 0}, -delta_rotation)
        
        // Apply rotation: new_quat = rotation_quat * initial_quat
        new_quaternion := rotation_quat * state.initial_quaternion
        
        // Convert back to Euler for object (only at final interface point)
        object.transform.rotation = rl.QuaternionToEuler(new_quaternion) * 180.0 / math.PI
        
    case .Z_ROTATION:
        // Rotate around WORLD Z-axis using radial motion in XY plane
        initial_angle := calculate_ring_angle(state, state.drag_start_mouse, 0, 1) // XY plane
        current_angle := calculate_ring_angle(state, mouse_pos, 0, 1)
        
        delta_rotation := (current_angle - initial_angle)  // Keep in radians
        
        // Create rotation quaternion around world Z-axis
        rotation_quat := rl.QuaternionFromAxisAngle({0, 0, 1}, delta_rotation)
        
        // Apply rotation: new_quat = rotation_quat * initial_quat
        new_quaternion := rotation_quat * state.initial_quaternion
        
        // Convert back to Euler for object (only at final interface point)
        object.transform.rotation = rl.QuaternionToEuler(new_quaternion) * 180.0 / math.PI
        
    case .VIEW_ROTATION:
        // White outer circle: Rotate around camera-to-object axis (FIXED DIRECTION)
        initial_angle := math.atan2(state.drag_start_mouse.y - center.y, state.drag_start_mouse.x - center.x)
        current_angle := math.atan2(mouse_pos.y - center.y, mouse_pos.x - center.x)
        
        delta_rotation := (current_angle - initial_angle)  // Fixed direction, keep in radians
        
        // Calculate camera-to-object direction as rotation axis
        camera_to_obj := rl.Vector3Normalize(object.transform.position - camera.position)
        
        // Create rotation quaternion around camera-to-object axis
        rotation_quat := rl.QuaternionFromAxisAngle(camera_to_obj, delta_rotation)
        
        // Apply rotation: new_quat = rotation_quat * initial_quat
        new_quaternion := rotation_quat * state.initial_quaternion
        
        // Convert back to Euler for object (only at final interface point)
        object.transform.rotation = rl.QuaternionToEuler(new_quaternion) * 180.0 / math.PI
    }
    
    return true
}

// Handle scale drag
handle_scale_drag :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object,
                         mouse_pos: rl.Vector2, camera: rl.Camera3D) -> bool {
    
    mouse_delta := mouse_pos - state.drag_start_mouse
    
    #partial switch state.drag_handle {
    case .X_SCALE:
        // Scale along X-axis based on movement along screen-space X direction
        axis_movement := rl.Vector2DotProduct(mouse_delta, state.axes_2d[0])
        scale_factor := 1.0 + axis_movement * 0.01  // 1% per pixel
        scale_factor = max(scale_factor, 0.1)  // Minimum scale
        
        new_scale := state.initial_scale
        new_scale.x = state.initial_scale.x * scale_factor
        object.transform.scale = new_scale
        
    case .Y_SCALE:
        // Scale along Y-axis
        axis_movement := rl.Vector2DotProduct(mouse_delta, state.axes_2d[1])
        scale_factor := 1.0 + axis_movement * 0.01
        scale_factor = max(scale_factor, 0.1)
        
        new_scale := state.initial_scale
        new_scale.y = state.initial_scale.y * scale_factor
        object.transform.scale = new_scale
        
    case .Z_SCALE:
        // Scale along Z-axis
        axis_movement := rl.Vector2DotProduct(mouse_delta, state.axes_2d[2])
        scale_factor := 1.0 + axis_movement * 0.01
        scale_factor = max(scale_factor, 0.1)
        
        new_scale := state.initial_scale
        new_scale.z = state.initial_scale.z * scale_factor
        object.transform.scale = new_scale
        
    case .UNIFORM_SCALE:
        // Uniform scaling based on distance from center
        distance_delta := rl.Vector2Length(mouse_delta)
        if mouse_delta.x + mouse_delta.y < 0 {
            distance_delta = -distance_delta  // Scale down if moving toward center
        }
        
        scale_factor := 1.0 + distance_delta * 0.01
        scale_factor = max(scale_factor, 0.1)
        
        new_scale := state.initial_scale * scale_factor
        object.transform.scale = new_scale
    }
    
    return true
}