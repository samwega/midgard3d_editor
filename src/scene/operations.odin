package scene

import "../core"
import rl "vendor:raylib"

add_object :: proc(scene: ^Scene, object_type: core.Object_Type, position: rl.Vector3, rotation: rl.Vector3,scale: rl.Vector3, color: rl.Color, name: string) {
    object := Scene_Object {
        id = scene.next_id,
        name = name,
        object_type = object_type,
        transform = core.Transform {
            position = position,
            rotation = rotation,
            scale = scale,
        },
        color = color,
        mesh_data = nil,  // Initialize mesh_data to nil for non-mesh objects
    }
    append(&scene.objects, object)
    scene.next_id += 1
}

// Find object by ID
find_object :: proc(scene: ^Scene, id: int) -> ^Scene_Object {
    for &obj in scene.objects {
        if obj.id == id {
            return &obj
        }
    }
    return nil
}

// Get object index by ID
get_object_index :: proc(scene: ^Scene, id: int) -> int {
    for obj, i in scene.objects {
        if obj.id == id {
            return i
        }
    }
    return -1
}

// Clear entire scene
clear_scene :: proc(scene: ^Scene) {
    clear(&scene.objects)
    scene.next_id = 1
}