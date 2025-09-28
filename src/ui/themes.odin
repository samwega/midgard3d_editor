package ui

import rl "vendor:raylib"

// THEME COLORS - SINGLE SOURCE OF TRUTH
// Change these values to update colors throughout the entire application

UI_COLORS := struct {
    // Core UI Colors  
    BACKGROUND:     rl.Color,  // Panel backgrounds
    SKY:            rl.Color,  // 3D viewport sky
    SECONDARY:      rl.Color,  // Darker sections, menu bars, headers
    BORDER:         rl.Color,  // All borders and lines
    
    // Text Colors
    TEXT:           rl.Color,  // Normal text
    TEXT_MUTED:     rl.Color,  // Debug info, shortcuts, secondary text
    
    // Interactive Colors
    ACCENT:         rl.Color,  // Primary accent - checkboxes, gizmos, labels (fuchsia!)
    HOVER:          rl.Color,  // Hover/focus states (subtle blue)
    INPUT_BG:       rl.Color,  // Input field backgrounds
    SELECTION:      rl.Color,  // Selection highlight
} {
    // Your carefully chosen color palette
    BACKGROUND     = {16, 26, 41, 255},      // #101A29 - Dark panels
    SKY            = {135, 206, 235, 255},   // #87CEEB - Clear blue sky
    SECONDARY      = {13, 21, 33, 255},      // #0D1521 - Darker sections, headers
    BORDER         = {9, 14, 22, 255},       // #090E16 - All borders
    
    TEXT           = {184, 92, 64, 255},     // #B85C40 - Light text
    TEXT_MUTED     = {51, 141, 151, 255},    // rgb(51, 141, 151) - Turquoise for debug/secondary text/spheres
    
    ACCENT         = {190, 74, 112, 255},    // #BE4A70 - Primary accent (fuchsia!)
    HOVER          = {35, 27, 42, 255},      // #231B2A - Hover/focus states
    INPUT_BG       = {9, 14, 22, 255},       // #090E16 - Input backgrounds
    SELECTION      = {68, 31, 48, 255},      // #441F30 - Selection highlight
}