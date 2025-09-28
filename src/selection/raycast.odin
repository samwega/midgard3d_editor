package selection

import "../core"
import "../scene"
import rl "vendor:raylib"
import "core:math"
import "core:fmt"

// Convert mouse position to world ray
get_mouse_ray :: proc(mouse_pos: rl.Vector2, camera: rl.Camera3D) -> rl.Ray {
    return rl.GetScreenToWorldRay(mouse_pos, camera)
}


// Check if ray hits an object's bounding box
check_ray_collision_box :: proc(ray: rl.Ray, bounds: rl.BoundingBox) -> bool {
    collision := rl.GetRayCollisionBox(ray, bounds)
    return collision.hit
}

// Get bounding box for a scene object based on its type and transform
// This creates a world-space axis-aligned bounding box that accounts for rotation
get_object_bounding_box :: proc(object: ^scene.Scene_Object) -> rl.BoundingBox {
    pos := object.transform.position
    rotation := object.transform.rotation  // Euler angles in degrees
    scale := object.transform.scale
    
    // Create transformation matrix matching the rendering system
    transform_matrix := rl.Matrix(1)
    transform_matrix = transform_matrix * rl.MatrixTranslate(pos.x, pos.y, pos.z)
    transform_matrix = transform_matrix * rl.MatrixRotateZ(rotation.z * rl.DEG2RAD)
    transform_matrix = transform_matrix * rl.MatrixRotateY(rotation.y * rl.DEG2RAD) 
    transform_matrix = transform_matrix * rl.MatrixRotateX(rotation.x * rl.DEG2RAD)
    transform_matrix = transform_matrix * rl.MatrixScale(scale.x, scale.y, scale.z)
    
    // Define local-space bounding box based on object type
    local_min, local_max: rl.Vector3
    
    #partial switch object.object_type {
        case .CUBE:
            // Unit cube from -0.5 to 0.5 in each axis
            local_min = {-0.5, -0.5, -0.5}
            local_max = {0.5, 0.5, 0.5}
            
        case .SPHERE:
            // Unit sphere from -1 to 1 in each axis (radius = 1)
            local_min = {-1, -1, -1}
            local_max = {1, 1, 1}
            
        case .CYLINDER:
            // Unit cylinder: radius = 1, height = 1, centered at origin
            local_min = {-1, -0.5, -1}
            local_max = {1, 0.5, 1}
            
        case .MESH:
            // Use mesh bounds if available
            if object.mesh_data != nil {
                mesh_bounds := object.mesh_data.bounds
                
                // Calculate bounds size to detect oversized collision boxes
                size_x := mesh_bounds.max.x - mesh_bounds.min.x
                size_y := mesh_bounds.max.y - mesh_bounds.min.y  
                size_z := mesh_bounds.max.z - mesh_bounds.min.z
                
                // If the mesh bounds are very large (> 10 units in any dimension),
                // apply a reduction factor to create tighter collision bounds
                LARGE_MESH_THRESHOLD :: 10.0
                BOUNDS_REDUCTION_FACTOR :: 0.6  // Use 60% of the original bounds
                
                if size_x > LARGE_MESH_THRESHOLD || size_z > LARGE_MESH_THRESHOLD {
                    // Calculate center point
                    center := rl.Vector3{
                        (mesh_bounds.min.x + mesh_bounds.max.x) * 0.5,
                        (mesh_bounds.min.y + mesh_bounds.max.y) * 0.5,
                        (mesh_bounds.min.z + mesh_bounds.max.z) * 0.5,
                    }
                    
                    // Reduce bounds around center point
                    half_size_x := size_x * 0.5 * BOUNDS_REDUCTION_FACTOR
                    half_size_y := size_y * 0.5  // Keep Y bounds unchanged (height)
                    half_size_z := size_z * 0.5 * BOUNDS_REDUCTION_FACTOR
                    
                    local_min = rl.Vector3{
                        center.x - half_size_x,
                        center.y - half_size_y,
                        center.z - half_size_z,
                    }
                    local_max = rl.Vector3{
                        center.x + half_size_x,
                        center.y + half_size_y,
                        center.z + half_size_z,
                    }
                    
                } else {
                    // Use original bounds for reasonably-sized meshes
                    local_min = mesh_bounds.min
                    local_max = mesh_bounds.max
                }
            } else {
                // Fallback: unit cube
                local_min = {-0.5, -0.5, -0.5}
                local_max = {0.5, 0.5, 0.5}
            }
    }
    
    // Transform the 8 corners of the local bounding box to world space
    corners := [8]rl.Vector3{
        {local_min.x, local_min.y, local_min.z},  // min corner
        {local_max.x, local_min.y, local_min.z},  // +X
        {local_min.x, local_max.y, local_min.z},  // +Y
        {local_min.x, local_min.y, local_max.z},  // +Z
        {local_max.x, local_max.y, local_min.z},  // +X+Y
        {local_max.x, local_min.y, local_max.z},  // +X+Z
        {local_min.x, local_max.y, local_max.z},  // +Y+Z
        {local_max.x, local_max.y, local_max.z},  // max corner
    }
    
    // Transform all corners and find world-space min/max
    world_min := rl.Vector3{math.F32_MAX, math.F32_MAX, math.F32_MAX}
    world_max := rl.Vector3{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
    
    for corner in corners {
        world_corner := rl.Vector3Transform(corner, transform_matrix)
        
        world_min.x = min(world_min.x, world_corner.x)
        world_min.y = min(world_min.y, world_corner.y)
        world_min.z = min(world_min.z, world_corner.z)
        
        world_max.x = max(world_max.x, world_corner.x)
        world_max.y = max(world_max.y, world_corner.y)
        world_max.z = max(world_max.z, world_corner.z)
    }
    
    
    return rl.BoundingBox{world_min, world_max}
}

// Find the closest object that intersects with the given ray
// Returns object ID if hit, -1 if no hit
raycast_scene :: proc(ray: rl.Ray, scene_data: ^scene.Scene) -> int {
    closest_distance := f32(math.F32_MAX)
    closest_id := -1
    
    // Debug: Track if ANY collision detection works
    any_collision_tested := false
    any_collision_hit := false
    
    for &object in scene_data.objects {
        bounds := get_object_bounding_box(&object)
        any_collision_tested = true
        
        // Use Raylib's standard collision detection
        collision := rl.GetRayCollisionBox(ray, bounds)
        hit, distance := collision.hit, collision.distance
        
        if hit {
            any_collision_hit = true
            if distance < closest_distance {
                closest_distance = distance
                closest_id = object.id
            }
        }
    }
    
    // Raycast debugging removed - issue was continuous raycasting during flying mode
    
    return closest_id
}

// Convenience function: cast ray from mouse position and find intersected object
raycast_from_mouse :: proc(mouse_pos: rl.Vector2, camera: rl.Camera3D, scene_data: ^scene.Scene) -> int {
    ray := get_mouse_ray(mouse_pos, camera)
    return raycast_scene(ray, scene_data)
}