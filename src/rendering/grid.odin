package rendering

import rl "vendor:raylib"
import "core:math"

// Single unified grid system with dynamic line emphasis
draw_adaptive_grid :: proc(camera_distance: f32, camera_pos: rl.Vector3) {
    camera_height := math.abs(camera_pos.y)
    
    // Always draw 1m grid, but emphasize 8m lines with different opacity/color
    draw_unified_grid(camera_pos, camera_height)
}

// Unified grid system - single 1m grid with emphasized major lines
draw_unified_grid :: proc(camera_pos: rl.Vector3, camera_height: f32) {
    max_radius := f32(150)
    base_grid_color := rl.Color{140, 140, 130, 235}     // 1x1m grid color
    major_grid_color := rl.Color{105, 100, 107, 235}    // 8x8m grid color
    
    camera_x := camera_pos.x
    camera_z := camera_pos.z
    
    // Calculate 1m grid bounds
    start_x := math.floor((camera_x - max_radius) / 1.0) * 1.0
    end_x := math.ceil((camera_x + max_radius) / 1.0) * 1.0
    start_z := math.floor((camera_z - max_radius) / 1.0) * 1.0
    end_z := math.ceil((camera_z + max_radius) / 1.0) * 1.0
    
    // Detail grid fades out at height, major grid stays visible
    detail_alpha := math.max(0.0, 1.0 - camera_height / 16.0) * 0.6
    major_alpha := f32(1.0)
    
    // Draw all X lines with dynamic alpha based on importance
    for x := start_x; x <= end_x; x += 1.0 {
        dx := x - camera_x
        if math.abs(dx) <= max_radius {
            // Determine if this is a major line (8m interval)
            is_major := math.mod(x, 8.0) == 0
            
            // Choose color and alpha
            color: rl.Color
            if is_major {
                color = rl.ColorAlpha(major_grid_color, major_alpha)
            } else {
                if detail_alpha <= 0.01 do continue  // Skip detail lines when too faded
                color = rl.ColorAlpha(base_grid_color, detail_alpha)
            }
            
            // Calculate Z range where this X line is within circular radius
            remaining_radius := math.sqrt(max_radius * max_radius - dx * dx)
            clip_start_z := math.max(start_z, camera_z - remaining_radius)
            clip_end_z := math.min(end_z, camera_z + remaining_radius)
            
            if clip_start_z <= clip_end_z {
                rl.DrawLine3D({x, 0, clip_start_z}, {x, 0, clip_end_z}, color)
            }
        }
    }
    
    // Draw all Z lines with dynamic alpha based on importance
    for z := start_z; z <= end_z; z += 1.0 {
        dz := z - camera_z
        if math.abs(dz) <= max_radius {
            // Determine if this is a major line (8m interval)
            is_major := math.mod(z, 8.0) == 0
            
            // Choose color and alpha
            color: rl.Color
            if is_major {
                color = rl.ColorAlpha(major_grid_color, major_alpha)
            } else {
                if detail_alpha <= 0.01 do continue  // Skip detail lines when too faded
                color = rl.ColorAlpha(base_grid_color, detail_alpha)
            }
            
            // Calculate X range where this Z line is within circular radius
            remaining_radius := math.sqrt(max_radius * max_radius - dz * dz)
            clip_start_x := math.max(start_x, camera_x - remaining_radius)
            clip_end_x := math.min(end_x, camera_x + remaining_radius)
            
            if clip_start_x <= clip_end_x {
                rl.DrawLine3D({clip_start_x, 0, z}, {clip_end_x, 0, z}, color)
            }
        }
    }
}

// Helper function for infinite coordinate axes (like Godot)
draw_infinite_axes :: proc(camera_distance: f32) {
    // Make axes visible from far distances
    axis_extent := math.max(camera_distance * 2, 1000.0)
    
    
    // X-axis (Red) - horizontal line on grid plane
    rl.DrawLine3D(
        {-axis_extent, 0, 0},    // Start point
        {axis_extent, 0, 0},     // End point
        rl.RED,
    )
    
    // Y-axis (Green) - vertical line through grid plane
    rl.DrawLine3D(
        {0, -axis_extent, 0},             // Start at grid level
        {0, axis_extent, 0},              // End point 
        rl.GREEN,
    )
    
    // Z-axis (Blue) - depth line on grid plane
    rl.DrawLine3D(
        {0, 0, -axis_extent},    // Start point
        {0, 0, axis_extent},     // End point
        rl.BLUE,
    )
}