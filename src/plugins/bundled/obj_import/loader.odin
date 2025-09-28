package obj_import

import "../../../core"
import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:math"
import "core:path/filepath"

// OBJ model loading (moved from model_import package)
load_obj_model :: proc(file_path: string) -> (model: rl.Model, success: bool) {
    // Ensure file exists
    if !os.exists(file_path) {
        fmt.eprintln("OBJ file not found:", file_path)
        return {}, false
    }
    
    // Pre-validate file before loading to prevent crashes
    if !validate_obj_file_safety(file_path) {
        fmt.eprintln("OBJ file failed safety validation:", file_path)
        return {}, false
    }
    
    // Preprocess MTL files to fix absolute texture paths
    temp_mtl_path := ""
    actual_file_path := file_path
    
    if temp_path, needs_preprocessing := preprocess_mtl_file(file_path); needs_preprocessing {
        temp_mtl_path = temp_path
        // Create temporary OBJ file that references the fixed MTL
        mtl_filename := filepath.base(temp_mtl_path)
        temp_obj_content := strings.concatenate({
            "# Temporary OBJ file with fixed MTL reference\n",
            "mtllib ", mtl_filename, "\n",
            "# Include original OBJ content\n",
        }, context.temp_allocator)
        
        // Read original OBJ and append (skipping any existing mtllib lines)
        if obj_data, obj_ok := os.read_entire_file(file_path); obj_ok {
            defer delete(obj_data)
            obj_lines := strings.split(string(obj_data), "\n", context.temp_allocator)
            for line in obj_lines {
                if !strings.has_prefix(strings.trim_space(line), "mtllib ") {
                    temp_obj_content = strings.concatenate({temp_obj_content, line, "\n"}, context.temp_allocator)
                }
            }
        }
        
        // Write temporary OBJ file
        temp_obj_path := strings.concatenate({file_path[:len(file_path)-4], "_temp.obj"}, context.temp_allocator)
        if os.write_entire_file(temp_obj_path, transmute([]byte)temp_obj_content) {
            actual_file_path = temp_obj_path
            fmt.printf("Using temporary OBJ file with fixed MTL reference: %s\n", temp_obj_path)
        }
    }
    
    // Use Raylib's built-in loader
    c_filepath := strings.clone_to_cstring(actual_file_path, context.temp_allocator)
    
    fmt.printf("Attempting to load OBJ model with Raylib: %s\n", actual_file_path)
    fmt.printf("If crash occurs here, this is a known Raylib OBJ loader bug (tinyobjloader-c hashmap issue)\n")
    
    model = rl.LoadModel(c_filepath)
    
    fmt.printf("OBJ model loaded successfully!\n")
    
    // Clean up temporary files if created
    if temp_mtl_path != "" {
        cleanup_temp_mtl(temp_mtl_path)
        if actual_file_path != file_path {
            os.remove(actual_file_path) // Remove temp OBJ file
        }
    }
    
    // Check if loading succeeded
    if model.meshCount == 0 {
        fmt.eprintln("Failed to load OBJ model with Raylib:", file_path)
        fmt.eprintln("This is likely due to a known bug in Raylib's OBJ loader (tinyobjloader-c hashmap collision)")
        fmt.eprintln("Solutions:")
        fmt.eprintln("  1. Convert model to GLTF/GLB format for more reliable loading")
        fmt.eprintln("  2. Try simplifying the model geometry")
        fmt.eprintln("  3. Update Raylib/Odin to a newer version if available")
        return {}, false
    }
    
    // Post-process OBJ model
    if !post_process_obj_model(&model, file_path) {
        rl.UnloadModel(model)
        return {}, false
    }
    
    fmt.printf("Loaded OBJ model: %d meshes, %d materials - %s\n",
               model.meshCount, model.materialCount, file_path)
    
    return model, true
}

// Post-process OBJ models 
post_process_obj_model :: proc(model: ^rl.Model, file_path: string) -> bool {
    // Validate OBJ model structure
    if !validate_obj_model(model, file_path) {
        return false
    }
    
    // Generate tangents for OBJ models if needed
    for i in 0..<model.meshCount {
        mesh := &model.meshes[i]
        
        // OBJ models often lack tangents - generate them
        if mesh.tangents == nil && mesh.vertexCount > 0 && mesh.texcoords != nil && mesh.normals != nil {
            rl.GenMeshTangents(mesh)
        }
        
        // Ensure normals exist - calculate if missing
        if mesh.normals == nil && mesh.vertexCount > 0 {
            fmt.printf("Warning: OBJ mesh %d missing normals in %s (manual normal generation needed)\n", i, file_path)
        }
    }
    
    // Handle MTL materials - Raylib loads them automatically, but validate
    if model.materialCount == 0 {
        fmt.printf("Warning: No materials found for OBJ file %s, creating default\n", file_path)
        create_default_materials(model)
    } else {
        // Validate and fix OBJ materials if needed
        validate_obj_materials(model, file_path)
    }
    
    return true
}

// Validate OBJ model structure
validate_obj_model :: proc(model: ^rl.Model, file_path: string) -> bool {
    if model.meshCount == 0 {
        fmt.eprintln("Error: OBJ file contains no meshes:", file_path)
        return false
    }
    
    // Check for degenerate meshes
    for i in 0..<model.meshCount {
        mesh := &model.meshes[i]
        
        if mesh.vertexCount < 3 {
            fmt.printf("Warning: OBJ mesh %d has fewer than 3 vertices in %s\n", i, file_path)
            continue
        }
        
        if mesh.vertices == nil {
            fmt.printf("Error: OBJ mesh %d has no vertex data in %s\n", i, file_path)
            return false
        }
    }
    
    return true
}

// Validate and fix OBJ materials
validate_obj_materials :: proc(model: ^rl.Model, file_path: string) {
    base_dir := filepath.dir(file_path, context.temp_allocator)
    fmt.printf("=== Material Debug Info for %s ===\n", file_path)
    
    for i in 0..<model.materialCount {
        material := &model.materials[i]
        fmt.printf("Material %d:\n", i)
        
        // Check all material map types for debugging
        material_maps := []rl.MaterialMapIndex{
            .ALBEDO, .METALNESS, .NORMAL, .ROUGHNESS, .OCCLUSION, .EMISSION, .HEIGHT,
        }
        
        has_textures := false
        for map_type in material_maps {
            texture := material.maps[map_type].texture
            color := material.maps[map_type].color
            
            if texture.id != 0 {
                has_textures = true
                fmt.printf("  %v: Texture ID=%d, Size=%dx%d\n", map_type, texture.id, texture.width, texture.height)
                
                // Validate texture dimensions
                if texture.width == 0 || texture.height == 0 {
                    fmt.printf("    WARNING: Invalid texture dimensions!\n")
                    // Clear invalid texture
                    material.maps[map_type].texture = {}
                }
            } else if color.a > 0 {
                fmt.printf("  %v: Color=(%d,%d,%d,%d)\n", map_type, color.r, color.g, color.b, color.a)
            }
        }
        
        if !has_textures {
            fmt.printf("  No textures found - using default white material\n")
            // Ensure material has reasonable default values
            material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.WHITE
        }
    }
    
    fmt.printf("=== End Material Debug ===\n")
}

// Create default materials
create_default_materials :: proc(model: ^rl.Model) {
    model.materialCount = 1
    model.materials = make([^]rl.Material, 1)
    model.materials[0] = rl.LoadMaterialDefault()
    
    // Assign default material to all meshes
    if model.meshMaterial == nil {
        model.meshMaterial = make([^]i32, model.meshCount)
    }
    for i in 0..<model.meshCount {
        model.meshMaterial[i] = 0
    }
}

// Calculate bounding box for entire model
calculate_model_bounds :: proc(model: rl.Model) -> rl.BoundingBox {
    if model.meshCount == 0 {
        return {{0, 0, 0}, {0, 0, 0}}
    }
    
    min_point := rl.Vector3{math.F32_MAX, math.F32_MAX, math.F32_MAX}
    max_point := rl.Vector3{-math.F32_MAX, -math.F32_MAX, -math.F32_MAX}
    
    for i in 0..<model.meshCount {
        mesh := &model.meshes[i]
        
        // Process all vertices
        for j := 0; j < int(mesh.vertexCount); j += 1 {
            x := mesh.vertices[j*3 + 0]
            y := mesh.vertices[j*3 + 1]
            z := mesh.vertices[j*3 + 2]
            
            min_point.x = min(min_point.x, x)
            min_point.y = min(min_point.y, y)
            min_point.z = min(min_point.z, z)
            
            max_point.x = max(max_point.x, x)
            max_point.y = max(max_point.y, y)
            max_point.z = max(max_point.z, z)
        }
    }
    
    return {min_point, max_point}
}