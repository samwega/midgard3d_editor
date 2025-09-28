package serialization

import "../scene"
import "../core"
import "../model_import"
import "../resources"
import "core:encoding/json"
import "core:os"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

// Scene file format version for compatibility checking
SCENE_FILE_VERSION :: 1

// Serializable scene format
Scene_File :: struct {
    version: int,
    next_id: int,
    objects: []Object_Data,
    environment: Environment_Data `json:"environment,omitempty"`,  // NEW
}

// Serializable object data (no Raylib types)
Object_Data :: struct {
    id: int,
    name: string,
    object_type: string,  // String instead of enum for readability
    transform: Transform_Data,
    color: [4]u8,  // RGBA as array
    mesh_source_file: string `json:"mesh_source_file,omitempty"`,  // For mesh objects
}

// Serializable transform
Transform_Data :: struct {
    position: [3]f32,
    rotation: [3]f32,
    scale: [3]f32,
}

// Serializable environment data
Environment_Data :: struct {
    enabled: bool,
    source_path: string,
    rotation_y: f32,
    exposure: f32,
    intensity: f32,
    background_visible: bool,
    grid_visible: bool,
    sky_color: [3]u8,  // RGB color
}

// Current file state
File_State :: struct {
    current_filepath: string,
    has_unsaved_changes: bool,
    last_saved_time: f64,
}

file_state: File_State

// Save scene to JSON file
save_scene :: proc(scene_data: ^scene.Scene, environment: ^resources.Environment_State, filepath: string) -> bool {
    // Convert scene to serializable format
    objects := make([]Object_Data, len(scene_data.objects), context.temp_allocator)
    // No defer delete needed - temp allocator handles cleanup
    
    for obj, i in scene_data.objects {
        mesh_source := ""
        if obj.object_type == .MESH && obj.mesh_data != nil {
            mesh_source = obj.mesh_data.source_file
        }
        
        objects[i] = Object_Data{
            id = obj.id,
            name = obj.name,
            object_type = object_type_to_string(obj.object_type),
            transform = Transform_Data{
                position = {obj.transform.position.x, obj.transform.position.y, obj.transform.position.z},
                rotation = {obj.transform.rotation.x, obj.transform.rotation.y, obj.transform.rotation.z},
                scale = {obj.transform.scale.x, obj.transform.scale.y, obj.transform.scale.z},
            },
            color = {obj.color.r, obj.color.g, obj.color.b, obj.color.a},
            mesh_source_file = mesh_source,
        }
    }
    
    // Convert environment to serializable format
    environment_data := Environment_Data{
        enabled = environment.enabled,
        source_path = environment.source_path,
        rotation_y = environment.rotation_y,
        exposure = environment.exposure,
        intensity = environment.intensity,
        background_visible = environment.background_visible,
        grid_visible = environment.grid_visible,
        sky_color = {environment.sky_color.r, environment.sky_color.g, environment.sky_color.b},
    }
    
    scene_file := Scene_File{
        version = SCENE_FILE_VERSION,
        next_id = scene_data.next_id,
        objects = objects,
        environment = environment_data,
    }
    
    // Marshal to JSON
    data, err := json.marshal(scene_file, {pretty = true, use_spaces = true, spaces = 2})
    if err != nil {
        fmt.eprintln("Failed to marshal scene:", err)
        return false
    }
    defer delete(data)
    
    // Write to file
    ok := os.write_entire_file(filepath, data)
    if !ok {
        fmt.eprintln("Failed to write file:", filepath)
        return false
    }
    
    // Update file state
    file_state.current_filepath = filepath
    file_state.has_unsaved_changes = false
    file_state.last_saved_time = rl.GetTime()
    
    fmt.println("Scene saved to:", filepath)
    return true
}

// Load scene from JSON file
load_scene :: proc(filepath: string) -> (scene.Scene, resources.Environment_State, bool) {
    // Create an empty scene with an initialized arena
    new_scene := scene.init_empty()
    empty_environment := resources.Environment_State{
        grid_visible = true,
        background_visible = true,
        sky_color = {55, 70, 90, 255}, // Default dark blue-gray
    }
    
    // Read file
    data, ok := os.read_entire_file(filepath, context.temp_allocator)
    if !ok {
        fmt.eprintln("Failed to read file:", filepath)
        // Cleanup the partially created scene before returning
        scene.cleanup(&new_scene)
        return new_scene, empty_environment, false
    }
    
    // Parse JSON
    scene_file: Scene_File
    err := json.unmarshal(data, &scene_file)
    if err != nil {
        fmt.eprintln("Failed to parse JSON:", err)
        scene.cleanup(&new_scene)
        return new_scene, empty_environment, false
    }
    
    // Check version
    if scene_file.version != SCENE_FILE_VERSION {
        fmt.eprintln("Incompatible file version:", scene_file.version, "expected:", SCENE_FILE_VERSION)
        scene.cleanup(&new_scene)
        return new_scene, empty_environment, false
    }
    
    // Convert to scene format, allocating within the new scene's arena
    // Pre-allocate the objects slice to avoid re-allocations
    reserve(&new_scene.objects, len(scene_file.objects))
    new_scene.next_id = scene_file.next_id
    
    for obj_data in scene_file.objects {
        // Clone strings 
        name_clone := strings.clone(obj_data.name)
        
        scene_obj := scene.Scene_Object{
            id = obj_data.id,
            name = name_clone,
            object_type = string_to_object_type(obj_data.object_type),
            transform = core.Transform{
                position = rl.Vector3{obj_data.transform.position[0], obj_data.transform.position[1], obj_data.transform.position[2]},
                rotation = rl.Vector3{obj_data.transform.rotation[0], obj_data.transform.rotation[1], obj_data.transform.rotation[2]},
                scale = rl.Vector3{obj_data.transform.scale[0], obj_data.transform.scale[1], obj_data.transform.scale[2]},
            },
            color = rl.Color{obj_data.color[0], obj_data.color[1], obj_data.color[2], obj_data.color[3]},
        }
        
        // Load mesh data if this is a mesh object
        if scene_obj.object_type == .MESH && obj_data.mesh_source_file != "" {
            // Clone the source file path
            mesh_source_clone := strings.clone(obj_data.mesh_source_file)
            
            if model, ok := model_import.load_model(mesh_source_clone); ok {
                // Create the mesh data
                scene_obj.mesh_data = model_import.create_mesh_data(model, mesh_source_clone)
            } else {
                // Failed to load mesh - convert to cube as fallback
                fmt.eprintln("Warning: Failed to load mesh from", mesh_source_clone, "- converting to cube")
                scene_obj.object_type = .CUBE
                scene_obj.color = rl.RED  // Visual indicator of missing mesh
                delete(mesh_source_clone) // Clean up the unused path clone
            }
        }
        append(&new_scene.objects, scene_obj)
    }
    
    // Process environment data - always load all settings, not just when skybox is enabled
    // Handle backward compatibility: if sky_color is all zeros (missing from old files), use default
    sky_color := rl.Color{scene_file.environment.sky_color[0], scene_file.environment.sky_color[1], scene_file.environment.sky_color[2], 255}
    if scene_file.environment.sky_color[0] == 0 && scene_file.environment.sky_color[1] == 0 && scene_file.environment.sky_color[2] == 0 {
        sky_color = {55, 70, 90, 255}  // Default dark blue-gray for old files
    }
    
    environment := resources.Environment_State{
        enabled = scene_file.environment.enabled,
        source_path = strings.clone(scene_file.environment.source_path),
        rotation_y = scene_file.environment.rotation_y,
        exposure = scene_file.environment.exposure,
        intensity = scene_file.environment.intensity,
        background_visible = scene_file.environment.background_visible,
        grid_visible = scene_file.environment.grid_visible,
        sky_color = sky_color,
        // GPU resources will be loaded separately when needed
        skybox_texture = {},
        skybox_shader = {},
        skybox_model = {},
    }
    
    // Update file state
    file_state.current_filepath = strings.clone(filepath) // Take ownership of the filepath string
    file_state.has_unsaved_changes = false
    file_state.last_saved_time = rl.GetTime()
    
    fmt.println("Scene loaded from:", filepath)
    return new_scene, environment, true
}

// Helper to convert object type enum to string
object_type_to_string :: proc(obj_type: core.Object_Type) -> string {
    switch obj_type {
    case .CUBE:
        return "CUBE"
    case .SPHERE:
        return "SPHERE"
    case .CYLINDER:
        return "CYLINDER"
    case .MESH:
        return "MESH"
    }
    return "UNKNOWN"
}

// Helper to convert string to object type enum
string_to_object_type :: proc(type_str: string) -> core.Object_Type {
    switch type_str {
    case "CUBE":
        return .CUBE
    case "SPHERE":
        return .SPHERE
    case "CYLINDER":
        return .CYLINDER
    case "MESH":
        return .MESH
    }
    return .CUBE  // Default
}

// Create a new empty scene
new_scene :: proc() -> scene.Scene {
    return scene.init_empty()
}

// Mark the scene as having unsaved changes
mark_unsaved :: proc() {
    file_state.has_unsaved_changes = true
}

// Get current filename for display
get_current_filename :: proc() -> string {
    if file_state.current_filepath == "" {
        return "Untitled"
    }
    
    // Extract just the filename from the path
    last_slash := strings.last_index(file_state.current_filepath, "/")
    last_backslash := strings.last_index(file_state.current_filepath, "\\")
    
    separator_index := max(last_slash, last_backslash)
    if separator_index >= 0 && separator_index < len(file_state.current_filepath) - 1 {
        return file_state.current_filepath[separator_index + 1:]
    }
    
    return file_state.current_filepath
}

// Check if there are unsaved changes
has_unsaved_changes :: proc() -> bool {
    return file_state.has_unsaved_changes
}