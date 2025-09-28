package ui

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

// FONT CONFIGURATION - SINGLE SOURCE OF TRUTH
// Change these values to update fonts throughout the entire application

Font_Role :: enum {
    LOGO,       // Application logo (currently unused)
    TITLE,      // Main UI section titles
    GIZMO,      // 3D viewport gizmo text
    HEADER,     // Inspector section headers  
    REGULAR,    // Normal UI text, buttons, inputs
    SMALL,      // Labels, small text, debug info
}

// Font configuration struct for each role
Font_Config :: struct {
    path: string,
    size: i32,
}

// Font configurations - change these to update fonts everywhere
// CRITICAL: These sizes are loaded AND used - NO SCALING ANYWHERE!
FONT_CONFIGS := [Font_Role]Font_Config {
    .LOGO   = {"assets/fonts/VikingRunesAndIcons.otf", 120},
    .TITLE  = {"assets/fonts/Norse.otf", 56}, 
    .GIZMO  = {"assets/fonts/Norsebold.otf", 18},
    .HEADER = {"assets/fonts/Hasklig-Regular.ttf", 22},
    .REGULAR= {"assets/fonts/Hasklig-Regular.ttf", 20},
    .SMALL  = {"assets/fonts/Hasklig-Regular.ttf", 18},
}

// Loaded font instances - automatically managed
Fonts :: struct {
    data: [Font_Role]rl.Font,
}

// Global font instance
fonts: Fonts

// Get font by role - main interface for the rest of the codebase
get_font :: proc(role: Font_Role) -> rl.Font {
    return fonts.data[role]
}

// Get font size as f32 for drawing - MUST match loaded size exactly
get_font_size :: proc(role: Font_Role) -> f32 {
    return f32(FONT_CONFIGS[role].size)
}

// Load all fonts with configured settings
load_all_fonts :: proc() {
    fmt.println("Loading fonts at exact usage sizes...")
    
    // Load each font at its EXACT usage size - NO SCALING ALLOWED
    for role in Font_Role {
        config := FONT_CONFIGS[role]
        
        font := rl.LoadFontEx(strings.clone_to_cstring(config.path, context.temp_allocator), config.size, nil, 0)
        
        // Fallback to default font if loading failed
        if font.texture.id == 0 {
            fmt.printf("Warning: Failed to load font %s for role %v, using default\n", config.path, role)
            font = rl.GetFontDefault()
        } else {
            fmt.printf("Loaded font %s at %dpx for %v (NO SCALING)\n", config.path, config.size, role)
        }
        
        fonts.data[role] = font
    }
}

// Unload all fonts safely
unload_all_fonts :: proc() {
    default_font := rl.GetFontDefault()
    
    for role in Font_Role {
        font := fonts.data[role]
        // Only unload non-default fonts
        if font.texture.id != default_font.texture.id {
            rl.UnloadFont(font)
        }
    }
}

// Convenience accessors - GUARANTEED no scaling
draw_text :: proc(role: Font_Role, text: cstring, pos: rl.Vector2, color: rl.Color) {
    font := get_font(role)
    size := get_font_size(role)  // This MUST match the loaded size exactly
    rl.DrawTextEx(font, text, pos, size, 1, color)
}

measure_text :: proc(role: Font_Role, text: cstring) -> rl.Vector2 {
    font := get_font(role)
    size := get_font_size(role)  // This MUST match the loaded size exactly
    return rl.MeasureTextEx(font, text, size, 1)
}