package gizmo

import "../scene"
import rl "vendor:raylib"
import "core:math"

// --- Main Interaction Logic ---

// Helper to determine the operation type from the handle
get_operation_type_from_handle :: proc(handle: Handle_Type) -> Operation_Type {
    #partial switch handle {
    case .X_AXIS, .Y_AXIS, .Z_AXIS, .XY_PLANE, .XZ_PLANE, .YZ_PLANE:
        return .TRANSLATE
    case .X_ROTATION, .Y_ROTATION, .Z_ROTATION, .VIEW_ROTATION:
        return .ROTATE
    case .X_SCALE, .Y_SCALE, .Z_SCALE, .UNIFORM_SCALE:
        return .SCALE
    }
    return .NONE
}

// Update gizmo interaction state
update :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object, 
               mouse_pos: rl.Vector2, camera: rl.Camera3D,
               mouse_clicked: bool, mouse_released: bool) -> (transform_changed: bool, consumed_input: bool) {
    
    if object == nil || state.mode == .NONE || !state.visible {
        return false, false
    }
    
    transform_changed = false
    consumed_input = false
    
    // Handle drag release
    if mouse_released && state.is_dragging {
        state.is_dragging = false
        state.rotation_accumulator = 0  // Reset rotation accumulator
        return false, true 
    }
    
    // Handle ongoing drag
    if state.is_dragging {
        op_type: Operation_Type
        if state.mode == .TRANSFORM {
            op_type = get_operation_type_from_handle(state.drag_handle)
        } else {
            #partial switch state.mode {
            case .TRANSLATE: op_type = .TRANSLATE
            case .ROTATE:    op_type = .ROTATE
            case .SCALE:     op_type = .SCALE
            }
        }

        #partial switch op_type {
        case .TRANSLATE:
            transform_changed = handle_translation_drag(state, object, mouse_pos, camera)
        case .ROTATE:
            transform_changed = handle_rotation_drag(state, object, mouse_pos, camera)
        case .SCALE:
            transform_changed = handle_scale_drag(state, object, mouse_pos, camera)
        }
        return transform_changed, true
    }
    
    // Check for hover/click interactions
    state.hovered_handle = check_handle_collision_enhanced(state, mouse_pos, camera, object.transform.position)
    
    if state.hovered_handle != .NONE {
        consumed_input = true
        
        if mouse_clicked {
            start_drag_enhanced(state, object, mouse_pos, state.hovered_handle, camera)
        }
    }
    
    return transform_changed, consumed_input
}

// Start drag with mode-specific initialization
start_drag_enhanced :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object, 
                          mouse_pos: rl.Vector2, handle: Handle_Type, camera: rl.Camera3D) {
    state.is_dragging = true
    state.hovered_handle = handle
    state.drag_handle = handle
    
    op_type: Operation_Type
    if state.mode == .TRANSFORM {
        op_type = get_operation_type_from_handle(handle)
    } else {
        #partial switch state.mode {
        case .TRANSLATE: op_type = .TRANSLATE
        case .ROTATE:    op_type = .ROTATE
        case .SCALE:     op_type = .SCALE
        }
    }

    // For translation mode, calculate the actual world point where the handle was clicked
    if op_type == .TRANSLATE {
        ray := rl.GetScreenToWorldRay(mouse_pos, camera)
        #partial switch handle {
        case .X_AXIS, .Y_AXIS, .Z_AXIS:
            // For axis handles, find closest point on the axis to the mouse ray
            axis_vector: rl.Vector3
            #partial switch handle {
            case .X_AXIS: axis_vector = {1, 0, 0}
            case .Y_AXIS: axis_vector = {0, 1, 0}  
            case .Z_AXIS: axis_vector = {0, 0, 1}
            }
            
            // Find the closest point on the axis line to the mouse ray
            t := project_ray_on_line(ray, object.transform.position, axis_vector)
            state.drag_start_world = object.transform.position + axis_vector * t
            
        case .XY_PLANE, .XZ_PLANE, .YZ_PLANE:
            // For plane handles, intersect ray with the constraint plane at object center
            plane_normal: rl.Vector3
            #partial switch handle {
            case .XY_PLANE: plane_normal = {0, 0, 1}  // Z normal
            case .XZ_PLANE: plane_normal = {0, 1, 0}  // Y normal
            case .YZ_PLANE: plane_normal = {1, 0, 0}  // X normal
            }
            if hit, distance := get_ray_collision_plane(ray, object.transform.position, plane_normal); hit {
                state.drag_start_world = ray.position + ray.direction * distance
            } else {
                state.drag_start_world = object.transform.position
            }
        }
        state.grab_offset = state.drag_start_world - object.transform.position
    } else {
        state.drag_start_world = object.transform.position
        state.grab_offset = {0, 0, 0}
    }
    
    // For rotation handles, project mouse position onto the circle to prevent jumping
    if op_type == .ROTATE {
        center := state.center_2d
        radius := state.base_size * 0.8  // Same as visual circle radius
        
        #partial switch handle {
        case .VIEW_ROTATION:
            // Project onto outer circle
            to_mouse := rl.Vector2Normalize(mouse_pos - center)
            state.drag_start_mouse = center + to_mouse * (state.base_size * 1.0)
        case .X_ROTATION, .Y_ROTATION, .Z_ROTATION:
            // Project onto inner circles
            to_mouse := rl.Vector2Normalize(mouse_pos - center) 
            state.drag_start_mouse = center + to_mouse * radius
        case:
            state.drag_start_mouse = mouse_pos
        }
    } else {
        state.drag_start_mouse = mouse_pos
    }
    
    #partial switch op_type {
    case .TRANSLATE:
        state.initial_transform = object.transform.position
    case .ROTATE:
        state.initial_rotation = object.transform.rotation
        // Convert Euler to quaternion for quaternion-based rotation
        euler_radians := object.transform.rotation * math.PI / 180.0
        state.initial_quaternion = rl.QuaternionFromEuler(euler_radians.x, euler_radians.y, euler_radians.z)
        state.rotation_accumulator = 0
    case .SCALE:
        state.initial_scale = object.transform.scale
    }
}

// Keep existing start_drag for backward compatibility
start_drag :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object, 
                  mouse_pos: rl.Vector2, handle: Handle_Type, camera: rl.Camera3D) {
    start_drag_enhanced(state, object, mouse_pos, handle, camera)
}