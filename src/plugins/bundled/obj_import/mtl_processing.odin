package obj_import

import "core:strings"
import "core:os"
import "core:fmt"
import "core:path/filepath"

// Preprocess MTL file to fix absolute texture paths
// This is necessary because many downloaded OBJ/MTL files contain absolute paths
// from the original creator's computer, making them unusable on other machines.

preprocess_mtl_file :: proc(obj_file_path: string) -> (temp_mtl_path: string, success: bool) {
    base_dir := filepath.dir(obj_file_path, context.temp_allocator)
    original_mtl_path, _ := strings.replace(obj_file_path, ".obj", ".mtl", 1, context.temp_allocator)
    
    if !os.exists(original_mtl_path) {
        return "", false
    }
    
    // Read the original MTL file
    mtl_data, read_ok := os.read_entire_file(original_mtl_path)
    if !read_ok {
        return "", false
    }
    defer delete(mtl_data)
    
    mtl_content := string(mtl_data)
    lines := strings.split(mtl_content, "\n", context.temp_allocator)
    
    // Process each line to fix texture paths
    processed_lines: [dynamic]string
    defer delete(processed_lines)
    
    needs_processing := false
    
    for line in lines {
        trimmed := strings.trim_space(line)
        processed_line := line
        
        // Check for texture map declarations with absolute paths
        texture_prefixes := []string{"map_Kd ", "map_Ka ", "map_Ks ", "map_Ns ", "map_bump ", "bump ", "map_d ", "disp "}
        
        for prefix in texture_prefixes {
            if strings.has_prefix(trimmed, prefix) {
                parts := strings.split(trimmed, " ", context.temp_allocator)
                if len(parts) >= 2 {
                    texture_path := parts[1]
                    
                    // Check if this is an absolute path
                    if strings.contains(texture_path, ":") || strings.contains(texture_path, "\\\\") {
                        // Extract just the filename
                        texture_filename := filepath.base(texture_path)
                        
                        // Try to find the texture in common locations
                        possible_locations := []string{
                            texture_filename,                                    // Same directory as MTL
                            strings.concatenate({"textures/", texture_filename}, context.temp_allocator), // textures subdirectory
                        }
                        
                        found_texture := ""
                        for location in possible_locations {
                            full_path := filepath.join([]string{base_dir, location}, context.temp_allocator)
                            if os.exists(full_path) {
                                found_texture = location
                                break
                            }
                        }
                        
                        if found_texture != "" {
                            // Replace the absolute path with relative path
                            processed_line = strings.concatenate({prefix, found_texture}, context.temp_allocator)
                            needs_processing = true
                            fmt.printf("MTL Fix: '%s' -> '%s'\n", texture_path, found_texture)
                        } else {
                            fmt.printf("MTL Warning: Could not locate texture '%s' for line '%s'\n", texture_filename, trimmed)
                        }
                    }
                }
                break
            }
        }
        
        append(&processed_lines, strings.clone(processed_line))
    }
    
    // If no processing was needed, return empty string to use original file
    if !needs_processing {
        return "", false
    }
    
    // Create temporary MTL file with fixed paths
    temp_mtl_name := strings.concatenate({filepath.stem(obj_file_path), "_fixed.mtl"}, context.temp_allocator)
    temp_mtl_full_path := filepath.join([]string{base_dir, temp_mtl_name}, context.temp_allocator)
    
    // Write the processed content
    processed_content := strings.join(processed_lines[:], "\n", context.temp_allocator)
    
    write_ok := os.write_entire_file(temp_mtl_full_path, transmute([]byte)processed_content)
    if !write_ok {
        return "", false
    }
    
    fmt.printf("Created temporary MTL file with fixed paths: %s\n", temp_mtl_full_path)
    return strings.clone(temp_mtl_full_path), true
}

// Clean up temporary MTL file after loading
cleanup_temp_mtl :: proc(temp_mtl_path: string) {
    if temp_mtl_path != "" && os.exists(temp_mtl_path) {
        os.remove(temp_mtl_path)
        fmt.printf("Cleaned up temporary MTL file: %s\n", temp_mtl_path)
    }
}