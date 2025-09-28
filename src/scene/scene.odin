package scene

import "../core"
import "../model_import"
import rl "vendor:raylib"

Scene :: struct {
    objects: [dynamic]Scene_Object,
    next_id: int,
}

Scene_Object :: struct {
    id:          int,
    name:        string,
    object_type: core.Object_Type,
    transform:   core.Transform,
    color:       rl.Color,
    mesh_data:   ^core.Mesh_Data,
}

init :: proc() -> Scene {
    scene := init_empty()

    // Create initial objects
    cube_color := rl.Color{51, 141, 151, 255}  // Turquoise (TEXT_MUTED)
    add_object(&scene, .CUBE, {0.5, 0.5, 0.5}, {0, 0, 0}, {1, 1, 1}, cube_color, "Reference 1x1x1 Cube")
    return scene
}

init_empty :: proc() -> Scene {
    scene := Scene {
        objects = make([dynamic]Scene_Object),
        next_id = 1,
    }
    return scene
}

cleanup :: proc(scene: ^Scene) {
    // Clean up mesh data for all mesh objects before clearing
    for &obj in scene.objects {
        if obj.object_type == .MESH && obj.mesh_data != nil {
            model_import.cleanup_mesh_data(obj.mesh_data)
        }
    }
    delete(scene.objects)
}
