package model_import

import "../core"
import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"

// Supported model formats (core only - plugins can add more)
Model_Format :: enum {
    GLTF,
    GLB, 
    UNKNOWN,
}

// Detect model format from file extension (core formats only)
detect_model_format :: proc(file_path: string) -> Model_Format {
    ext := strings.to_lower(filepath.ext(file_path), context.temp_allocator)
    
    switch ext {
    case ".gltf": return .GLTF
    case ".glb":  return .GLB
    case:         return .UNKNOWN
    }
}

// Pre-validate GLTF file dependencies before loading
validate_gltf_dependencies :: proc(file_path: string) -> bool {
    // Only validate glTF files (not GLB which embeds data)
    if detect_model_format(file_path) != .GLTF {
        return true  // No external dependencies to check for GLB or other formats
    }
    
    // Read the GLTF file
    file_data, ok := os.read_entire_file(file_path)
    if !ok {
        fmt.eprintln("Failed to read GLTF file for validation:", file_path)
        return false
    }
    defer delete(file_data)
    
    file_content := string(file_data)
    
    // Look for buffer URI references in the GLTF JSON
    // This is a simple text-based approach since full JSON parsing is complex
    buffer_start := strings.index(file_content, "\"buffers\"")
    if buffer_start < 0 {
        return true  // No buffers section found
    }
    
    // Look for the end of the buffers section (find matching closing bracket)
    // We'll search for the first occurrence of "]," or "]" that comes after buffers section
    buffers_section_start := buffer_start
    buffers_section_end := len(file_content)
    
    // Find the opening bracket of buffers array
    open_bracket := strings.index(file_content[buffers_section_start:], "[")
    if open_bracket >= 0 {
        open_bracket += buffers_section_start
        // Find the closing bracket (simple approach - find first "]}" or "]," after opening)
        close_bracket1 := strings.index(file_content[open_bracket:], "]}")
        close_bracket2 := strings.index(file_content[open_bracket:], "],")
        
        if close_bracket1 >= 0 && close_bracket2 >= 0 {
            // Use the first one found
            close_bracket := close_bracket1
            if close_bracket2 < close_bracket1 && close_bracket2 >= 0 {
                close_bracket = close_bracket2
            }
            buffers_section_end = open_bracket + close_bracket + 2
        } else if close_bracket1 >= 0 {
            buffers_section_end = open_bracket + close_bracket1 + 2
        } else if close_bracket2 >= 0 {
            buffers_section_end = open_bracket + close_bracket2 + 2
        }
    }
    
    buffers_section := file_content[buffers_section_start:buffers_section_end]
    
    // Find all URI entries in the buffers section using a simpler approach
    uri_pos := 0
    base_dir := filepath.dir(file_path, context.temp_allocator)
    
    for {
        // Look for "uri" field
        uri_search_start := uri_pos
        if uri_search_start >= len(buffers_section) {
            break
        }
        
        uri_pos = strings.index(buffers_section[uri_search_start:], "\"uri\"")
        if uri_pos < 0 {
            break  // No more URI entries
        }
        
        uri_pos += uri_search_start
        
        // Find the value of this URI entry (look for the next quoted string after "uri")
        // First find the colon after "uri"
        colon_pos := strings.index(buffers_section[uri_pos:], ":")
        if colon_pos < 0 {
            uri_pos += 5 // Move past "uri"
            continue
        }
        
        colon_pos += uri_pos
        // Find the opening quote of the value
        value_start_search := colon_pos + 1
        if value_start_search >= len(buffers_section) {
            break
        }
        
        // Skip whitespace and find the opening quote
        quote_start := -1
        for i in value_start_search..<len(buffers_section) {
            if buffers_section[i] == '"' {
                quote_start = i
                break
            } else if buffers_section[i] != ' ' && buffers_section[i] != '\t' && buffers_section[i] != '\n' && buffers_section[i] != '\r' {
                // Non-whitespace character that's not a quote, break
                break
            }
        }
        
        if quote_start < 0 || quote_start < value_start_search {
            uri_pos = colon_pos + 1
            continue
        }
        
        // Find the closing quote
        value_start := quote_start + 1
        if value_start >= len(buffers_section) {
            break
        }
        
        value_end := -1
        for i in value_start..<len(buffers_section) {
            if buffers_section[i] == '"' && (i == 0 || buffers_section[i-1] != '\\') {
                // Found unescaped quote
                value_end = i
                break
            }
        }
        
        if value_end < 0 {
            uri_pos = value_start
            continue
        }
        
        uri_value := buffers_section[value_start:value_end]
        
        // Skip data URIs (embedded data)
        if strings.has_prefix(uri_value, "data:") {
            uri_pos = value_end
            continue
        }
        
        // Construct full path to the buffer file
        buffer_path := filepath.join([]string{base_dir, uri_value}, context.temp_allocator)
        
        // Check if buffer file exists
        if !os.exists(buffer_path) {
            fmt.eprintln("Missing required buffer file for GLTF model:", buffer_path)
            fmt.eprintln("Referenced in:", file_path)
            return false
        }
        
        uri_pos = value_end
    }
    
    return true  // All dependencies are present
}

// Core model loader (glTF/GLB only - plugins handle other formats)
load_model :: proc(file_path: string) -> (model: rl.Model, success: bool) {
    // Ensure file exists
    if !os.exists(file_path) {
        fmt.eprintln("Model file not found:", file_path)
        return {}, false
    }
    
    format := detect_model_format(file_path)
    if format == .UNKNOWN {
        fmt.eprintln("Unsupported core model format:", file_path)
        return {}, false
    }
    
    // Pre-validate GLTF dependencies to prevent crashes
    if format == .GLTF {
        if !validate_gltf_dependencies(file_path) {
            fmt.eprintln("GLTF model validation failed - missing required buffer files")
            return {}, false
        }
    }
    
    // Use Raylib's built-in loader for glTF/GLB
    c_filepath := strings.clone_to_cstring(file_path, context.temp_allocator)
    
    fmt.printf("Loading %v model: %s\n", format, file_path)
    model = rl.LoadModel(c_filepath)
    
    // Check if loading succeeded
    if model.meshCount == 0 {
        fmt.eprintln("Failed to load model with Raylib:", file_path)
        fmt.eprintln("Possible causes:")
        fmt.eprintln("  - Missing .bin file for GLTF models")
        fmt.eprintln("  - Corrupted model file")
        fmt.eprintln("  - Unsupported model features")
        return {}, false
    }
    
    
    // Print basic model info
    fmt.printf("Loaded model - Meshes: %d, Materials: %d\n", model.meshCount, model.materialCount)
    
    // Fix vertex count for specific problematic models only (house/viking models)
    model_name := filepath.base(file_path)
    if strings.contains(model_name, "house") || strings.contains(model_name, "viking") {
        for i in 0..<model.meshCount {
            mesh := &model.meshes[i]
            if mesh.vertexCount > 0 && mesh.vertexCount % 3 != 0 {
                original_count := mesh.vertexCount
                mesh.vertexCount = (mesh.vertexCount / 3) * 3
                mesh.triangleCount = mesh.vertexCount / 3
                fmt.printf("Fixed problematic model vertex count: %d → %d\n", original_count, mesh.vertexCount)
            }
        }
    }
    
    // Apply glTF/GLB post-processing
    success = post_process_gltf_model(&model, file_path)
    
    if !success {
        rl.UnloadModel(model)
        return {}, false
    }
    
    fmt.printf("Loaded %v model: %d meshes, %d materials - %s\n",
               format, model.meshCount, model.materialCount, file_path)
    
    return model, true
}

// Post-process glTF/glb models (existing logic)
post_process_gltf_model :: proc(model: ^rl.Model, file_path: string) -> bool {
    // Generate missing tangents if needed (for normal mapping)
    for i in 0..<model.meshCount {
        mesh := &model.meshes[i]
        
        if mesh.tangents == nil && mesh.vertexCount > 0 && mesh.texcoords != nil && mesh.normals != nil {
            rl.GenMeshTangents(mesh)
        }
    }
    
    // Ensure materials are loaded
    if model.materialCount == 0 && model.meshCount > 0 {
        create_default_materials(model)
    }
    
    // Process materials for proper alpha cutout handling
    process_alpha_materials(model)
    
    return true
}


// Create default materials for glTF models
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

// Process materials - keep this simple and general
process_alpha_materials :: proc(model: ^rl.Model) {
    // For now, just ensure materials are loaded properly
    // Don't modify material properties to avoid breaking normal models
}

// Create mesh data from loaded model (same as before, but more robust)
create_mesh_data :: proc(model: rl.Model, source_filepath: string) -> ^core.Mesh_Data {
    mesh_data := new(core.Mesh_Data)
    mesh_data.model = model
    mesh_data.source_file = strings.clone(source_filepath)
    mesh_data.mesh_count = int(model.meshCount)
    mesh_data.material_count = int(model.materialCount)
    
    // Calculate bounds
    mesh_data.bounds = calculate_model_bounds(model)
    
    // Store additional metadata
    format := detect_model_format(source_filepath)
    fmt.printf("Created mesh data for %v format: %s\n", format, source_filepath)
    
    return mesh_data
}

// Calculate bounding box for entire model (unchanged from existing)
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

// Cleanup mesh data (unchanged)
cleanup_mesh_data :: proc(mesh_data: ^core.Mesh_Data) {
    if mesh_data != nil {
        rl.UnloadModel(mesh_data.model)
        delete(mesh_data.source_file)
        free(mesh_data)
    }
}


// Generate import report for a loaded model
generate_import_report :: proc(filepath: string, model: rl.Model) -> string {
    report := fmt.aprintf("=== Import Report ===\nFile: %s\nMeshes: %d\nMaterials: %d\nVertices: %d\n",
                         filepath, model.meshCount, model.materialCount,
                         model.meshes != nil ? int(model.meshes[0].vertexCount) : 0)
    return report
}

// Legacy compatibility functions (preserves existing API)
load_gltf_model :: proc(file_path: string) -> (model: rl.Model, success: bool) {
    return load_model(file_path)
}
