package gizmo

import rl "vendor:raylib"
import "core:math"

// --- Mathematical Helper Functions for 3D Gizmo Interaction ---

// Calculate angle of mouse position relative to a specific axis plane
calculate_ring_angle :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, axis1_idx: int, axis2_idx: int) -> f32 {
    center := state.center_2d
    to_mouse := mouse_pos - center
    
    // Get screen-space axis directions for the rotation plane
    axis1_dir := state.axes_2d[axis1_idx]
    axis2_dir := state.axes_2d[axis2_idx]
    
    // Project mouse offset onto the two axis directions
    proj1 := rl.Vector2DotProduct(to_mouse, axis1_dir)
    proj2 := rl.Vector2DotProduct(to_mouse, axis2_dir)
    
    // Calculate angle in this plane
    return math.atan2(proj2, proj1)
}

// DEPRECATED: Matrix-based rotation functions removed
// All rotation operations now use pure quaternions for mathematical stability

// Custom ray-plane intersection
get_ray_collision_plane :: proc(ray: rl.Ray, plane_point: rl.Vector3, plane_normal: rl.Vector3) -> (bool, f32) {
    denominator := rl.Vector3DotProduct(plane_normal, ray.direction)
    if math.abs(denominator) < 0.0001 {
        return false, 0
    }
    distance := rl.Vector3DotProduct(plane_point - ray.position, plane_normal) / denominator
    return distance >= 0, distance
}

// 2D point to line segment distance
point_to_line_distance_2d :: proc(point: rl.Vector2, line_start: rl.Vector2, line_end: rl.Vector2) -> f32 {
    line_vec := line_end - line_start
    line_len := rl.Vector2Length(line_vec)
    if line_len < 0.0001 {
        return rl.Vector2Distance(point, line_start)
    }
    
    line_unit_vec := rl.Vector2Normalize(line_vec)
    point_vec := point - line_start
    projection := rl.Vector2DotProduct(point_vec, line_unit_vec)
    
    // Clamp projection to line segment
    projection = math.clamp(projection, 0, line_len)
    
    closest_point := line_start + line_unit_vec * projection
    return rl.Vector2Distance(point, closest_point)
}

// Math helper for projecting a 3D ray onto a 3D line
project_ray_on_line :: proc(ray: rl.Ray, line_point: rl.Vector3, line_dir: rl.Vector3) -> f32 {
    to_ray := ray.position - line_point
    line_dir_normalized := rl.Vector3Normalize(line_dir)
    cross := rl.Vector3CrossProduct(line_dir_normalized, ray.direction)
    cross_mag_sq := rl.Vector3DotProduct(cross, cross)
    
    if cross_mag_sq < 0.0001 {
        // Parallel case - project ray position onto line
        return rl.Vector3DotProduct(to_ray, line_dir_normalized)
    }
    
    numerator := rl.Vector3DotProduct(rl.Vector3CrossProduct(to_ray, ray.direction), cross)
    return numerator / cross_mag_sq
}

// Math helper for grid snapping
snap_to_grid :: proc(position: rl.Vector3, increment: f32) -> rl.Vector3 {
    return {
        math.round(position.x / increment) * increment,
        math.round(position.y / increment) * increment,
        math.round(position.z / increment) * increment,
    }
}

snap_to_rotation_grid :: proc(angle: f32, increment: f32) -> f32 {
    return math.round(angle / increment) * increment
}