package resources

import "core:fmt"
import "core:strings"
import "core:os"
import "core:math"
// import "core:mem"
import "core:c"
import "core:strconv"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Manual HDR file parsing since raylib's stb_image doesn't have HDR support enabled
// We'll implement a simple Radiance HDR (.hdr) parser

// HDR format constants
RLE_SCANLINE_SIGNATURE_1 :: 0x02
RLE_SCANLINE_SIGNATURE_2 :: 0x02
RGBE_EXPONENT_OFFSET :: 128
RLE_RUN_THRESHOLD :: 128

// Forward declaration to avoid circular imports
Environment_State :: struct {
    // Core state
    enabled: bool,
    source_path: string,
    is_hdr: bool,           // True if loaded from HDR file
    
    // GPU resources (zero-init = invalid)
    skybox_texture: rl.Texture2D,
    skybox_shader: rl.Shader,
    skybox_model: rl.Model,
    
    // User controls
    rotation_y: f32,        // Y-axis rotation in degrees
    exposure: f32,          // EV adjustment (default 0.0)
    intensity: f32,         // Brightness multiplier (default 1.0)
    background_visible: bool, // Toggle skybox visibility (default true)
    grid_visible: bool,     // Toggle grid visibility (default true)
    sky_color: rl.Color,    // Color of the sky when no skybox is active
}

// HDR loading result - simplified since we don't use raylib Image
HDR_Load_Result :: struct {
    width, height: int,
    pixels: ^f32,        // Direct pointer to pixel data
    success: bool,
}

// Simple Radiance HDR file parser - basic implementation
parse_hdr_header :: proc(data: []byte) -> (width, height, offset: int, success: bool) {
    // Look for the resolution line (last line of header)
    header_end := -1
    for i in 0..<len(data)-1 {
        if data[i] == '\n' && data[i+1] != '#' && data[i+1] != '\n' {
            // Found potential resolution line
            line_start := i + 1
            line_end := line_start
            for line_end < len(data) && data[line_end] != '\n' {
                line_end += 1
            }
            
            // Parse resolution line: "-Y height +X width"
            line := string(data[line_start:line_end])
            if strings.contains(line, "-Y") && strings.contains(line, "+X") {
                // Simple parsing - look for numbers
                parts := strings.fields(line, context.temp_allocator)
                if len(parts) >= 4 {
                    h, h_ok := strconv.parse_int(parts[1])
                    w, w_ok := strconv.parse_int(parts[3])
                    if !h_ok || !w_ok { continue } 
                    if h > 0 && w > 0 {
                        return w, h, line_end + 1, true
                    }
                }
            }
        }
    }
    return 0, 0, 0, false
}

// Convert RGBE to RGB float
rgbe_to_rgb :: proc(rgbe: [4]u8) -> [3]f32 {
    if rgbe[3] == 0 {
        return {0, 0, 0}
    }
    
    exponent := f32(int(rgbe[3]) - RGBE_EXPONENT_OFFSET)
    scale := math.pow(2.0, exponent) / 256.0
    
    return {
        f32(rgbe[0]) * scale,
        f32(rgbe[1]) * scale, 
        f32(rgbe[2]) * scale,
    }
}

// Load HDR image using manual parsing
load_hdr_image :: proc(path: string) -> HDR_Load_Result {
    // Read file data
    file_data, ok := os.read_entire_file(path, context.temp_allocator)
    if !ok {
        fmt.eprintln("Failed to read HDR file:", path)
        return {success = false}
    }
    
    // Parse header
    width, height, data_offset, header_ok := parse_hdr_header(file_data)
    if !header_ok {
        fmt.eprintln("Failed to parse HDR header:", path)
        return {success = false}
    }
    
    fmt.printf("HDR dimensions: %dx%d\n", width, height)
    
    // Allocate float RGB data using temp allocator for automatic cleanup
    pixel_count := width * height * 3
    pixels := make([]f32, pixel_count, context.temp_allocator)
    
    // HDR files use RLE compression - need to decompress scanlines
    rgbe_data := file_data[data_offset:]
    
    // Decode RLE compressed scanlines
    rgbe_pixels := make([]u8, width * height * 4, context.temp_allocator)
    data_pos := 0
    pixel_pos := 0
    
    for y in 0..<height {
        // Check if this is a new RLE scanline (starts with signature bytes)
        if data_pos + 4 < len(rgbe_data) && 
           rgbe_data[data_pos] == RLE_SCANLINE_SIGNATURE_1 && rgbe_data[data_pos + 1] == RLE_SCANLINE_SIGNATURE_2 {
            
            // RLE compressed scanline
            data_pos += 4 // Skip header
            
            // Decompress each channel separately
            for channel in 0..<4 {
                x := 0
                for x < width && data_pos < len(rgbe_data) {
                    run_length := int(rgbe_data[data_pos])
                    data_pos += 1
                    
                    if run_length > RLE_RUN_THRESHOLD {
                        // Run of identical values
                        run_length -= RLE_RUN_THRESHOLD
                        if data_pos >= len(rgbe_data) { break }
                        value := rgbe_data[data_pos]
                        data_pos += 1
                        
                        for i in 0..<run_length {
                            if x >= width { break }
                            rgbe_pixels[(y * width + x) * 4 + channel] = value
                            x += 1
                        }
                    } else {
                        // Run of different values
                        for i in 0..<run_length {
                            if x >= width || data_pos >= len(rgbe_data) { break }
                            rgbe_pixels[(y * width + x) * 4 + channel] = rgbe_data[data_pos]
                            data_pos += 1
                            x += 1
                        }
                    }
                }
            }
        } else {
            // Uncompressed scanline - copy 4 bytes per pixel
            for x in 0..<width {
                if data_pos + 4 > len(rgbe_data) { break }
                rgbe_pixels[pixel_pos + 0] = rgbe_data[data_pos + 0]
                rgbe_pixels[pixel_pos + 1] = rgbe_data[data_pos + 1]
                rgbe_pixels[pixel_pos + 2] = rgbe_data[data_pos + 2]
                rgbe_pixels[pixel_pos + 3] = rgbe_data[data_pos + 3]
                data_pos += 4
                pixel_pos += 4
            }
        }
    }
    
    // Convert decompressed RGBE to RGB float (flip Y to correct orientation)
    for y in 0..<height {
        for x in 0..<width {
            rgbe_idx := (y * width + x) * 4
            // Flip Y coordinate to correct skybox orientation
            flipped_y := height - 1 - y
            rgb_idx := (flipped_y * width + x) * 3
            
            rgbe := [4]u8{rgbe_pixels[rgbe_idx], rgbe_pixels[rgbe_idx+1], rgbe_pixels[rgbe_idx+2], rgbe_pixels[rgbe_idx+3]}
            rgb := rgbe_to_rgb(rgbe)
            
            pixels[rgb_idx + 0] = rgb[0]
            pixels[rgb_idx + 1] = rgb[1]
            pixels[rgb_idx + 2] = rgb[2]
        }
    }
    
    fmt.printf("HDR parsed successfully: %dx%d, %d pixels\n", width, height, len(pixels)/3)
    
    return HDR_Load_Result{
        width = width,
        height = height,
        pixels = raw_data(pixels),
        success = true,
    }
}

// Check if current GL context supports float textures
supports_float_textures :: proc() -> bool {
    // Raylib with OpenGL 3.3+ should support float textures by default
    // We can query the GL version through rlgl if needed, but for now assume support
    return true
}

// Upload float texture to GPU using rlgl
upload_float_texture_2d :: proc(width, height: int, pixels: ^f32) -> (texture_id: u32, success: bool) {
    // Use rlgl.LoadTexture with float format
    // UNCOMPRESSED_R32G32B32 is 32-bit float RGB format
    tex_id := rlgl.LoadTexture(rawptr(pixels), c.int(width), c.int(height), c.int(rl.PixelFormat.UNCOMPRESSED_R32G32B32), 1)
    
    if tex_id == 0 {
        return 0, false
    }
    
    return u32(tex_id), true
}

// Create a raylib Texture2D from GL texture ID
make_raylib_texture_from_gl :: proc(gl_tex_id: u32, width, height: int) -> rl.Texture2D {
    texture := rl.Texture2D{
        id = u32(gl_tex_id),
        width = i32(width),
        height = i32(height),
        mipmaps = 1,
        format = rl.PixelFormat.UNCOMPRESSED_R32G32B32,
    }
    return texture
}

// CPU fallback: tonemap HDR to 8-bit and create texture
cpu_tonemap_and_upload :: proc(width, height: int, hdr_pixels: ^f32, exposure, intensity: f32) -> rl.Texture2D {
    // Allocate 8-bit RGB buffer
    pixel_count := width * height * 3
    ldr_pixels := make([]u8, pixel_count, context.temp_allocator)
    
    // Apply exposure and tonemapping
    exposure_scale := math.pow(2.0, exposure) * intensity
    
    for i := 0; i < pixel_count; i += 3 {
        // Get HDR RGB values (cast pointer to slice for indexing)
        pixels := ([^]f32)(hdr_pixels)
        r := f32(pixels[i + 0]) * exposure_scale
        g := f32(pixels[i + 1]) * exposure_scale
        b := f32(pixels[i + 2]) * exposure_scale
        
        // Reinhard tonemapping: color = color / (1 + color)
        r = r / (1.0 + r)
        g = g / (1.0 + g)
        b = b / (1.0 + b)
        
        // Gamma correction (2.2)
        r = math.pow(r, f32(1.0 / 2.2))
        g = math.pow(g, f32(1.0 / 2.2))
        b = math.pow(b, f32(1.0 / 2.2))
        
        // Convert to 8-bit
        ldr_pixels[i + 0] = u8(math.clamp(r * 255.0, f32(0), f32(255)))
        ldr_pixels[i + 1] = u8(math.clamp(g * 255.0, f32(0), f32(255)))
        ldr_pixels[i + 2] = u8(math.clamp(b * 255.0, f32(0), f32(255)))
    }
    
    // Create raylib image and texture
    image := rl.Image{
        data = raw_data(ldr_pixels),
        width = i32(width),
        height = i32(height),
        mipmaps = 1,
        format = rl.PixelFormat.UNCOMPRESSED_R8G8B8,
    }
    
    texture := rl.LoadTextureFromImage(image)
    return texture
}

// Generate cubemap from equirectangular image
gen_texture_cubemap :: proc(shader: rl.Shader, panorama: rl.Texture2D, size: int) -> rl.Texture2D {
    // This would implement the cubemap generation as shown in the Raylib example
    // For now, we'll just return the panorama texture as a fallback
    return panorama
}

load_hdri_environment :: proc(file_path: string, current_env: Environment_State) -> (env: Environment_State, success: bool) {
    // Validate file exists
    if !os.exists(file_path) {
        fmt.eprintln("Skybox file not found:", file_path)
        return {}, false
    }
    
    // Check if this is an HDR/EXR file
    is_hdr := strings.has_suffix(file_path, ".hdr") || strings.has_suffix(file_path, ".exr")
    
    skybox_texture: rl.Texture2D
    
    // HDR pipeline using custom parser
    if is_hdr && strings.has_suffix(file_path, ".hdr") {
        fmt.printf("Loading HDR image: %s\n", file_path)
        
        // Load HDR float data
        hdr_result := load_hdr_image(file_path)
        if !hdr_result.success {
            return {}, false
        }
        // Note: HDR data uses temp allocator and will be automatically cleaned up after GPU upload
        
        // Try to upload as float texture
        if supports_float_textures() {
            gl_tex_id, upload_ok := upload_float_texture_2d(hdr_result.width, hdr_result.height, hdr_result.pixels)
            if upload_ok {
                skybox_texture = make_raylib_texture_from_gl(gl_tex_id, hdr_result.width, hdr_result.height)
                fmt.printf("HDR texture uploaded as float format (%dx%d)\n", hdr_result.width, hdr_result.height)
            } else {
                fmt.eprintln("Float texture upload failed, falling back to CPU tonemapping")
                skybox_texture = cpu_tonemap_and_upload(hdr_result.width, hdr_result.height, hdr_result.pixels, 0.0, 1.0)
            }
        } else {
            fmt.printf("Float textures not supported, using CPU tonemapping\n")
            skybox_texture = cpu_tonemap_and_upload(hdr_result.width, hdr_result.height, hdr_result.pixels, 0.0, 1.0)
        }
        
        if skybox_texture.id == 0 {
            fmt.eprintln("Failed to create texture from HDR data")
            return {}, false
        }
    } else if is_hdr && strings.has_suffix(file_path, ".exr") {
        // EXR not supported yet
        fmt.eprintln("EXR files not supported yet. Please convert to HDR format or use a regular image format (PNG/JPG).")
        return {}, false
    } else {
        // Regular image loading for PNG/JPG/etc
        image := rl.LoadImage(strings.clone_to_cstring(file_path, context.temp_allocator))
        if image.data == nil {
            fmt.eprintln("Failed to load image:", file_path)
            return {}, false
        }
        defer rl.UnloadImage(image)
        
        // Convert to texture
        skybox_texture = rl.LoadTextureFromImage(image)
        if skybox_texture.id == 0 {
            fmt.eprintln("Failed to create texture from image")
            return {}, false
        }
    }
    
    // Find the assets directory to locate shader files
    // This handles the issue where file dialogs change the current working directory
    vs_path := find_asset_path("assets/shaders/skybox_equirect.vs")
    fs_path := find_asset_path("assets/shaders/skybox_equirect.fs")
    
    // Verify that the shader files exist before attempting to load them
    if vs_path == "" {
        fmt.eprintln("Vertex shader not found: assets/shaders/skybox_equirect.vs")
        rl.UnloadTexture(skybox_texture)
        return {}, false
    }
    if fs_path == "" {
        fmt.eprintln("Fragment shader not found: assets/shaders/skybox_equirect.fs")
        rl.UnloadTexture(skybox_texture)
        return {}, false
    }
    
    // Check if files exist first
    if !os.exists(vs_path) {
        fmt.eprintln("Vertex shader not found at:", vs_path)
        rl.UnloadTexture(skybox_texture)
        return {}, false
    }
    if !os.exists(fs_path) {
        fmt.eprintln("Fragment shader not found at:", fs_path)
        rl.UnloadTexture(skybox_texture)
        return {}, false
    }
    
    skybox_shader := rl.LoadShader(
        strings.clone_to_cstring(vs_path, context.temp_allocator),
        strings.clone_to_cstring(fs_path, context.temp_allocator),
    )
    if skybox_shader.id == 0 {
        rl.UnloadTexture(skybox_texture)
        fmt.eprintln("Failed to load skybox shader - shader compilation failed")
        return {}, false
    }
    
    // Create sphere model for skybox
    sphere_mesh := rl.GenMeshSphere(1.0, 32, 32)
    skybox_model := rl.LoadModelFromMesh(sphere_mesh)
    
    // Set material properties
    skybox_model.materials[0].shader = skybox_shader
    
    env = Environment_State{
        enabled = true,
        source_path = strings.clone(file_path),
        is_hdr = is_hdr && strings.has_suffix(file_path, ".hdr"),
        skybox_texture = skybox_texture,
        skybox_shader = skybox_shader,
        skybox_model = skybox_model,
        rotation_y = current_env.rotation_y,          // Preserve rotation setting
        exposure = current_env.exposure,              // Preserve exposure setting
        intensity = current_env.intensity,            // Preserve intensity setting
        background_visible = current_env.background_visible, // Preserve skybox visibility
        grid_visible = current_env.grid_visible,      // Preserve grid visibility
        sky_color = current_env.sky_color,            // Preserve sky color
    }
    
    fmt.printf("Skybox loaded successfully: %s\\n", file_path)
    return env, true
}

unload_hdri_environment :: proc(env: ^Environment_State) {
    if env == nil || !env.enabled { return }
    
    // Preserve environment settings (non-skybox related)
    grid_visible := env.grid_visible
    sky_color := env.sky_color
    
    // Unload texture - works for both regular and HDR float textures
    rl.UnloadTexture(env.skybox_texture)
    rl.UnloadShader(env.skybox_shader)
    rl.UnloadModel(env.skybox_model)
    delete(env.source_path)
    
    // Reset only skybox-related fields, preserve environment settings
    env^ = {}
    env.grid_visible = grid_visible
    env.sky_color = sky_color
    
    fmt.println("Skybox environment unloaded")
}
// Find an asset file by searching from the current directory up to project root
// This handles the issue where file dialogs change the current working directory
find_asset_path :: proc(asset_rel_path: string) -> string {
    // Check if the file exists at the relative path from current directory
    if os.exists(asset_rel_path) {
        return asset_rel_path
    }
    
    // If not found, try to find the assets directory by searching in parent directories
    // This is a simple approach - we'll check a few levels up
    path1 := strings.concatenate({"../", asset_rel_path}, context.temp_allocator)
    if os.exists(path1) {
        return path1
    }
    
    path2 := strings.concatenate({"../../", asset_rel_path}, context.temp_allocator)
    if os.exists(path2) {
        return path2
    }
    
    path3 := strings.concatenate({"../../../", asset_rel_path}, context.temp_allocator)
    if os.exists(path3) {
        return path3
    }
    
    path4 := strings.concatenate({"../../../../", asset_rel_path}, context.temp_allocator)
    if os.exists(path4) {
        return path4
    }
    
    // If still not found, return empty string to indicate failure
    return ""
}