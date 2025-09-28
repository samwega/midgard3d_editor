package resources

import rl "vendor:raylib"
import "core:fmt"

// DEPRECATED: This file is kept for backward compatibility
// All new font configuration should be done in ui/font_config.odin

Fonts :: struct {
    title: rl.Font,
    ui: rl.Font,
    debug: rl.Font,
    inspector_16: rl.Font,
    inspector_18: rl.Font,
    inspector_20: rl.Font,
    inspector_24: rl.Font,
    viewport_gizmo_18: rl.Font,
}

load_fonts :: proc() -> Fonts {
    // This is deprecated - using ui font configuration instead
    fonts := Fonts {
        title = rl.GetFontDefault(),
        ui = rl.GetFontDefault(),
        debug = rl.GetFontDefault(),
        inspector_16 = rl.GetFontDefault(),
        inspector_18 = rl.GetFontDefault(),
        inspector_20 = rl.GetFontDefault(),
        inspector_24 = rl.GetFontDefault(),
        viewport_gizmo_18 = rl.GetFontDefault(),
    }
    
    return fonts
}

unload_fonts :: proc(fonts: ^Fonts) {
    // Nothing to unload - using default fonts
}