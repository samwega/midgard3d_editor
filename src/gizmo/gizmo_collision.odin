package gizmo

import rl "vendor:raylib"
import "core:math"

// --- Collision Detection Functions ---

// Check if point is inside a 2D quad (defined by 4 points)
point_in_quad_2d :: proc(point: rl.Vector2, p1: rl.Vector2, p2: rl.Vector2, p3: rl.Vector2, p4: rl.Vector2) -> bool {
    // Simple approach: check if point is on the same side of all edges
    // This works for convex quads
    sign1 := math.sign((p2.x - p1.x) * (point.y - p1.y) - (p2.y - p1.y) * (point.x - p1.x))
    sign2 := math.sign((p3.x - p2.x) * (point.y - p2.y) - (p3.y - p2.y) * (point.x - p2.x))
    sign3 := math.sign((p4.x - p3.x) * (point.y - p3.y) - (p4.y - p3.y) * (point.x - p3.x))
    sign4 := math.sign((p1.x - p4.x) * (point.y - p4.y) - (p1.y - p4.y) * (point.x - p4.x))
    
    // Point is inside if all signs are the same
    return (sign1 == sign2) && (sign2 == sign3) && (sign3 == sign4)
}

// Enhanced handle collision detection for all modes (3D-aware)
check_handle_collision_enhanced :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, camera: rl.Camera3D, object_position: rl.Vector3) -> Handle_Type {
    if !state.visible {
        return .NONE
    }
    
    switch state.mode {
    case .TRANSLATE:
        return check_translation_collision(state, mouse_pos, camera, object_position)
    case .ROTATE:
        return check_rotation_collision(state, mouse_pos)
    case .SCALE:
        return check_scale_collision(state, mouse_pos, camera, object_position)
    case .TRANSFORM:
        return check_universal_collision(state, mouse_pos, camera, object_position)
    case .NONE:
        return .NONE
    }
    
    return .NONE
}

// Check collision for the universal gizmo
check_universal_collision :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, camera: rl.Camera3D, object_position: rl.Vector3) -> Handle_Type {
    
    // Priority: Scale Cubes > Arrow Tips > Planes > Rotation Rings

    // --- 1. Check Scale Handles (Cubes only) ---
    scale_screen_radius := state.base_size * 0.8
    scale_world_gizmo_size := calculate_world_radius_for_screen_size(object_position, scale_screen_radius, camera)
    scale_handles := []Handle_Type{.X_SCALE, .Y_SCALE, .Z_SCALE}
    directions := []rl.Vector3{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    
    cube_edge_offset := scale_world_gizmo_size * 1.6
    cube_screen_size := f32(25.0) // Match rendering

    for handle, i in scale_handles {
        if (i == 0 && .X not_in state.active_axes) ||
           (i == 1 && .Y not_in state.active_axes) ||
           (i == 2 && .Z not_in state.active_axes) {
            continue
        }
        
        cube_center := object_position + directions[i] * cube_edge_offset
        cube_center_2d := rl.GetWorldToScreen(cube_center, camera)
        
        margin := f32(10.0) // Generous collision margin
        cube_rect := rl.Rectangle{
            cube_center_2d.x - (cube_screen_size + margin)/2,
            cube_center_2d.y - (cube_screen_size + margin)/2,
            cube_screen_size + margin,
            cube_screen_size + margin,
        }
        
        if rl.CheckCollisionPointRec(mouse_pos, cube_rect) {
            return handle
        }
    }

    // --- 2. Check Translation Handles (Arrow Tips only) ---
    trans_screen_radius := state.base_size * 1.1
    trans_world_gizmo_size := calculate_world_radius_for_screen_size(object_position, trans_screen_radius, camera)
    translation_handles := []Handle_Type{.X_AXIS, .Y_AXIS, .Z_AXIS}
    
    closest_dist_axis := f32(math.F32_MAX)
    closest_handle := Handle_Type.NONE
    
    for handle, i in translation_handles {
        if (i == 0 && .X not_in state.active_axes) ||
           (i == 1 && .Y not_in state.active_axes) ||
           (i == 2 && .Z not_in state.active_axes) {
            continue
        }
        
        direction := directions[i]
        
        // Logic from draw_3d_axis_arrow to find the cone
        cube_face_offset := trans_world_gizmo_size * 0.6
        arrow_length := trans_world_gizmo_size * 1.5
        cone_height := trans_world_gizmo_size * 0.4

        line_start_3d := object_position + direction * cube_face_offset
        cone_base_3d := line_start_3d + direction * (arrow_length - cone_height)
        cone_tip_3d := line_start_3d + direction * arrow_length

        cone_base_2d := rl.GetWorldToScreen(cone_base_3d, camera)
        cone_tip_2d := rl.GetWorldToScreen(cone_tip_3d, camera)

        // This function is in gizmo_math.odin
        dist := point_to_line_distance_2d(mouse_pos, cone_base_2d, cone_tip_2d)

        click_radius := f32(15.0) // Generous click radius
        if dist < click_radius && dist < closest_dist_axis {
            closest_dist_axis = dist
            closest_handle = handle
        }
    }

    if closest_handle != .NONE {
        return closest_handle
    }

    // --- 3. Check Planar Handles ---
    if .X in state.active_axes && .Y in state.active_axes {
        if check_2d_plane_collision(state, mouse_pos, object_position, {1, 1, 0}, trans_world_gizmo_size, camera, .XY_PLANE) {
            return .XY_PLANE
        }
    }
    if .X in state.active_axes && .Z in state.active_axes {
        if check_2d_plane_collision(state, mouse_pos, object_position, {1, 0, 1}, trans_world_gizmo_size, camera, .XZ_PLANE) {
            return .XZ_PLANE
        }
    }
    if .Y in state.active_axes && .Z in state.active_axes {
        if check_2d_plane_collision(state, mouse_pos, object_position, {0, 1, 1}, trans_world_gizmo_size, camera, .YZ_PLANE) {
            return .YZ_PLANE
        }
    }

    // --- 4. Check Rotation Handles ---
    rotation_handle := check_rotation_collision(state, mouse_pos)
    if rotation_handle != .NONE {
        return rotation_handle
    }

    return .NONE
}

// Check collision for global rotation mode (sphere-based)
check_rotation_collision :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2) -> Handle_Type {
    sphere_radius := state.base_size * 1.1   // Same as rendering
    view_radius := state.base_size * 1.4     // Slightly larger for outer white circle
    max_tolerance := f32(25.0)  // Collision tolerance in pixels
    
    // Check view rotation circle first (outermost, highest priority)
    view_distance := calculate_distance_to_screen_circle(state, mouse_pos, view_radius)
    if view_distance < max_tolerance {
        return .VIEW_ROTATION
    }
    
    // Check each world-axis sphere-positioned circle
    best_handle := Handle_Type.NONE
    closest_distance := max_tolerance
    
    // Check each sphere-positioned circle (only front halves are drawn)
    if .X in state.active_axes {
        x_distance := calculate_distance_to_ellipse_ring(state, mouse_pos, sphere_radius, 1, 2) // YZ plane
        if x_distance < closest_distance {
            closest_distance = x_distance
            best_handle = .X_ROTATION
        }
    }
    
    if .Y in state.active_axes {
        y_distance := calculate_distance_to_ellipse_ring(state, mouse_pos, sphere_radius, 0, 2) // XZ plane
        if y_distance < closest_distance {
            closest_distance = y_distance
            best_handle = .Y_ROTATION
        }
    }
    
    if .Z in state.active_axes {
        z_distance := calculate_distance_to_ellipse_ring(state, mouse_pos, sphere_radius, 0, 1) // XY plane
        if z_distance < closest_distance {
            closest_distance = z_distance
            best_handle = .Z_ROTATION
        }
    }
    
    return best_handle
}

// Check collision for scale handles using 2D rectangle collision - VERY GENEROUS
check_scale_collision :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, camera: rl.Camera3D, object_position: rl.Vector3) -> Handle_Type {
    // Use screen radius directly like rotation gizmo
    screen_radius := state.base_size * 0.8   // EXACTLY same as rotation gizmo
    world_gizmo_size := calculate_world_radius_for_screen_size(object_position, screen_radius, camera)
    
    // Check uniform scale handle first (center rectangle) - BIGGER
    center_2d := rl.GetWorldToScreen(object_position, camera)
    center_size := f32(40.0)  // Same as rendering - BIGGER
    center_margin := f32(15.0) // Generous margin
    center_rect := rl.Rectangle{
        center_2d.x - (center_size + center_margin)/2,
        center_2d.y - (center_size + center_margin)/2,
        center_size + center_margin,
        center_size + center_margin,
    }
    
    if rl.CheckCollisionPointRec(mouse_pos, center_rect) {
        return .UNIFORM_SCALE
    }
    
    // Check axis scale handles (2D rectangles at calculated positions) - MUCH BIGGER
    scale_handles := []Handle_Type{.X_SCALE, .Y_SCALE, .Z_SCALE}
    directions := []rl.Vector3{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    
    cube_edge_offset := world_gizmo_size * 1.6
    cube_screen_size := f32(20.0)  // Same as rendering - more consistent
    
    for handle, i in scale_handles {
        if (i == 0 && .X not_in state.active_axes) ||
           (i == 1 && .Y not_in state.active_axes) ||
           (i == 2 && .Z not_in state.active_axes) {
            continue
        }
        
        // Calculate 3D position and project to 2D
        cube_center := object_position + directions[i] * cube_edge_offset
        cube_center_2d := rl.GetWorldToScreen(cube_center, camera)
        
        // Check 2D rectangle collision with generous margin
        margin := f32(10.0)  // Generous collision margin
        cube_rect := rl.Rectangle{
            cube_center_2d.x - (cube_screen_size + margin)/2,
            cube_center_2d.y - (cube_screen_size + margin)/2,
            cube_screen_size + margin,
            cube_screen_size + margin,
        }
        
        if rl.CheckCollisionPointRec(mouse_pos, cube_rect) {
            return handle
        }
    }
    
    return .NONE
}

// Check collision for translation handles using 2D screen-space collision - VERY GENEROUS
check_translation_collision :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, camera: rl.Camera3D, object_position: rl.Vector3) -> Handle_Type {
    // Use screen radius directly like rotation gizmo
    screen_radius := state.base_size * 1.3   // EXACTLY same as rotation gizmo
    world_gizmo_size := calculate_world_radius_for_screen_size(object_position, screen_radius, camera)
    
    // Check each axis for collision using 2D line distance
    translation_handles := []Handle_Type{.X_AXIS, .Y_AXIS, .Z_AXIS}
    directions := []rl.Vector3{{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    
    cube_face_offset := world_gizmo_size * 0.6  // Start from cube face
    arrow_length := world_gizmo_size * 1.5      // Total arrow length
    cone_height := world_gizmo_size * 0.4       // Cone arrowhead height
    
    closest_distance := f32(math.F32_MAX)
    closest_handle := Handle_Type.NONE
    click_radius := f32(15.0)  // More consistent collision radius
    
    for handle, i in translation_handles {
        if (i == 0 && .X not_in state.active_axes) ||
           (i == 1 && .Y not_in state.active_axes) ||
           (i == 2 && .Z not_in state.active_axes) {
            continue
        }
        
        direction := directions[i]
        
        // Calculate 3D positions matching rendering
        line_start_3d := object_position + direction * cube_face_offset
        line_end_3d := line_start_3d + direction * (arrow_length - cone_height)
        cone_tip_3d := line_start_3d + direction * arrow_length

        // Project to 2D screen coordinates
        line_start_2d := rl.GetWorldToScreen(line_start_3d, camera)
        line_end_2d := rl.GetWorldToScreen(line_end_3d, camera)
        cone_tip_2d := rl.GetWorldToScreen(cone_tip_3d, camera)
        
        // Check 2D line collision for the shaft - GENEROUS
        line_dist := point_to_line_distance_2d(mouse_pos, line_start_2d, line_end_2d)
        cone_dist := point_to_line_distance_2d(mouse_pos, line_end_2d, cone_tip_2d)

        min_dist := min(line_dist, cone_dist)
        if min_dist < click_radius && min_dist < closest_distance {
            closest_distance = min_dist
            closest_handle = handle
        }
    }
    
    // Check plane handles using 2D rectangle collision - VERY GENEROUS
    if closest_handle == .NONE {
        // Check XY plane
        if .X in state.active_axes && .Y in state.active_axes {
            if check_2d_plane_collision(state, mouse_pos, object_position, {1, 1, 0}, world_gizmo_size, camera, .XY_PLANE) {
                closest_handle = .XY_PLANE
            }
        }
        
        // Check XZ plane
        if .X in state.active_axes && .Z in state.active_axes && closest_handle == .NONE {
            if check_2d_plane_collision(state, mouse_pos, object_position, {1, 0, 1}, world_gizmo_size, camera, .XZ_PLANE) {
                closest_handle = .XZ_PLANE
            }
        }
        
        // Check YZ plane
        if .Y in state.active_axes && .Z in state.active_axes && closest_handle == .NONE {
            if check_2d_plane_collision(state, mouse_pos, object_position, {0, 1, 1}, world_gizmo_size, camera, .YZ_PLANE) {
                closest_handle = .YZ_PLANE
            }
        }
    }
    
    return closest_handle
}

// Check 2D plane collision using screen-projected quad
check_2d_plane_collision :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, object_position: rl.Vector3, direction: rl.Vector3, world_size: f32, camera: rl.Camera3D, handle: Handle_Type) -> bool {
    // --- This logic must EXACTLY match draw_3d_plane_handle in gizmo_render.odin ---

    // Position plane handle at the corner of the invisible cube
    // NOTE: world_size for collision is slightly larger than for rendering for easier clicking.
    plane_offset := world_size * 0.6

    // The direction vector (e.g., {1,1,0}) correctly positions the handle in the quadrant
    center := object_position + direction * plane_offset
    
    // Determine normal for the quad's orientation
    normal: rl.Vector3
    #partial switch handle {
    case .XY_PLANE: normal = {0, 0, 1}
    case .XZ_PLANE: normal = {0, 1, 0}
    case .YZ_PLANE: normal = {1, 0, 0}
    }
    
    quad_size := world_size * 0.4 // Match rendering logic

    // Create two perpendicular vectors to the normal for the quad
    up_vec := rl.Vector3{0, 1, 0}
    if math.abs(rl.Vector3DotProduct(normal, up_vec)) > 0.9 {
        up_vec = rl.Vector3{1, 0, 0}
    }
    
    right_vec := rl.Vector3Normalize(rl.Vector3CrossProduct(normal, up_vec))
    up_vec = rl.Vector3Normalize(rl.Vector3CrossProduct(right_vec, normal))
    
    half_size := quad_size * 0.5
    
    // Calculate 3D quad vertices
    v1_3d := center + right_vec * -half_size + up_vec * -half_size
    v2_3d := center + right_vec *  half_size + up_vec * -half_size  
    v3_3d := center + right_vec *  half_size + up_vec *  half_size
    v4_3d := center + right_vec * -half_size + up_vec *  half_size

    // Project 3D vertices to 2D screen space
    v1_2d := rl.GetWorldToScreen(v1_3d, camera)
    v2_2d := rl.GetWorldToScreen(v2_3d, camera)
    v3_2d := rl.GetWorldToScreen(v3_3d, camera)
    v4_2d := rl.GetWorldToScreen(v4_3d, camera)

    // Check if the mouse point is inside the projected 2D quad
    return point_in_quad_2d(mouse_pos, v1_2d, v2_2d, v3_2d, v4_2d)
}

// Helper functions

// Calculate actual distance from mouse to a perfect screen circle
calculate_distance_to_screen_circle :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, radius: f32) -> f32 {
    center := state.center_2d
    mouse_distance := rl.Vector2Distance(mouse_pos, center)
    return math.abs(mouse_distance - radius)
}

// Calculate actual distance from mouse to an elliptical ring using sampling approach
calculate_distance_to_ellipse_ring :: proc(state: ^Gizmo_State, mouse_pos: rl.Vector2, radius: f32, axis1_idx: int, axis2_idx: int) -> f32 {
    center := state.center_2d
    
    // Get the two axis directions that form this ellipse
    axis1_dir := state.axes_2d[axis1_idx]
    axis2_dir := state.axes_2d[axis2_idx]
    
    // Sample points around the ellipse and find the closest to mouse
    min_distance := f32(math.F32_MAX)
    sample_count := 32  // Number of points to sample around the ring
    
    for i in 0..<sample_count {
        angle := f32(i) * 2.0 * math.PI / f32(sample_count)
        
        // Calculate point on ellipse using the two axis directions
        cos_angle := math.cos(angle)
        sin_angle := math.sin(angle)
        
        ellipse_point := center + axis1_dir * (cos_angle * radius) + axis2_dir * (sin_angle * radius)
        
        // Calculate distance from mouse to this point on the ellipse
        distance := rl.Vector2Distance(mouse_pos, ellipse_point)
        
        if distance < min_distance {
            min_distance = distance
        }
    }
    
    return min_distance
}