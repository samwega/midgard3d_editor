package serialization

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"

// UI Colors - local copy to avoid cyclic import
UI_COLORS := struct {
    BACKGROUND: rl.Color,
    BORDER: rl.Color,
    TEXT: rl.Color,
    TEXT_MUTED: rl.Color,
    HOVER: rl.Color,
    INPUT_BG: rl.Color,
}{
    BACKGROUND = {16, 26, 41, 255},      // #101A29 - Match main theme
    BORDER = {9, 14, 22, 255},           // #090E16 - Match main theme
    TEXT = {184, 92, 64, 255},           // #B85C40 - Match main theme
    TEXT_MUTED = {43, 123, 138, 255},    // #2B7B8A - Match main theme
    HOVER = {35, 27, 42, 255},           // #231B2A - Match main theme
    INPUT_BG = {9, 14, 22, 255},         // #090E16 - Match main theme
}

// File dialog state - native Windows dialogs preferred, text input fallback
File_Dialog_State :: struct {
    visible: bool,
    mode: File_Dialog_Mode,
    input_buffer: [256]u8,
    input_length: int,
    completed: bool,
    completed_filepath: string,
}

File_Dialog_Mode :: enum {
    SAVE,
    LOAD,
    IMPORT,  // For importing glTF files
    HDRI_IMPORT,  // For importing HDRI files
}

file_dialog_state: File_Dialog_State

// Show save dialog - Windows uses native dialog, other platforms use built-in
show_save_dialog :: proc() {
    when ODIN_OS == .Windows {
        // Use native Windows file dialog only
        if filepath, success := show_native_save_dialog(); success {
            file_dialog_state.completed = true
            file_dialog_state.completed_filepath = filepath
            file_dialog_state.mode = .SAVE
        }
        // No fallback - if user cancels, that's it
    } else {
        // Use built-in text-based dialog on non-Windows platforms
        file_dialog_state.visible = true
        file_dialog_state.mode = .SAVE
        file_dialog_state.completed = false
        file_dialog_state.completed_filepath = ""
        
        // Pre-fill with default name
        default_name := "scene.json"
        copy(file_dialog_state.input_buffer[:], default_name)
        file_dialog_state.input_length = len(default_name)
    }
}

// Show load dialog - Windows uses native dialog, other platforms use built-in
show_load_dialog :: proc() {
    when ODIN_OS == .Windows {
        // Use native Windows file dialog only
        if filepath, success := show_native_load_dialog(); success {
            file_dialog_state.completed = true
            file_dialog_state.completed_filepath = filepath
            file_dialog_state.mode = .LOAD
        }
        // No fallback - if user cancels, that's it
    } else {
        // Use built-in text-based dialog on non-Windows platforms
        file_dialog_state.visible = true
        file_dialog_state.mode = .LOAD
        file_dialog_state.completed = false
        file_dialog_state.completed_filepath = ""
        
        // Clear buffer
        file_dialog_state.input_buffer = {}
        file_dialog_state.input_length = 0
    }
}

// Show import dialog for 3D models - Windows uses native dialog, other platforms use built-in
show_import_dialog :: proc() {
    when ODIN_OS == .Windows {
        // Use native Windows file dialog only
        if filepath, success := show_native_import_dialog(); success {
            file_dialog_state.completed = true
            file_dialog_state.completed_filepath = filepath
            file_dialog_state.mode = .IMPORT
        }
        // No fallback - if user cancels, that's it
    } else {
        // Use built-in text-based dialog on non-Windows platforms
        file_dialog_state.visible = true
        file_dialog_state.mode = .IMPORT
        file_dialog_state.completed = false
        file_dialog_state.completed_filepath = ""
        
        // Clear buffer
        file_dialog_state.input_buffer = {}
        file_dialog_state.input_length = 0
    }
}

// Show HDRI import dialog - Windows uses native dialog, other platforms use built-in
show_hdri_dialog :: proc() {
    when ODIN_OS == .Windows {
        // Use native Windows file dialog only
        if filepath, success := show_native_hdri_dialog(); success {
            file_dialog_state.completed = true
            file_dialog_state.completed_filepath = filepath
            file_dialog_state.mode = .HDRI_IMPORT
        }
        // No fallback - if user cancels, that's it
    } else {
        // Use built-in text-based dialog on non-Windows platforms
        file_dialog_state.visible = true
        file_dialog_state.mode = .HDRI_IMPORT
        file_dialog_state.completed = false
        file_dialog_state.completed_filepath = ""
        
        // Clear buffer
        file_dialog_state.input_buffer = {}
        file_dialog_state.input_length = 0
    }
}

// Update file dialog (handle input)
update_file_dialog :: proc() {
    if !file_dialog_state.visible {
        return
    }
    
    // Handle text input
    key := rl.GetCharPressed()
    for key > 0 {
        if key >= 32 && key < 127 && file_dialog_state.input_length < 255 {
            file_dialog_state.input_buffer[file_dialog_state.input_length] = u8(key)
            file_dialog_state.input_length += 1
        }
        key = rl.GetCharPressed()
    }
    
    // Handle backspace
    if rl.IsKeyPressed(.BACKSPACE) && file_dialog_state.input_length > 0 {
        file_dialog_state.input_length -= 1
        file_dialog_state.input_buffer[file_dialog_state.input_length] = 0
    }
    
    // Handle enter to confirm
    if rl.IsKeyPressed(.ENTER) && file_dialog_state.input_length > 0 {
        filepath := string(file_dialog_state.input_buffer[:file_dialog_state.input_length])
        
        // Ensure proper file extension based on mode
        switch file_dialog_state.mode {
        case .SAVE, .LOAD:
            if !strings.has_suffix(filepath, ".json") {
                filepath = strings.concatenate({filepath, ".json"}, context.temp_allocator)
            }
        case .IMPORT:
            // Accept multiple 3D model formats
            has_valid_extension := false
            
            if strings.has_suffix(filepath, ".gltf") || 
               strings.has_suffix(filepath, ".glb") ||
               strings.has_suffix(filepath, ".obj") {
                has_valid_extension = true
            }
            
            if !has_valid_extension {
                // Default to .obj if no extension (most common for architectural assets)
                filepath = strings.concatenate({filepath, ".obj"}, context.temp_allocator)
            }
        case .HDRI_IMPORT:
            // Accept HDRI formats
            has_valid_extension := false
            
            if strings.has_suffix(filepath, ".hdr") || 
               strings.has_suffix(filepath, ".exr") ||
               strings.has_suffix(filepath, ".png") ||
               strings.has_suffix(filepath, ".jpg") ||
               strings.has_suffix(filepath, ".jpeg") ||
               strings.has_suffix(filepath, ".tga") ||
               strings.has_suffix(filepath, ".bmp") {
                has_valid_extension = true
            }
            
            if !has_valid_extension {
                // Default to .png if no extension (common skybox format)
                filepath = strings.concatenate({filepath, ".png"}, context.temp_allocator)
            }
        }
        
        // Set completion state
        file_dialog_state.completed = true
        file_dialog_state.completed_filepath = strings.clone(filepath)
        
        // Close dialog
        file_dialog_state.visible = false
    }
    
    // Handle escape to cancel
    if rl.IsKeyPressed(.ESCAPE) {
        file_dialog_state.visible = false
    }
}

// Draw file dialog
draw_file_dialog :: proc() {
    if !file_dialog_state.visible {
        return
    }
    
    // Dialog dimensions
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())
    dialog_width := f32(400)
    dialog_height := f32(150)
    dialog_x := (screen_width - dialog_width) / 2
    dialog_y := (screen_height - dialog_height) / 2
    
    // Draw overlay
    rl.DrawRectangle(0, 0, i32(screen_width), i32(screen_height), rl.ColorAlpha(rl.BLACK, 0.5))
    
    // Draw dialog background
    dialog_rect := rl.Rectangle{dialog_x, dialog_y, dialog_width, dialog_height}
    rl.DrawRectangleRec(dialog_rect, UI_COLORS.BACKGROUND)
    rl.DrawRectangleLinesEx(dialog_rect, 2, UI_COLORS.BORDER)
    
    // Draw title
    title: string
    switch file_dialog_state.mode {
    case .SAVE:
        title = "Save Scene"
    case .LOAD:
        title = "Load Scene"
    case .IMPORT:
        title = "Import 3D Model (glTF/glb/OBJ)"
    case .HDRI_IMPORT:
        title = "Import Skybox Image"
    }
    title_pos := rl.Vector2{dialog_x + 10, dialog_y + 10}
    
    // Draw title using centralized system
    // Note: We need to import ui to use draw_text, so using raw call with local colors for now
    rl.DrawTextEx(rl.GetFontDefault(), strings.clone_to_cstring(title, context.temp_allocator), 
                  title_pos, 24, 1, UI_COLORS.TEXT)
    
    // Draw input field
    input_rect := rl.Rectangle{
        dialog_x + 10,
        dialog_y + 50,
        dialog_width - 20,
        30,
    }
    rl.DrawRectangleRec(input_rect, UI_COLORS.INPUT_BG)
    rl.DrawRectangleLinesEx(input_rect, 1, UI_COLORS.HOVER)
    
    // Draw input text
    input_text := string(file_dialog_state.input_buffer[:file_dialog_state.input_length])
    if file_dialog_state.input_length > 0 {
        rl.DrawTextEx(rl.GetFontDefault(), strings.clone_to_cstring(input_text, context.temp_allocator),
                     {input_rect.x + 5, input_rect.y + 6}, 18, 1, UI_COLORS.TEXT)
    }
    
    // Draw cursor
    cursor_x := input_rect.x + 5 + rl.MeasureTextEx(rl.GetFontDefault(), 
                strings.clone_to_cstring(input_text, context.temp_allocator), 18, 1).x
    if int(rl.GetTime() * 2) % 2 == 0 {  // Blinking cursor
        rl.DrawRectangle(i32(cursor_x), i32(input_rect.y + 6), 2, 18, UI_COLORS.TEXT)
    }
    
    // Draw instructions
    instructions: string
    switch file_dialog_state.mode {
    case .SAVE, .LOAD:
        instructions = "Format: .json | Enter: Confirm | Escape: Cancel"
    case .IMPORT:
        instructions = "Formats: .gltf .glb .obj | Enter: Confirm | Escape: Cancel"
    case .HDRI_IMPORT:
        instructions = "Formats: .hdr .exr .png .jpg .tga .bmp | Enter: Confirm | Escape: Cancel"
    }
    
    rl.DrawTextEx(rl.GetFontDefault(), strings.clone_to_cstring(instructions, context.temp_allocator),
                 {dialog_x + 10, dialog_y + dialog_height - 30}, 16, 1, UI_COLORS.TEXT_MUTED)
}

// Check if dialog is visible (blocks other input)
is_file_dialog_visible :: proc() -> bool {
    return file_dialog_state.visible
}

// Check if dialog was completed and return the result
check_dialog_completion :: proc() -> (filepath: string, mode: File_Dialog_Mode, completed: bool) {
    if file_dialog_state.completed {
        // Return completion data and reset
        result_filepath := file_dialog_state.completed_filepath
        result_mode := file_dialog_state.mode
        file_dialog_state.completed = false
        file_dialog_state.completed_filepath = ""
        return result_filepath, result_mode, true
    }
    return "", .SAVE, false
}