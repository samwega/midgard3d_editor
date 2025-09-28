package gizmo

import "../scene"
import rl "vendor:raylib"

import "core:math"

// Colors for gizmo handles - much brighter and more saturated
AXIS_COLORS := [3]rl.Color{
    {255, 60, 60, 255},    // Bright Red X
    {60, 255, 60, 255},    // Bright Green Y  
    {60, 120, 255, 255},   // Bright Blue Z
}

// Calculate the 3D world radius needed to achieve a specific screen radius
calculate_world_radius_for_screen_size :: proc(position: rl.Vector3, desired_screen_radius: f32, camera: rl.Camera3D) -> f32 {
    // Project the center position to screen
    center_screen := rl.GetWorldToScreen(position, camera)
    
    // Create a test point 1 world unit away from position (along camera's right vector)
    camera_forward := rl.Vector3Normalize(camera.target - camera.position)
    camera_right := rl.Vector3Normalize(rl.Vector3CrossProduct(camera_forward, camera.up))
    
    test_point := position + camera_right * 1.0  // 1 world unit to the right
    test_screen := rl.GetWorldToScreen(test_point, camera)
    
    // Calculate how many pixels 1 world unit translates to at this distance
    pixels_per_world_unit := rl.Vector2Distance(center_screen, test_screen)
    
    // Avoid division by zero
    if pixels_per_world_unit < 0.001 {
        return 1.0  // Fallback radius
    }
    
    // Calculate the world radius needed to achieve the desired screen radius
    return desired_screen_radius / pixels_per_world_unit
}

AXIS_COLORS_HOVER := [3]rl.Color{
    rl.YELLOW,  // Highlighted color when hovered
    rl.YELLOW,
    rl.YELLOW,
}

// Update screen-space gizmo state based on 3D world position and camera
update_screen_state :: proc(state: ^Gizmo_State, position: rl.Vector3, camera: rl.Camera3D) {
    // Project world position to screen space
    state.center_2d = rl.GetWorldToScreen(position, camera)
    
    // Check if object is behind camera first - this prevents sky gizmo bug
    camera_to_object := position - camera.position
    camera_forward := rl.Vector3Normalize(camera.target - camera.position)
    depth := rl.Vector3DotProduct(camera_to_object, camera_forward)
    
    if depth <= 0.1 {  // Object is behind or too close to camera
        state.visible = false
        return
    }
    
    // Check if object is off-screen - but be more lenient
    screen_w := f32(rl.GetScreenWidth())
    screen_h := f32(rl.GetScreenHeight())
    margin := f32(200)  // Increased margin to prevent false negatives
    
    if state.center_2d.x < -margin || state.center_2d.x > screen_w + margin ||
       state.center_2d.y < -margin || state.center_2d.y > screen_h + margin {
        state.visible = false
        return
    }
    
    // Calculate world-to-camera transformation matrix - with safety check
    camera_forward_vec := camera.target - camera.position
    if rl.Vector3Length(camera_forward_vec) < 0.0001 {
        state.visible = false  // Skip if camera is corrupted
        return
    }
    
    // For translation and scale gizmos: Initialize axes_2d for drag functionality
    // Even though 3D positioning doesn't need 2D axis calculations, drag functions do
    update_traditional_screen_state(state, position, camera)
    
    state.visible = true
}

// Cube-based screen state update for stable translation/scale gizmos
update_cube_based_screen_state :: proc(state: ^Gizmo_State, position: rl.Vector3, camera: rl.Camera3D) {
    // Calculate world radius needed to achieve desired screen size
    world_cube_radius := calculate_world_radius_for_screen_size(position, state.base_size * 0.4, camera)
    
    // Cube face centers for stable axis positioning (world-aligned cube)
    cube_faces := [3]rl.Vector3{
        {1, 0, 0},  // +X face center
        {0, 1, 0},  // +Y face center  
        {0, 0, 1},  // +Z face center
    }
    
    // Project cube faces to screen space for stable axis directions
    for axis, i in cube_faces {
        face_world_pos := position + axis * world_cube_radius
        face_screen_pos := rl.GetWorldToScreen(face_world_pos, camera)
        state.axes_2d[i] = rl.Vector2Normalize(face_screen_pos - state.center_2d)
    }
}

// Traditional screen state update (for rotation gizmos)
update_traditional_screen_state :: proc(state: ^Gizmo_State, position: rl.Vector3, camera: rl.Camera3D) {
    // Transform world axes to camera space, then to screen space
    world_x := rl.Vector3{1, 0, 0}
    world_y := rl.Vector3{0, 1, 0} 
    world_z := rl.Vector3{0, 0, 1}
    
    // Project axis endpoints to screen space
    x_end_3d := position + world_x
    y_end_3d := position + world_y
    z_end_3d := position + world_z
    
    x_end_2d := rl.GetWorldToScreen(x_end_3d, camera)
    y_end_2d := rl.GetWorldToScreen(y_end_3d, camera)
    z_end_2d := rl.GetWorldToScreen(z_end_3d, camera)
    
    // Calculate screen-space direction vectors with safe normalization
    x_diff := x_end_2d - state.center_2d
    y_diff := y_end_2d - state.center_2d
    z_diff := z_end_2d - state.center_2d
    
    x_len := rl.Vector2Length(x_diff)
    y_len := rl.Vector2Length(y_diff)
    z_len := rl.Vector2Length(z_diff)
    
    // Safe normalization - use default vectors if projection results in zero length
    state.axes_2d[0] = x_len > 0.001 ? x_diff / x_len : rl.Vector2{1, 0}  // X axis fallback
    state.axes_2d[1] = y_len > 0.001 ? y_diff / y_len : rl.Vector2{0, -1} // Y axis fallback  
    state.axes_2d[2] = z_len > 0.001 ? z_diff / z_len : rl.Vector2{0.5, 0.5} // Z axis fallback
}


// Draw the complete gizmo based on current mode




// Draw gizmo with full object transform (preferred for LOCAL_ROTATION)
draw :: proc(state: ^Gizmo_State, object: ^scene.Scene_Object, camera: rl.Camera3D) {
    if state.mode == .NONE {
        return
    }
    
    position := object.transform.position
    
    // Use world axes for all modes
    update_screen_state(state, position, camera)
    
    if !state.visible {
        return
    }

    switch state.mode {
    case .TRANSLATE:
        draw_translation_gizmo(state, camera, position)
    case .ROTATE:
        draw_rotation_gizmo(state, position, camera)
    case .SCALE:
        draw_scale_gizmo(state, camera, position)
    case .TRANSFORM:
        draw_universal_gizmo(state, camera, position)
    case .NONE:
        // Already handled above
    }
}

// Draw universal gizmo combining all three modes
draw_universal_gizmo :: proc(state: ^Gizmo_State, camera: rl.Camera3D, position: rl.Vector3) {
    // Draw rotation gizmo parts
    draw_rotation_gizmo(state, position, camera)

    // --- Draw scale gizmo parts (cubes only) ---
    scale_screen_radius := state.base_size * 0.8
    if .X in state.active_axes {
        draw_3d_scale_handle(state, .X_SCALE, position, {1, 0, 0}, scale_screen_radius, camera, draw_line=false)
    }
    if .Y in state.active_axes {
        draw_3d_scale_handle(state, .Y_SCALE, position, {0, 1, 0}, scale_screen_radius, camera, draw_line=false)
    }
    if .Z in state.active_axes {
        draw_3d_scale_handle(state, .Z_SCALE, position, {0, 0, 1}, scale_screen_radius, camera, draw_line=false)
    }

    // --- Draw translation gizmo parts (arrow tips only) ---
    trans_screen_radius := state.base_size * 1.1
    if .X in state.active_axes {
        draw_3d_axis_arrow(state, .X_AXIS, position, {1, 0, 0}, trans_screen_radius, camera, draw_line=false)
    }
    if .Y in state.active_axes {
        draw_3d_axis_arrow(state, .Y_AXIS, position, {0, 1, 0}, trans_screen_radius, camera, draw_line=false)
    }
    if .Z in state.active_axes {
        draw_3d_axis_arrow(state, .Z_AXIS, position, {0, 0, 1}, trans_screen_radius, camera, draw_line=false)
    }
    
    // --- Draw plane handles ---
    if .X in state.active_axes && .Y in state.active_axes {
        draw_3d_plane_handle(state, .XY_PLANE, position, {1, 1, 0}, trans_screen_radius, camera)
    }
    if .X in state.active_axes && .Z in state.active_axes {
        draw_3d_plane_handle(state, .XZ_PLANE, position, {1, 0, 1}, trans_screen_radius, camera)
    }
    if .Y in state.active_axes && .Z in state.active_axes {
        draw_3d_plane_handle(state, .YZ_PLANE, position, {0, 1, 1}, trans_screen_radius, camera)
    }
}

// Draw translation gizmo with EXACT same size as rotation gizmo
draw_translation_gizmo :: proc(state: ^Gizmo_State, camera: rl.Camera3D, position: rl.Vector3) {
    // Use EXACT same sizing as rotation gizmo - screen radius directly
    screen_radius := state.base_size * 1.1   // EXACTLY same as rotation gizmo
    
    // Draw 3D axes with cone arrowheads
    if .X in state.active_axes {
        draw_3d_axis_arrow(state, .X_AXIS, position, rl.Vector3{1, 0, 0}, screen_radius, camera)
    }
    if .Y in state.active_axes {
        draw_3d_axis_arrow(state, .Y_AXIS, position, rl.Vector3{0, 1, 0}, screen_radius, camera)
    }
    if .Z in state.active_axes {
        draw_3d_axis_arrow(state, .Z_AXIS, position, rl.Vector3{0, 0, 1}, screen_radius, camera)
    }

    // Draw 3D plane handles (positioned at cube edges) - MUCH LARGER
    if .X in state.active_axes && .Y in state.active_axes {
        draw_3d_plane_handle(state, .XY_PLANE, position, rl.Vector3{1, 1, 0}, screen_radius, camera)
    }
    if .X in state.active_axes && .Z in state.active_axes {
        draw_3d_plane_handle(state, .XZ_PLANE, position, rl.Vector3{1, 0, 1}, screen_radius, camera)
    }
    if .Y in state.active_axes && .Z in state.active_axes {
        draw_3d_plane_handle(state, .YZ_PLANE, position, rl.Vector3{0, 1, 1}, screen_radius, camera)
    }
}

// Draw stable axis arrow using 3D-calculated positions but 2D rendering 
draw_3d_axis_arrow :: proc(state: ^Gizmo_State, handle: Handle_Type, position: rl.Vector3, direction: rl.Vector3, screen_radius: f32, camera: rl.Camera3D, draw_line := true) {
    axis_idx := int(handle) - 1
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := is_active ? AXIS_COLORS_HOVER[axis_idx] : AXIS_COLORS[axis_idx]
    
    // Convert screen radius to world space for stable 3D positioning
    world_size := calculate_world_radius_for_screen_size(position, screen_radius, camera)
    
    // Position arrow starting from cube face (invisible cube edge)
    cube_face_offset := world_size * 0.6  // Start from cube face
    arrow_length := world_size * 1.5      // Total arrow length
    cone_height := world_size * 0.4       // Cone arrowhead height
    
    // Calculate 3D positions
    line_start := position + direction * cube_face_offset
    line_end := line_start + direction * (arrow_length - cone_height)
    cone_tip := line_start + direction * arrow_length
    
    // Project to 2D screen coordinates
    line_start_2d := rl.GetWorldToScreen(line_start, camera)
    line_end_2d := rl.GetWorldToScreen(line_end, camera)
    cone_tip_2d := rl.GetWorldToScreen(cone_tip, camera)
    
    // Draw 2D line for the axis - more consistent with rotation gizmo
    if draw_line {
        line_thickness := f32(4.0)
        if is_active {
            line_thickness = 6.0
        }
        rl.DrawLineEx(line_start_2d, line_end_2d, line_thickness, color)
    }
    
    // Draw 2D cone for the arrowhead - more consistent with rotation gizmo
    cone_base_radius := f32(12.0)  // More consistent screen-space radius
    draw_solid_cone_2d(line_end_2d, cone_tip_2d, cone_base_radius, color)
}

// Draw stable plane handle using 3D-calculated positions projected to 2D
draw_3d_plane_handle :: proc(state: ^Gizmo_State, handle: Handle_Type, position: rl.Vector3, direction: rl.Vector3, screen_radius: f32, camera: rl.Camera3D) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    
    // Determine plane color based on which axes it combines
    plane_color: rl.Color
    #partial switch handle {
    case .XY_PLANE: 
        plane_color = rl.Color{200, 200, 60, 200}  // Yellow-ish blend
    case .XZ_PLANE:
        plane_color = rl.Color{200, 60, 200, 200}  // Purple-ish blend
    case .YZ_PLANE:
        plane_color = rl.Color{60, 200, 200, 200}  // Cyan-ish blend
    case:
        plane_color = rl.ColorAlpha(rl.GRAY, 0.8)  // Fallback
    }
    
    if is_active {
        plane_color = rl.ColorAlpha(rl.GOLD, 0.9)
    }
    
    // Convert screen radius to world space for stable positioning
    world_size := calculate_world_radius_for_screen_size(position, screen_radius, camera)
    
    // Position plane handle at the corner of the invisible cube
    plane_offset := world_size * 0.6 // Match arrow start
    center := position + direction * plane_offset
    
    // Determine normal for the quad's orientation
    normal: rl.Vector3
    #partial switch handle {
    case .XY_PLANE:
        normal = rl.Vector3{0, 0, 1}  // Z normal for XY plane
    case .XZ_PLANE:
        normal = rl.Vector3{0, 1, 0} // Y normal for XZ plane
    case .YZ_PLANE:
        normal = rl.Vector3{1, 0, 0}  // X normal for YZ plane
    case:
        normal = rl.Vector3{0, 0, 1}  // Default to Z normal
    }
    
    quad_size := world_size * 0.4

    // Create two perpendicular vectors to the normal for the quad
    up_vec := rl.Vector3{0, 1, 0}
    if math.abs(rl.Vector3DotProduct(normal, up_vec)) > 0.9 {
        up_vec = rl.Vector3{1, 0, 0}  // Use right vector if normal is too close to up
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
    
    // Draw triangles to form the quad in 2D (double-sided)
    rl.DrawTriangle(v1_2d, v2_2d, v3_2d, plane_color)
    rl.DrawTriangle(v1_2d, v3_2d, v4_2d, plane_color)
    // Draw back-facing triangles to make it double-sided
    rl.DrawTriangle(v3_2d, v2_2d, v1_2d, plane_color)
    rl.DrawTriangle(v4_2d, v3_2d, v1_2d, plane_color)
}

// Draws a single gizmo axis in screen-space with solid cone tip and subtle glow
draw_axis_arrow_2d :: proc(state: ^Gizmo_State, axis: Handle_Type, camera: rl.Camera3D, position: rl.Vector3) {
    axis_index := int(axis) - 1
    is_active := state.hovered_handle == axis || (state.is_dragging && state.drag_handle == axis)
    color := is_active ? AXIS_COLORS_HOVER[axis_index] : AXIS_COLORS[axis_index]

    line_thickness :: 6.0
    cone_base_radius :: 10.0
    cone_height :: 26.0
    
    dir := state.axes_2d[axis_index]
    
    // For cube-based positioning, use stable screen-space distances
    cube_face_distance := state.base_size * 0.4  // Distance to cube face
    total_axis_length := state.base_size * 0.85   // Total axis length from center
    
    // Calculate positions - arrow extends from cube face outward
    line_start_pos := state.center_2d + dir * cube_face_distance
    line_end_pos := state.center_2d + dir * (total_axis_length - cone_height)
    cone_tip_pos := state.center_2d + dir * total_axis_length
    
    // Draw subtle glow effect first (behind main elements)
    glow_color := rl.Color{255, 255, 200, 90}  // Very subtle yellow glow
    rl.DrawLineEx(line_start_pos, line_end_pos, line_thickness + 2, glow_color)
    draw_solid_cone_2d_with_glow(line_end_pos, cone_tip_pos, cone_base_radius + 1, glow_color)
    
    // Draw main axis line (from cube face to cone base)
    rl.DrawLineEx(line_start_pos, line_end_pos, line_thickness, color)
    
    // Draw solid cone tip
    draw_solid_cone_2d(line_end_pos, cone_tip_pos, cone_base_radius, color)
}

// Helper function to draw a solid cone in 2D screen space
draw_solid_cone_2d :: proc(base_center: rl.Vector2, tip: rl.Vector2, base_radius: f32, color: rl.Color) {
    // Calculate direction and perpendicular vectors
    dir := rl.Vector2Normalize(tip - base_center)
    perp := rl.Vector2{-dir.y, dir.x}
    
    // Number of segments for the cone (more = smoother)
    segments := 8
    
    // Draw cone as a fan of triangles from tip to base circle
    for i in 0..<segments {
        angle1 := f32(i) * 2.0 * math.PI / f32(segments)
        angle2 := f32(i + 1) * 2.0 * math.PI / f32(segments)
        
        // Calculate points on the base circle
        offset1 := perp * math.cos(angle1) * base_radius + rl.Vector2{dir.y, -dir.x} * math.sin(angle1) * base_radius
        offset2 := perp * math.cos(angle2) * base_radius + rl.Vector2{dir.y, -dir.x} * math.sin(angle2) * base_radius
        
        point1 := base_center + offset1
        point2 := base_center + offset2
        
        // Draw triangle from tip to two points on base
        rl.DrawTriangle(tip, point1, point2, color)
    }
    
    // Draw the base circle to close the cone
    rl.DrawCircleV(base_center, base_radius, color)
}

// Helper function to draw glow version of cone (slightly larger, more transparent)
draw_solid_cone_2d_with_glow :: proc(base_center: rl.Vector2, tip: rl.Vector2, base_radius: f32, color: rl.Color) {
    // Calculate direction and perpendicular vectors
    dir := rl.Vector2Normalize(tip - base_center)
    perp := rl.Vector2{-dir.y, dir.x}
    
    // Number of segments for the cone (more = smoother)
    segments := 8
    
    // Draw cone as a fan of triangles from tip to base circle
    for i in 0..<segments {
        angle1 := f32(i) * 2.0 * math.PI / f32(segments)
        angle2 := f32(i + 1) * 2.0 * math.PI / f32(segments)
        
        // Calculate points on the base circle
        offset1 := perp * math.cos(angle1) * base_radius + rl.Vector2{dir.y, -dir.x} * math.sin(angle1) * base_radius
        offset2 := perp * math.cos(angle2) * base_radius + rl.Vector2{dir.y, -dir.x} * math.sin(angle2) * base_radius
        
        point1 := base_center + offset1
        point2 := base_center + offset2
        
        // Draw triangle from tip to two points on base
        rl.DrawTriangle(tip, point1, point2, color)
    }
    
    // Draw the base circle to close the cone
    rl.DrawCircleV(base_center, base_radius, color)
}

// Draws a single plane handle in screen-space
draw_plane_handle_2d :: proc(state: ^Gizmo_State, handle: Handle_Type) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    
    // Determine plane color based on which axes it combines
    plane_color: rl.Color
    #partial switch handle {
    case .XY_PLANE: 
        // Mix red (X) and green (Y) with transparency
        plane_color = rl.Color{200, 200, 60, 220}  // Yellow-ish blend
    case .XZ_PLANE:
        // Mix red (X) and blue (Z) with transparency  
        plane_color = rl.Color{200, 60, 200, 220}  // Purple-ish blend
    case .YZ_PLANE:
        // Mix green (Y) and blue (Z) with transparency
        plane_color = rl.Color{60, 200, 200, 220}  // Cyan-ish blend
    case:
        plane_color = rl.ColorAlpha(rl.GRAY, 0.8)  // Fallback
    }
    
    if is_active {
        plane_color = rl.ColorAlpha(rl.GOLD, 0.8)
    }
    
    // Use cube-based positioning for stable plane handle placement
    cube_face_distance :: 0.3   // Position closer to object center
    plane_size :: 0.15           // Smaller plane handles for cube-based approach
    
    // Select appropriate axes based on plane
    axis1_idx, axis2_idx: int
    #partial switch handle {
    case .XY_PLANE: axis1_idx, axis2_idx = 0, 1  // X, Y
    case .XZ_PLANE: axis1_idx, axis2_idx = 0, 2  // X, Z  
    case .YZ_PLANE: axis1_idx, axis2_idx = 1, 2  // Y, Z
    case: return
    }
    
    dir1 := state.axes_2d[axis1_idx]
    dir2 := state.axes_2d[axis2_idx]
    
    // Calculate plane quad vertices using cube-based positioning
    offset := (dir1 + dir2) * (state.base_size * cube_face_distance)
    size1 := dir1 * (state.base_size * plane_size)
    size2 := dir2 * (state.base_size * plane_size)
    
    p1 := state.center_2d + offset
    p2 := p1 + size1
    p3 := p2 + size2
    p4 := p1 + size2
    
    // Draw filled quad with double-sided triangles (clockwise and counter-clockwise)
    // First triangle (clockwise)
    rl.DrawTriangle(p1, p2, p4, plane_color)
    // Same triangle (counter-clockwise)
    rl.DrawTriangle(p1, p4, p2, plane_color)
    
    // Second triangle (clockwise)
    rl.DrawTriangle(p2, p3, p4, plane_color)
    // Same triangle (counter-clockwise)
    rl.DrawTriangle(p2, p4, p3, plane_color)
    
    // Draw outline for better visibility
    outline_color := rl.ColorAlpha(is_active ? rl.GOLD : rl.YELLOW, 0.6)
    rl.DrawLineEx(p1, p2, 2.0, outline_color)
    rl.DrawLineEx(p2, p3, 2.0, outline_color)
    rl.DrawLineEx(p3, p4, 2.0, outline_color)
    rl.DrawLineEx(p4, p1, 2.0, outline_color)
}

// Draw rotation gizmo using sphere-based approach (same visual style as local rotation)
draw_rotation_gizmo :: proc(state: ^Gizmo_State, position: rl.Vector3, camera: rl.Camera3D) {
    // GLOBAL rotation: Same beautiful sphere approach as local rotation
    // - Three circles positioned on invisible sphere around object
    // - Only front-facing halves visible (eliminates overlap issues)
    // - Circles aligned with WORLD coordinate system (not object)
    // - Plus white camera-relative circle (outermost)
    
    sphere_radius := state.base_size * 1.1   // All circles same size on the sphere
    view_radius := state.base_size * 1.4     // White circle slightly larger
    
    // Draw white camera-relative circle first (outermost)
    draw_fixed_screen_circle(state, .VIEW_ROTATION, view_radius)
    
    // Draw sphere-based half-circles for each WORLD axis
    if .X in state.active_axes {
        draw_world_sphere_half_circle(state, .X_ROTATION, sphere_radius, 0, position, camera) // Red X (world)
    }
    
    if .Y in state.active_axes {
        draw_world_sphere_half_circle(state, .Y_ROTATION, sphere_radius, 1, position, camera) // Green Y (world)
    }
    
    if .Z in state.active_axes {
        draw_world_sphere_half_circle(state, .Z_ROTATION, sphere_radius, 2, position, camera) // Blue Z (world)
    }
}

// Draw rotation ring for specific axis
draw_rotation_ring_2d :: proc(state: ^Gizmo_State, handle: Handle_Type, axis_idx: int, radius: f32) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := get_handle_color(handle, is_active, is_active)
    
    // Calculate ring orientation based on axis
    // For screen-space rings, we need to project the rotation plane onto screen space
    center := state.center_2d
    segments := 64  // Number of line segments for smooth circle
    thickness := f32(3.0)
    
    if is_active {
        thickness = 5.0
    }
    
    // Draw ring as connected line segments
    angle_step := 2.0 * math.PI / f32(segments)
    
    for i in 0..<segments {
        angle1 := f32(i) * angle_step
        angle2 := f32(i + 1) * angle_step
        
        // Calculate ring points based on axis orientation
        p1, p2: rl.Vector2
        
        switch axis_idx {
        case 0: // X-axis rotation (YZ plane)
            p1 = get_rotated_ring_point(state, center, radius, angle1, 1, 2)
            p2 = get_rotated_ring_point(state, center, radius, angle2, 1, 2)
        case 1: // Y-axis rotation (XZ plane)  
            p1 = get_rotated_ring_point(state, center, radius, angle1, 0, 2)
            p2 = get_rotated_ring_point(state, center, radius, angle2, 0, 2)
        case 2: // Z-axis rotation (XY plane)
            p1 = get_rotated_ring_point(state, center, radius, angle1, 0, 1)
            p2 = get_rotated_ring_point(state, center, radius, angle2, 0, 1)
        }
        
        rl.DrawLineEx(p1, p2, thickness, color)
    }
}

// Helper to get rotated ring point in screen space
get_rotated_ring_point :: proc(state: ^Gizmo_State, center: rl.Vector2, radius: f32, angle: f32, axis1_idx: int, axis2_idx: int) -> rl.Vector2 {
    cos_a := math.cos(angle)
    sin_a := math.sin(angle)
    
    // Use screen-space axis directions for ring orientation
    axis1_dir := state.axes_2d[axis1_idx]
    axis2_dir := state.axes_2d[axis2_idx]
    
    offset := axis1_dir * (cos_a * radius) + axis2_dir * (sin_a * radius)
    return center + offset
}

// Draw scale gizmo with EXACT same size as rotation gizmo
draw_scale_gizmo :: proc(state: ^Gizmo_State, camera: rl.Camera3D, position: rl.Vector3) {
    // Use EXACT same sizing as rotation gizmo - screen radius directly
    screen_radius := state.base_size * 0.8   // EXACTLY same as rotation gizmo
    
    // Draw 3D axes with cube handles - MUCH BIGGER
    if .X in state.active_axes {
        draw_3d_scale_handle(state, .X_SCALE, position, rl.Vector3{1, 0, 0}, screen_radius, camera)
    }
    if .Y in state.active_axes {
        draw_3d_scale_handle(state, .Y_SCALE, position, rl.Vector3{0, 1, 0}, screen_radius, camera)
    }
    if .Z in state.active_axes {
        draw_3d_scale_handle(state, .Z_SCALE, position, rl.Vector3{0, 0, 1}, screen_radius, camera)
    }
    
    // Draw uniform scale handle at center - MUCH BIGGER
    draw_3d_uniform_scale_handle(state, position, screen_radius, camera)
}

// Draw stable scale handle using 3D-calculated positions but 2D rendering - MUCH BIGGER
draw_3d_scale_handle :: proc(state: ^Gizmo_State, handle: Handle_Type, position: rl.Vector3, direction: rl.Vector3, screen_radius: f32, camera: rl.Camera3D, draw_line := true) {
    axis_idx := int(handle) - int(Handle_Type.X_SCALE)  // Convert to 0-2 range
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := is_active ? AXIS_COLORS_HOVER[axis_idx] : AXIS_COLORS[axis_idx]
    
    // Convert screen radius to world space for stable positioning
    world_size := calculate_world_radius_for_screen_size(position, screen_radius, camera)
    
    // Position scale handle at cube edge
    cube_edge_offset := world_size * 1.6   // Distance from center to cube edge
    
    // Calculate 3D positions
    line_end := position + direction * (cube_edge_offset - world_size * 0.1)
    cube_center := position + direction * cube_edge_offset
    
    // Project to 2D screen coordinates
    position_2d := rl.GetWorldToScreen(position, camera)
    line_end_2d := rl.GetWorldToScreen(line_end, camera)
    cube_center_2d := rl.GetWorldToScreen(cube_center, camera)
    
    // Draw 2D line from object center to cube - more consistent with other gizmos
    if draw_line {
        line_thickness := f32(3.0)
        if is_active {
            line_thickness = 5.0
        }
        rl.DrawLineEx(position_2d, line_end_2d, line_thickness, color)
    }
    
    // Draw 2D rectangle as cube handle - more consistent with other gizmos
    cube_screen_size := f32(25.0)  // More consistent screen-space size
    cube_rect := rl.Rectangle{
        cube_center_2d.x - cube_screen_size/2,
        cube_center_2d.y - cube_screen_size/2,
        cube_screen_size,
        cube_screen_size,
    }
    
    rl.DrawRectangleRec(cube_rect, color)
    rl.DrawRectangleLinesEx(cube_rect, 2, rl.BLACK)
}

// Draw stable uniform scale handle using 3D-calculated positions but 2D rendering - MUCH BIGGER
draw_3d_uniform_scale_handle :: proc(state: ^Gizmo_State, position: rl.Vector3, screen_radius: f32, camera: rl.Camera3D) {
    is_active := state.hovered_handle == .UNIFORM_SCALE || (state.is_dragging && state.drag_handle == .UNIFORM_SCALE)
    color := is_active ? rl.YELLOW : rl.WHITE
    
    // Project object center to screen
    center_2d := rl.GetWorldToScreen(position, camera)
    
    // Draw 2D rectangle as uniform scale handle - MUCH BIGGER
    center_size := f32(28.0)  // MUCH bigger screen-space size
    center_rect := rl.Rectangle{
        center_2d.x - center_size/2,
        center_2d.y - center_size/2,
        center_size,
        center_size,
    }
    
    rl.DrawRectangleRec(center_rect, color)
    rl.DrawRectangleLinesEx(center_rect, 3, rl.BLACK)  // Thicker outline
}

// Draw scale handle at axis end
draw_scale_handle_2d :: proc(state: ^Gizmo_State, handle: Handle_Type, axis_idx: int, handle_size: f32) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := get_handle_color(handle, is_active, is_active)
    
    // Use cube-based positioning for stable scale handle placement
    cube_handle_distance := state.base_size * 0.75  // Position scale handles on cube edges
    handle_pos := state.center_2d + state.axes_2d[axis_idx] * cube_handle_distance
    
    // Draw as filled rectangle (cube representation in 2D)
    handle_rect := rl.Rectangle{
        handle_pos.x - handle_size/2,
        handle_pos.y - handle_size/2,
        handle_size,
        handle_size,
    }
    
    rl.DrawRectangleRec(handle_rect, color)
    rl.DrawRectangleLinesEx(handle_rect, 2, rl.BLACK)
}

// Draw uniform scale handle at center
draw_uniform_scale_handle_2d :: proc(state: ^Gizmo_State, handle_size: f32) {
    is_active := state.hovered_handle == .UNIFORM_SCALE || (state.is_dragging && state.drag_handle == .UNIFORM_SCALE)
    color := get_handle_color(.UNIFORM_SCALE, is_active, is_active)
    
    center_size := handle_size * 1.5  // Slightly larger for visibility
    
    handle_rect := rl.Rectangle{
        state.center_2d.x - center_size/2,
        state.center_2d.y - center_size/2,
        center_size,
        center_size,
    }
    
    rl.DrawRectangleRec(handle_rect, color)
    rl.DrawRectangleLinesEx(handle_rect, 2, rl.BLACK)
}

// Draw thin line from center to scale handle
draw_scale_line_2d :: proc(state: ^Gizmo_State, axis_idx: int) {
    // Use cube-based positioning for scale line consistency
    cube_face_distance := state.base_size * 0.4   // Start from cube face
    cube_handle_distance := state.base_size * 0.75 // End at scale handle position
    
    line_start := state.center_2d + state.axes_2d[axis_idx] * cube_face_distance
    line_end := state.center_2d + state.axes_2d[axis_idx] * cube_handle_distance
    
    // Get appropriate handle type based on axis index
    handle_type: Handle_Type
    switch axis_idx {
    case 0: handle_type = .X_SCALE
    case 1: handle_type = .Y_SCALE
    case 2: handle_type = .Z_SCALE
    case: handle_type = .X_SCALE  // Fallback
    }
    
    color := get_handle_color(handle_type, false, false)
    color.a = 128  // Semi-transparent
    
    rl.DrawLineEx(line_start, line_end, 2.0, color)
}

// Draw fixed screen-space circle (for Z-rotation trackball)
draw_fixed_screen_circle :: proc(state: ^Gizmo_State, handle: Handle_Type, radius: f32) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := get_handle_color(handle, is_active, is_active)
    
    center := state.center_2d
    segments := 64
    thickness := f32(3.0)
    
    if is_active {
        thickness = 5.0
    }
    
    // Draw perfect circle in screen space
    angle_step := 2.0 * math.PI / f32(segments)
    
    for i in 0..<segments {
        angle1 := f32(i) * angle_step
        angle2 := f32(i + 1) * angle_step
        
        p1 := center + rl.Vector2{math.cos(angle1) * radius, math.sin(angle1) * radius}
        p2 := center + rl.Vector2{math.cos(angle2) * radius, math.sin(angle2) * radius}
        
        rl.DrawLineEx(p1, p2, thickness, color)
    }
}

// Draw world-axis-aligned circle (for X and Y rotation)
draw_world_axis_circle :: proc(state: ^Gizmo_State, handle: Handle_Type, radius: f32, axis_idx: int) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := get_handle_color(handle, is_active, is_active)
    
    center := state.center_2d
    segments := 64
    thickness := f32(3.0)
    
    if is_active {
        thickness = 5.0
    }
    
    // Calculate the two perpendicular axes that form this rotation plane
    axis1_idx, axis2_idx: int
    switch axis_idx {
    case 0: // X-axis rotation (YZ plane)
        axis1_idx, axis2_idx = 1, 2  // Y and Z axes
    case 1: // Y-axis rotation (XZ plane)  
        axis1_idx, axis2_idx = 0, 2  // X and Z axes
    case: // Default to XY plane
        axis1_idx, axis2_idx = 0, 1  // X and Y axes
    }
    
    // Get screen-space directions for the two axes that form this rotation plane
    axis1_dir := state.axes_2d[axis1_idx]
    axis2_dir := state.axes_2d[axis2_idx]
    
    // Draw circle/ellipse in screen space using these two directions
    angle_step := 2.0 * math.PI / f32(segments)
    
    for i in 0..<segments {
        angle1 := f32(i) * angle_step  
        angle2 := f32(i + 1) * angle_step
        
        // Calculate points using the two axis directions to form the ellipse
        p1 := center + axis1_dir * (math.cos(angle1) * radius) + axis2_dir * (math.sin(angle1) * radius)
        p2 := center + axis1_dir * (math.cos(angle2) * radius) + axis2_dir * (math.sin(angle2) * radius)
        
        rl.DrawLineEx(p1, p2, thickness, color)
    }
}



// Draw world-space half-circle positioned on invisible sphere (world axes) 
draw_world_sphere_half_circle :: proc(state: ^Gizmo_State, handle: Handle_Type, radius: f32, axis_idx: int, position: rl.Vector3, camera: rl.Camera3D) {
    is_active := state.hovered_handle == handle || (state.is_dragging && state.drag_handle == handle)
    color := get_handle_color(handle, is_active, is_active)
    
    thickness := f32(3.0)
    if is_active {
        thickness = 5.0
    }
    
    // Calculate 3D world radius needed to achieve the desired screen radius
    world_sphere_radius := calculate_world_radius_for_screen_size(position, radius, camera)
    
    // Use world axes (not object-relative)
    world_axes: [3]rl.Vector3 = {
        rl.Vector3{1, 0, 0}, // World X
        rl.Vector3{0, 1, 0}, // World Y
        rl.Vector3{0, 0, 1}, // World Z
    }
    
    // Get the two perpendicular axes for this rotation circle
    perp1, perp2: rl.Vector3
    switch axis_idx {
    case 0: // X rotation circle (rotates around world X-axis)
        perp1 = world_axes[1]  // World Y
        perp2 = world_axes[2]  // World Z
    case 1: // Y rotation circle (rotates around world Y-axis)
        perp1 = world_axes[0]  // World X
        perp2 = world_axes[2]  // World Z
    case 2: // Z rotation circle (rotates around world Z-axis)
        perp1 = world_axes[0]  // World X
        perp2 = world_axes[1]  // World Y
    case: return
    }
    
    // Calculate camera direction for proper front-face culling
    camera_dir := rl.Vector3Normalize(camera.position - position)
    
    // Draw the circle, but only the front-facing half
    segments := 48
    angle_step := 2.0 * math.PI / f32(segments)
    
    prev_valid := false
    prev_screen: rl.Vector2
    
    for i in 0..=segments {  // Include wraparound
        angle := f32(i) * angle_step
        
        // Calculate 3D point on circle
        circle_point := position + perp1 * math.cos(angle) * world_sphere_radius + perp2 * math.sin(angle) * world_sphere_radius
        
        // Check if this point is on the front face of the invisible sphere
        to_point := rl.Vector3Normalize(circle_point - position)
        dot_with_camera := rl.Vector3DotProduct(to_point, camera_dir)
        
        if dot_with_camera > 0.0 {  // Front-facing
            screen_point := rl.GetWorldToScreen(circle_point, camera)
            
            // Draw line segment if we have a previous valid point
            if prev_valid {
                rl.DrawLineEx(prev_screen, screen_point, thickness, color)
            }
            
            prev_screen = screen_point
            prev_valid = true
        } else {
            prev_valid = false  // Break line segments for back faces
        }
    }
}
