package ui

import "../serialization"
import "../scene"
import "core:strings"
import "core:path/filepath"
import "core:fmt"
import rl "vendor:raylib"

// Menu bar state
Menu_Bar_State :: struct {
    height: f32,
    file_menu_open: bool,
    view_menu_open: bool,
}

menu_bar_state := Menu_Bar_State{
    height = 30,
    file_menu_open = false,
    view_menu_open = false,
}

// Draw menu bar and handle immediate interactions
draw_menu_bar :: proc(ui_state: ^UI_State) {
    screen_width := f32(rl.GetScreenWidth())
    
    // Draw menu bar background with transparency
    menu_rect := rl.Rectangle{0, 0, screen_width, menu_bar_state.height}
    menubar_bg := UI_COLORS.SECONDARY
    menubar_bg.a = 220 // Match keymap panel transparency
    rl.DrawRectangleRec(menu_rect, menubar_bg)

    menubar_border := UI_COLORS.BORDER
    menubar_border.a = 220
    rl.DrawRectangleLinesEx(menu_rect, 1, menubar_border)
    
    // --- Menu Buttons ---
    mouse_pos := rl.GetMousePosition()
    
    // Base X position for menus (moves with hierarchy panel)
    base_x := f32(5)
    if is_hierarchy_visible() {
        base_x = get_hierarchy_width() + 5
    }
    
    // --- File Menu ---
    file_button_rect := rl.Rectangle{base_x, 2, 60, menu_bar_state.height - 4}
    file_hovered := rl.CheckCollisionPointRec(mouse_pos, file_button_rect)
    
    if file_hovered {
        rl.DrawRectangleRec(file_button_rect, UI_COLORS.HOVER)
    }
    
    text_pos := rl.Vector2{file_button_rect.x + 10, file_button_rect.y + 4}
    draw_text(.REGULAR, "File", text_pos, UI_COLORS.TEXT)
    
    // --- View Menu ---
    view_button_rect := rl.Rectangle{base_x + 65, 2, 60, menu_bar_state.height - 4}
    view_hovered := rl.CheckCollisionPointRec(mouse_pos, view_button_rect)
    
    if view_hovered {
        rl.DrawRectangleRec(view_button_rect, UI_COLORS.HOVER)
    }
    
    text_pos = rl.Vector2{view_button_rect.x + 10, view_button_rect.y + 4}
    draw_text(.REGULAR, "View", text_pos, UI_COLORS.TEXT)
    
    // --- Draw Centered Filename ---
    filename := serialization.get_current_filename()
    if serialization.has_unsaved_changes() {
        filename = strings.concatenate({filename, "*"}, context.temp_allocator)
    }
    
    filename_width := measure_text(.REGULAR, strings.clone_to_cstring(filename, context.temp_allocator)).x
    window_center := screen_width / 2
    filename_x := window_center - (filename_width / 2)
    
    draw_text(.REGULAR, strings.clone_to_cstring(filename, context.temp_allocator), {filename_x, 6}, UI_COLORS.TEXT)
    
    // Handle menu button clicks
    if file_hovered && rl.IsMouseButtonPressed(.LEFT) {
        menu_bar_state.file_menu_open = !menu_bar_state.file_menu_open
        menu_bar_state.view_menu_open = false  // Close other menus
    }
    
    if view_hovered && rl.IsMouseButtonPressed(.LEFT) {
        menu_bar_state.view_menu_open = !menu_bar_state.view_menu_open
        menu_bar_state.file_menu_open = false  // Close other menus
    }
    
    // Close menus when clicking elsewhere (but not inside dropdown menu areas)
    if rl.IsMouseButtonPressed(.LEFT) {
        // Check if click is within any menu or dropdown area
        file_dropdown_rect := rl.Rectangle{base_x, menu_bar_state.height, 300, 200} // File menu dropdown area
        view_dropdown_rect := rl.Rectangle{base_x + 65, menu_bar_state.height, 220, 75} // View menu dropdown area
        
        click_in_ui := rl.CheckCollisionPointRec(mouse_pos, file_button_rect) ||
                       rl.CheckCollisionPointRec(mouse_pos, view_button_rect) ||
                       (menu_bar_state.file_menu_open && rl.CheckCollisionPointRec(mouse_pos, file_dropdown_rect)) ||
                       (menu_bar_state.view_menu_open && rl.CheckCollisionPointRec(mouse_pos, view_dropdown_rect))
        
        if !click_in_ui {
            menu_bar_state.file_menu_open = false
            menu_bar_state.view_menu_open = false
        }
    }
}

// Draw dropdown menus (call this after all other UI elements)
draw_menu_dropdowns :: proc(ui_state: ^UI_State) {
    // Base X position for menus
    base_x := f32(5)
    if is_hierarchy_visible() {
        base_x = get_hierarchy_width() + 5
    }

    // --- File Menu Dropdown ---
    if menu_bar_state.file_menu_open {
        file_menu_pos := rl.Vector2{base_x, menu_bar_state.height}
        selected_item := draw_file_menu(file_menu_pos)
        if selected_item != .NONE {
            ui_state.menu_selection = selected_item
            menu_bar_state.file_menu_open = false
        }
    }
    
    // --- View Menu Dropdown ---
    if menu_bar_state.view_menu_open {
        view_menu_pos := rl.Vector2{base_x + 65, menu_bar_state.height}
        draw_view_menu(view_menu_pos, ui_state)
        // This menu handles its own state changes, so we don't check for a return value
    }
}

// Draw file menu dropdown
draw_file_menu :: proc(position: rl.Vector2) -> Menu_Item {
    menu_width := f32(300) // Wider to prevent text overlapping
    item_height := f32(25)
    
    items := []string{"New Scene", "Open Scene...", "Save Scene", "Save Scene As...", "---", "Import...", "---", "Exit"}
    menu_height := f32(len(items)) * item_height
    
    // Draw menu background with transparency
    menu_bg := UI_COLORS.BACKGROUND
    menu_bg.a = 220
    menu_rect := rl.Rectangle{position.x, position.y, menu_width, menu_height}
    rl.DrawRectangleRec(menu_rect, menu_bg)

    menu_border := UI_COLORS.BORDER
    menu_border.a = 220
    rl.DrawRectangleLinesEx(menu_rect, 1, menu_border)
    
    mouse_pos := rl.GetMousePosition()
    selected_item := Menu_Item.NONE
    
    for item, i in items {
        item_rect := rl.Rectangle{position.x, position.y + f32(i) * item_height, menu_width, item_height}
        
        if item == "---" {
            rl.DrawLine(i32(item_rect.x + 5), i32(item_rect.y + item_height/2), i32(item_rect.x + menu_width - 5), i32(item_rect.y + item_height/2), UI_COLORS.BORDER)
        } else {
            is_hovered := rl.CheckCollisionPointRec(mouse_pos, item_rect)
            if is_hovered {
                rl.DrawRectangleRec(item_rect, UI_COLORS.HOVER)
            }
            
            shortcut := ""
            switch item {
            case "New Scene":       shortcut = "Ctrl+N"
            case "Open Scene...":   shortcut = "Ctrl+O"
            case "Save Scene":      shortcut = "Ctrl+S"
            case "Save Scene As...":shortcut = "Ctrl+Shift+S"
            case "Import...":       shortcut = "Ctrl+I"
            }
            
            draw_text(.REGULAR, strings.clone_to_cstring(item, context.temp_allocator), {item_rect.x + 10, item_rect.y + 6}, UI_COLORS.TEXT)
            
            if shortcut != "" {
                shortcut_width := measure_text(.SMALL, strings.clone_to_cstring(shortcut, context.temp_allocator)).x
                draw_text(.SMALL, strings.clone_to_cstring(shortcut, context.temp_allocator), {item_rect.x + menu_width - shortcut_width - 10, item_rect.y + 7}, UI_COLORS.TEXT_MUTED)
            }
            
            if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
                switch item {
                case "New Scene":        selected_item = .NEW_SCENE
                case "Open Scene...":    selected_item = .OPEN_SCENE
                case "Save Scene":       selected_item = .SAVE_SCENE
                case "Save Scene As...": selected_item = .SAVE_AS_SCENE
                case "Import...":        selected_item = .IMPORT_ASSET
                case "Exit":             selected_item = .EXIT
                }
            }
        }
    }
    
    return selected_item
}

// Draw view menu dropdown
draw_view_menu :: proc(position: rl.Vector2, ui_state: ^UI_State) {
    menu_width := f32(220)
    item_height := f32(25)
    
    // Panel states for checkboxes
    items := []struct {
        text: string,
        is_visible: bool,
    } {
        {"Show Left Panel", is_hierarchy_visible()},
        {"Show Right Panel", ui_state.right_panel.visible},
        {"Show Keymap", ui_state.keymap_visible},
    }
    
    menu_height := f32(len(items)) * item_height
    
    // Draw menu background with transparency
    menu_bg := UI_COLORS.BACKGROUND
    menu_bg.a = 220
    menu_rect := rl.Rectangle{position.x, position.y, menu_width, menu_height}
    rl.DrawRectangleRec(menu_rect, menu_bg)

    menu_border := UI_COLORS.BORDER
    menu_border.a = 220
    rl.DrawRectangleLinesEx(menu_rect, 1, menu_border)
    
    mouse_pos := rl.GetMousePosition()
    
    for item, i in items {
        item_rect := rl.Rectangle{position.x, position.y + f32(i) * item_height, menu_width, item_height}
        
        is_hovered := rl.CheckCollisionPointRec(mouse_pos, item_rect)
        if is_hovered {
            rl.DrawRectangleRec(item_rect, UI_COLORS.HOVER)
        }
        
        // Draw checkbox
        checkbox_rect := rl.Rectangle{item_rect.x + 10, item_rect.y + 5, 15, 15}
        rl.DrawRectangleLinesEx(checkbox_rect, 1, UI_COLORS.ACCENT)
        if item.is_visible {
            rl.DrawRectangle(i32(checkbox_rect.x+3), i32(checkbox_rect.y+3), i32(checkbox_rect.width-6), i32(checkbox_rect.height-6), UI_COLORS.ACCENT)
        }
        
        // Draw text
        draw_text(.REGULAR, strings.clone_to_cstring(item.text, context.temp_allocator), {item_rect.x + 35, item_rect.y + 6}, UI_COLORS.TEXT)
        
        // Handle click
        if is_hovered && rl.IsMouseButtonPressed(.LEFT) {
            switch item.text {
            case "Show Left Panel":
                toggle_hierarchy()
            case "Show Right Panel":
                toggle_right_panel(ui_state)
            case "Show Keymap":
                ui_state.keymap_visible = !ui_state.keymap_visible
            }
            // Close menu after selection
            menu_bar_state.view_menu_open = false
        }
    }
}


// Get menu bar height for layout adjustment
get_menu_bar_height :: proc() -> f32 {
    return menu_bar_state.height
}

// Check if mouse is over any dropdown menu areas
is_mouse_over_dropdown_menus :: proc() -> bool {
    mouse_pos := rl.GetMousePosition()
    
    // Base X position for menus
    base_x := f32(5)
    if is_hierarchy_visible() {
        base_x = get_hierarchy_width() + 5
    }
    
    // Check file menu dropdown area
    if menu_bar_state.file_menu_open {
        file_dropdown_rect := rl.Rectangle{base_x, menu_bar_state.height, 300, 200}
        if rl.CheckCollisionPointRec(mouse_pos, file_dropdown_rect) {
            return true
        }
    }
    
    // Check view menu dropdown area  
    if menu_bar_state.view_menu_open {
        view_dropdown_rect := rl.Rectangle{base_x + 65, menu_bar_state.height, 220, 75}
        if rl.CheckCollisionPointRec(mouse_pos, view_dropdown_rect) {
            return true
        }
    }
    
    return false
}