#+build windows
package serialization

import "core:strings"
import win "core:sys/windows"
import "core:fmt"
import rl "vendor:raylib"

// Native Windows file dialog implementation
// Provides a much better user experience than the text-based dialog

// Show native Windows file open dialog for importing models
show_native_import_dialog :: proc() -> (filepath: string, success: bool) {
    // Create buffer for selected file path
    file_buf := make([]u16, win.MAX_PATH_WIDE, context.temp_allocator)
    
    // Define file filters for 3D model formats
    filter_string := strings.concatenate({
        "3D Model Files", "\x00",
        "*.obj;*.gltf;*.glb", "\x00",
        "OBJ Files (*.obj)", "\x00",
        "*.obj", "\x00", 
        "glTF Files (*.gltf)", "\x00",
        "*.gltf", "\x00",
        "GLB Files (*.glb)", "\x00", 
        "*.glb", "\x00",
        "All Files (*.*)", "\x00",
        "*.*", "\x00",
        "\x00",  // Double null terminator required
    }, context.temp_allocator)
    
    // Convert filter string to wide string
    filter_wide := win.utf8_to_wstring(filter_string, context.temp_allocator)
    
    // Set up OPENFILENAME structure
    ofn := win.OPENFILENAMEW{
        lStructSize     = size_of(win.OPENFILENAMEW),
        hwndOwner       = nil,  // Use desktop as parent - Raylib window handle not easily accessible
        lpstrFile       = win.wstring(&file_buf[0]),
        nMaxFile        = win.MAX_PATH_WIDE,
        lpstrFilter     = filter_wide,
        nFilterIndex    = 1,  // Default to "3D Model Files" filter
        lpstrTitle      = win.utf8_to_wstring("Import 3D Model", context.temp_allocator),
        lpstrInitialDir = win.utf8_to_wstring("assets/models", context.temp_allocator), // Default to models directory
        Flags           = win.OFN_PATHMUSTEXIST | win.OFN_FILEMUSTEXIST | win.OFN_EXPLORER,
    }
    
    // Show the dialog
    result := win.GetOpenFileNameW(&ofn)
    
    if result {
        // Convert the selected path back to UTF-8
        selected_path, conversion_error := win.wstring_to_utf8(win.wstring(&file_buf[0]), -1, context.temp_allocator)
        
        if conversion_error == nil && len(selected_path) > 0 {
            return strings.clone(selected_path), true
        }
    }
    
    return "", false
}

// Show native Windows file open dialog for loading scenes
show_native_load_dialog :: proc() -> (filepath: string, success: bool) {
    file_buf := make([]u16, win.MAX_PATH_WIDE, context.temp_allocator)
    
    filter_string := strings.concatenate({
        "Scene Files (*.json)", "\x00",
        "*.json", "\x00",
        "All Files (*.*)", "\x00", 
        "*.*", "\x00",
        "\x00",
    }, context.temp_allocator)
    
    filter_wide := win.utf8_to_wstring(filter_string, context.temp_allocator)
    
    ofn := win.OPENFILENAMEW{
        lStructSize     = size_of(win.OPENFILENAMEW),
        hwndOwner       = nil,
        lpstrFile       = win.wstring(&file_buf[0]),
        nMaxFile        = win.MAX_PATH_WIDE,
        lpstrFilter     = filter_wide,
        nFilterIndex    = 1,
        lpstrTitle      = win.utf8_to_wstring("Load Scene", context.temp_allocator),
        lpstrInitialDir = win.utf8_to_wstring(".", context.temp_allocator),
        Flags           = win.OFN_PATHMUSTEXIST | win.OFN_FILEMUSTEXIST | win.OFN_EXPLORER,
    }
    
    result := win.GetOpenFileNameW(&ofn)
    
    if result {
        selected_path, conversion_error := win.wstring_to_utf8(win.wstring(&file_buf[0]), -1, context.temp_allocator)
        
        if conversion_error == nil && len(selected_path) > 0 {
            return strings.clone(selected_path), true
        }
    }
    
    return "", false
}

// Show native Windows file save dialog for saving scenes
show_native_save_dialog :: proc(default_filename := "scene.json") -> (filepath: string, success: bool) {
    file_buf := make([]u16, win.MAX_PATH_WIDE, context.temp_allocator)
    
    // Pre-fill with default filename
    default_wide := win.utf8_to_utf16(default_filename, context.temp_allocator)
    copy(file_buf[:len(default_wide)], default_wide)
    
    filter_string := strings.concatenate({
        "Scene Files (*.json)", "\x00",
        "*.json", "\x00",
        "All Files (*.*)", "\x00",
        "*.*", "\x00", 
        "\x00",
    }, context.temp_allocator)
    
    filter_wide := win.utf8_to_wstring(filter_string, context.temp_allocator)
    
    ofn := win.OPENFILENAMEW{
        lStructSize     = size_of(win.OPENFILENAMEW),
        hwndOwner       = nil,
        lpstrFile       = win.wstring(&file_buf[0]),
        nMaxFile        = win.MAX_PATH_WIDE,
        lpstrFilter     = filter_wide,
        nFilterIndex    = 1,
        lpstrTitle      = win.utf8_to_wstring("Save Scene", context.temp_allocator),
        lpstrInitialDir = win.utf8_to_wstring(".", context.temp_allocator),
        lpstrDefExt     = win.utf8_to_wstring("json", context.temp_allocator),
        Flags           = win.OFN_OVERWRITEPROMPT | win.OFN_EXPLORER,
    }
    
    result := win.GetSaveFileNameW(&ofn)
    
    if result {
        selected_path, conversion_error := win.wstring_to_utf8(win.wstring(&file_buf[0]), -1, context.temp_allocator)
        
        if conversion_error == nil && len(selected_path) > 0 {
            return strings.clone(selected_path), true
        }
    }
    
    return "", false
}

// Show native Windows file open dialog for importing HDRI files
show_native_hdri_dialog :: proc() -> (filepath: string, success: bool) {
    // Create buffer for selected file path
    file_buf := make([]u16, win.MAX_PATH_WIDE, context.temp_allocator)
    
    // Define file filters for skybox image formats
    filter_string := strings.concatenate({
        "Skybox Images", "\x00",
        "*.hdr;*.exr;*.png;*.jpg;*.jpeg;*.tga;*.bmp", "\x00",
        "HDR Files (*.hdr)", "\x00",
        "*.hdr", "\x00", 
        "EXR Files (*.exr)", "\x00",
        "*.exr", "\x00",
        "PNG Files (*.png)", "\x00",
        "*.png", "\x00",
        "JPG Files (*.jpg)", "\x00",
        "*.jpg;*.jpeg", "\x00",
        "All Files (*.*)", "\x00",
        "*.*", "\x00",
        "\x00",  // Double null terminator required
    }, context.temp_allocator)
    
    // Convert filter string to wide string
    filter_wide := win.utf8_to_wstring(filter_string, context.temp_allocator)
    
    // Set up OPENFILENAME structure
    ofn := win.OPENFILENAMEW{
        lStructSize     = size_of(win.OPENFILENAMEW),
        hwndOwner       = nil,  // Use desktop as parent - Raylib window handle not easily accessible
        lpstrFile       = win.wstring(&file_buf[0]),
        nMaxFile        = win.MAX_PATH_WIDE,
        lpstrFilter     = filter_wide,
        nFilterIndex    = 1,  // Default to "HDRI Files" filter
        lpstrTitle      = win.utf8_to_wstring("Import HDRI", context.temp_allocator),
        lpstrInitialDir = win.utf8_to_wstring("assets", context.temp_allocator), // Default to assets directory
        Flags           = win.OFN_PATHMUSTEXIST | win.OFN_FILEMUSTEXIST | win.OFN_EXPLORER,
    }
    
    // Show the dialog
    result := win.GetOpenFileNameW(&ofn)
    
    if result {
        // Convert the selected path back to UTF-8
        selected_path, conversion_error := win.wstring_to_utf8(win.wstring(&file_buf[0]), -1, context.temp_allocator)
        
        if conversion_error == nil && len(selected_path) > 0 {
            return strings.clone(selected_path), true
        }
    }
    
    return "", false
}