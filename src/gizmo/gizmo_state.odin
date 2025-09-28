package gizmo

import rl "vendor:raylib"

Gizmo_Mode :: enum {
    NONE,
    TRANSLATE,
    ROTATE,        // World-space rotation with sphere-based visualization
    SCALE,
    TRANSFORM,     // Combines all three modes
}

Operation_Type :: enum { NONE, TRANSLATE, ROTATE, SCALE }

Axis_Flags :: bit_set[Axis]
Axis :: enum {
    X,
    Y,
    Z,
}

Gizmo_State :: struct {
    mode: Gizmo_Mode,
    active_axes: Axis_Flags,  // Which axes are enabled for transformation
    
    // Interaction state
    is_dragging: bool,
    drag_handle: Handle_Type,
    drag_start_world: rl.Vector3,
    drag_start_mouse: rl.Vector2,
    initial_transform: rl.Vector3,  // Position/rotation/scale at drag start
    grab_offset: rl.Vector3,        // Offset from object center to grab point
    
    // Rotation-specific state
    initial_rotation: rl.Vector3,   // Rotation at drag start (Euler) - DEPRECATED
    initial_quaternion: rl.Quaternion, // Rotation at drag start (Quaternion) - NEW
    rotation_accumulator: f32,      // Accumulated rotation during drag
    
    // Scale-specific state
    initial_scale: rl.Vector3,      // Scale at drag start
    uniform_scale_mode: bool,       // Whether to scale all axes uniformly
    
    // Visual state
    hovered_handle: Handle_Type,
    base_size: f32,            // Base gizmo size in pixels
    
    // Screen-space cache (recalculated each frame)
    center_2d: rl.Vector2,     // Object center in screen space
    axes_2d: [3]rl.Vector2,    // X, Y, Z axes in screen space (normalized)
    visible: bool,             // Whether gizmo should be rendered this frame
    
    // Settings
    snap_enabled: bool,
    snap_increment: f32,       // Grid snapping (1.0 = 1 unit grid)
    rotation_snap_increment: f32,   // Rotation snapping in degrees
}

Handle_Type :: enum {
    NONE,
    // Translation handles
    X_AXIS,
    Y_AXIS,
    Z_AXIS,
    XY_PLANE,
    XZ_PLANE,
    YZ_PLANE,
    VIEW_PLANE,  // Screen-aligned plane
    // Rotation handles
    X_ROTATION,
    Y_ROTATION,
    Z_ROTATION,
    VIEW_ROTATION,  // Camera-relative rotation (white circle)
    // Scale handles
    X_SCALE,
    Y_SCALE,
    Z_SCALE,
    UNIFORM_SCALE,
}

init :: proc() -> Gizmo_State {
    return Gizmo_State{
        mode = .TRANSLATE,
        active_axes = {.X, .Y, .Z},  // All axes enabled by default
        base_size = 130.0,           // Smaller size to better match Blender's gizmos
        snap_increment = 0.25,
        rotation_snap_increment = 15.0,  // 15 degree snapping
        uniform_scale_mode = true,       // Default to uniform scaling
    }
}

// Toggle axis constraint
toggle_axis :: proc(state: ^Gizmo_State, axis: Axis) {
    if axis in state.active_axes {
        state.active_axes -= {axis}
    } else {
        state.active_axes += {axis}
    }
}

// Set single axis constraint (exclusive)
set_single_axis :: proc(state: ^Gizmo_State, axis: Axis) {
    state.active_axes = {axis}
}

// Set plane constraint (two axes)
set_plane_constraint :: proc(state: ^Gizmo_State, axis_to_exclude: Axis) {
    state.active_axes = {.X, .Y, .Z}
    state.active_axes -= {axis_to_exclude}
}

// Get handle color based on axis and state
get_handle_color :: proc(handle: Handle_Type, is_hovered: bool, is_active: bool) -> rl.Color {
    if is_active || is_hovered {
        return rl.YELLOW
    }
    
    #partial switch handle {
    case .X_AXIS, .X_ROTATION, .X_SCALE:
        return {255, 60, 60, 255}   // Bright Red
    case .Y_AXIS, .Y_ROTATION, .Y_SCALE:
        return {60, 255, 60, 255}   // Bright Green
    case .Z_AXIS, .Z_ROTATION, .Z_SCALE:
        return {60, 120, 255, 255}  // Bright Blue
    case .VIEW_ROTATION:
        return {255, 255, 255, 255} // White for camera-relative rotation
    case .UNIFORM_SCALE:
        return {255, 255, 255, 255} // White for uniform scale
    case:
        return {128, 128, 128, 255} // Gray fallback
    }
}