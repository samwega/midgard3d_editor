package obj_import

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:os"
import "core:path/filepath"

// Pre-validate OBJ file to detect potential stack overflow conditions
validate_obj_file_safety :: proc(file_path: string) -> bool {
    file_info, stat_err := os.stat(file_path)
    if stat_err != nil {
        return false
    }
    
    file_size := file_info.size
    fmt.printf("OBJ file size: %.2f MB\n", f64(file_size) / (1024.0 * 1024.0))
    
    // Quick scan to estimate complexity - the real issue is vertex/face density
    if obj_data, read_ok := os.read_entire_file(file_path); read_ok {
        defer delete(obj_data)
        
        content := string(obj_data)
        vertex_count := strings.count(content, "\nv ")
        face_count := strings.count(content, "\nf ")
        
        fmt.printf("OBJ complexity: ~%d vertices, ~%d faces\n", vertex_count, face_count)
        
        // Info only - no arbitrary limits for a 3D editor
        fmt.printf("Model info: %d vertices, %d faces\n", vertex_count, face_count)
        
        // Only warn for truly massive models that might have genuine performance issues
        if vertex_count > 500_000 {
            fmt.printf("INFO: Large model (%d vertices) - may take time to load\n", vertex_count)
        }
        
        // Always return true but give warnings - let Raylib try and see what happens
        // This way we collect data on what actually causes crashes
        return true
    }
    
    return false
}

// OBJ-specific validation and utilities
OBJ_Import_Result :: struct {
    success: bool,
    warnings: [dynamic]string,
    errors: [dynamic]string,
}

// Comprehensive OBJ validation
validate_obj_file :: proc(file_path: string) -> OBJ_Import_Result {
    result := OBJ_Import_Result{
        success = true,
        warnings = make([dynamic]string),
        errors = make([dynamic]string),
    }
    
    // Check if OBJ file exists
    if !os.exists(file_path) {
        append(&result.errors, fmt.aprintf("OBJ file not found: %s", file_path))
        result.success = false
        return result
    }
    
    // Check for corresponding MTL file
    mtl_path, _ := strings.replace(file_path, ".obj", ".mtl", 1, context.temp_allocator)
    if !os.exists(mtl_path) {
        append(&result.warnings, fmt.aprintf("No MTL file found at: %s", mtl_path))
        append(&result.warnings, "Model will use default materials")
    }
    
    // Validate file is readable
    if file_data, ok := os.read_entire_file(file_path); ok {
        defer delete(file_data)
        
        // Basic OBJ format validation
        file_content := string(file_data)
        if !strings.contains(file_content, "v ") {
            append(&result.errors, "OBJ file contains no vertices")
            result.success = false
        }
        
        if !strings.contains(file_content, "f ") {
            append(&result.warnings, "OBJ file contains no faces - may be point cloud")
        }
        
        // Check for texture coordinates
        if !strings.contains(file_content, "vt ") {
            append(&result.warnings, "OBJ file contains no UV coordinates - texturing may not work properly")
        }
        
        // Check for normals
        if !strings.contains(file_content, "vn ") {
            append(&result.warnings, "OBJ file contains no normals - will generate automatically")
        }
        
    } else {
        append(&result.errors, "Cannot read OBJ file")
        result.success = false
    }
    
    return result
}

// Validate textures referenced by MTL file
validate_obj_textures :: proc(file_path: string) -> []string {
    missing_textures: [dynamic]string
    
    base_dir := filepath.dir(file_path, context.temp_allocator)
    mtl_path, _ := strings.replace(file_path, ".obj", ".mtl", 1, context.temp_allocator)
    
    fmt.printf("=== Texture Validation Debug ===\n")
    fmt.printf("OBJ file: %s\n", file_path)
    fmt.printf("Base directory: %s\n", base_dir)
    fmt.printf("MTL file path: %s\n", mtl_path)
    
    if !os.exists(mtl_path) {
        fmt.printf("ERROR: MTL file not found!\n")
        return missing_textures[:]
    }
    
    if mtl_data, ok := os.read_entire_file(mtl_path); ok {
        defer delete(mtl_data)
        
        mtl_content := string(mtl_data)
        lines := strings.split(mtl_content, "\n", context.temp_allocator)
        
        fmt.printf("MTL file contains %d lines\n", len(lines))
        
        for line in lines {
            trimmed := strings.trim_space(line)
            
            // Check for texture map declarations
            if strings.has_prefix(trimmed, "map_Kd ") ||      // Diffuse texture
               strings.has_prefix(trimmed, "map_Ka ") ||      // Ambient texture
               strings.has_prefix(trimmed, "map_Ks ") ||      // Specular texture
               strings.has_prefix(trimmed, "map_Ns ") ||      // Specular highlight texture
               strings.has_prefix(trimmed, "map_bump ") ||    // Bump map
               strings.has_prefix(trimmed, "bump ") ||        // Bump map (alternative)
               strings.has_prefix(trimmed, "map_d ") ||       // Dissolve texture
               strings.has_prefix(trimmed, "disp ") {         // Displacement map
                
                parts := strings.split(trimmed, " ", context.temp_allocator)
                if len(parts) >= 2 {
                    texture_path := parts[1]
                    
                    // Check if texture file exists
                    full_texture_path := filepath.join([]string{base_dir, texture_path}, context.temp_allocator)
                    
                    fmt.printf("Checking texture: %s -> %s\n", texture_path, full_texture_path)
                    
                    if !os.exists(full_texture_path) {
                        fmt.printf("  MISSING: %s\n", texture_path)
                        append(&missing_textures, strings.clone(texture_path))
                    } else {
                        fmt.printf("  FOUND: %s\n", texture_path)
                    }
                }
            }
        }
    }
    
    fmt.printf("=== End Texture Validation ===\n")
    return missing_textures[:]
}