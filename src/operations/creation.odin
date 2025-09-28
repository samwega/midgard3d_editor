package operations

import "../scene"
import "../core"
import "../selection"
import rl "vendor:raylib"
import "core:fmt"
import "core:path/filepath"

// Creation menu state
Creation_Menu_State :: struct {
    visible: bool,
    position: rl.Vector2,  // Screen position for menu
}

creation_menu_state: Creation_Menu_State

// Show creation menu at mouse position
show_creation_menu :: proc(mouse_pos: rl.Vector2) {
    creation_menu_state.visible = true
    creation_menu_state.position = mouse_pos
}

// Hide creation menu
hide_creation_menu :: proc() {
    creation_menu_state.visible = false
}

// Create a new primitive at world position
create_primitive :: proc(scene_data: ^scene.Scene, 
                        object_type: core.Object_Type, 
                        position: rl.Vector3,
                        name_prefix: string = "") -> int {
    
    // Generate appropriate name
    name: string
    if name_prefix != "" {
        name = fmt.aprintf("%s_%d", name_prefix, scene_data.next_id)
    } else {
        switch object_type {
        case .CUBE:
            name = fmt.aprintf("Cube_%d", scene_data.next_id)
        case .SPHERE:
            name = fmt.aprintf("Sphere_%d", scene_data.next_id)
        case .CYLINDER:
            name = fmt.aprintf("Cylinder_%d", scene_data.next_id)
        case .MESH:
            name = fmt.aprintf("Mesh_%d", scene_data.next_id)
        }
    }
    
    // Default properties for new objects
    rotation := rl.Vector3{0, 0, 0}
    scale := rl.Vector3{1, 1, 1}
    color := get_default_color(object_type)
    
    // Add to scene using existing add_object
    scene.add_object(scene_data, object_type, position, rotation, scale, color, name)
    
    // Return the ID of the newly created object
    return scene_data.next_id - 1
}

// Get default color for object type
get_default_color :: proc(object_type: core.Object_Type) -> rl.Color {
    switch object_type {
    case .CUBE:
        return {51, 141, 151, 255}         // Turquoise (TEXT_MUTED)
    case .SPHERE:
        return {190, 74, 112, 255}         // Fuchsia (ACCENT)
    case .CYLINDER:
        return {184, 92, 64, 255}          // Light text color (TEXT)
    case .MESH:
        return rl.WHITE                    // Meshes use material colors
    }
    return rl.WHITE
}

// Create object at camera focus point
create_at_cursor :: proc(scene_data: ^scene.Scene, 
                        camera: rl.Camera3D, 
                        object_type: core.Object_Type) -> int {
    // Place new object 5 units in front of camera
    forward := rl.Vector3Normalize(camera.target - camera.position)
    spawn_position := camera.position + forward * 5.0
    
    return create_primitive(scene_data, object_type, spawn_position)
}

// Duplicate an existing object
duplicate_object :: proc(scene_data: ^scene.Scene, original_id: int) -> int {
    // Find original object
    original: ^scene.Scene_Object = nil
    for &obj in scene_data.objects {
        if obj.id == original_id {
            original = &obj
            break
        }
    }
    
    if original == nil {
        return -1  // Object not found
    }
    
    // Create duplicate with offset position
    offset := rl.Vector3{1, 0, 1}  // Offset by 1 unit in X and Z
    new_position := original.transform.position + offset
    
    // Generate name for duplicate
    duplicate_name := fmt.aprintf("%s_copy", original.name)
    
    // Add new object with same properties as original
    scene.add_object(scene_data, 
                    original.object_type,
                    new_position,
                    original.transform.rotation,
                    original.transform.scale,
                    original.color,
                    duplicate_name)
    
    return scene_data.next_id - 1
}

// Create a mesh object from imported data
create_mesh_object :: proc(scene_data: ^scene.Scene, 
                          mesh_data: ^core.Mesh_Data,
                          position: rl.Vector3,
                          rotation: rl.Vector3 = {0, 0, 0},
                          scale: rl.Vector3 = {1, 1, 1},
                          name: string = "") -> int {
    
    // Generate name from mesh data if not provided
    object_name: string
    if name != "" {
        object_name = name
    } else {
        // Extract filename from path for default name
        filename := filepath.base(mesh_data.source_file)
        object_name = fmt.aprintf("%s_%d", filename, scene_data.next_id)
    }
    
    // Create scene object with mesh data
    object := scene.Scene_Object {
        id = scene_data.next_id,
        name = object_name,
        object_type = .MESH,
        transform = core.Transform {
            position = position,
            rotation = rotation,
            scale = scale,
        },
        color = rl.WHITE,  // Meshes use their own materials
        mesh_data = mesh_data,
    }
    
    append(&scene_data.objects, object)
    scene_data.next_id += 1
    
    return scene_data.next_id - 1
}