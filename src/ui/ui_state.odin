package ui

import rl "vendor:raylib"

UI_State :: struct {
    // Right sidebar state (unified)
    right_panel: Panel_State,
    
    // Plugin panel state
    plugin_panel_visible: bool,

    // Keymap panel state
    keymap_visible: bool,
    
    // UI interaction state
    mouse_over_ui: bool,
    active_widget: Widget_ID,
    hot_widget: Widget_ID,
    
    // Drag state tracking
    drag_started_in_world: bool, // true if RMB/MMB drag started outside UI
    
    // Widget navigation
    widget_navigation_requested: Navigation_Direction,
    max_widget_id_this_frame: Widget_ID,
    
    // Menu system
    menu_selection: Menu_Item,
    
    // Layout constants
    right_panel_width: f32,
    panel_padding: f32,
    widget_height: f32,
    spacing: f32,
}

Panel_State :: struct {
    visible: bool,
    panel_rect: rl.Rectangle,
    scroll_offset: f32,
    content_height: f32,
}

Navigation_Direction :: enum {
    NONE,
    NEXT,
    PREVIOUS,
}

// Menu item result for the editor to handle
Menu_Item :: enum {
    NONE,
    NEW_SCENE,
    OPEN_SCENE,
    SAVE_SCENE,
    SAVE_AS_SCENE,
    IMPORT_ASSET,
    EXIT,
}

Widget_ID :: distinct u32

// Widget ID generation (simple counter)
next_widget_id: Widget_ID = 1

generate_widget_id :: proc(ui_state: ^UI_State) -> Widget_ID {
    id := next_widget_id
    next_widget_id += 1
    // Track the maximum widget ID for navigation
    ui_state.max_widget_id_this_frame = id
    return id
}

init :: proc() -> UI_State {
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())
    right_panel_width := f32(300)
    
    right_panel_rect := rl.Rectangle{
        x = screen_width - right_panel_width,
        y = 0,
        width = right_panel_width,
        height = screen_height,
    }
    
    return UI_State{
        right_panel = Panel_State{
            visible = true,
            panel_rect = right_panel_rect,
            scroll_offset = 0,
            content_height = 0,
        },
        plugin_panel_visible = false,
        keymap_visible = false,
        mouse_over_ui = false,
        active_widget = 0,
        hot_widget = 0,
        drag_started_in_world = false,
        widget_navigation_requested = .NONE,
        max_widget_id_this_frame = 0,
        menu_selection = .NONE,
        right_panel_width = right_panel_width,
        panel_padding = 10,
        widget_height = 30,
        spacing = 8,
    }
}

// Update UI state - called before processing widgets
begin_ui :: proc(ui_state: ^UI_State) {
    // Handle navigation requests from previous frame
    if ui_state.widget_navigation_requested == .NEXT && ui_state.active_widget > 0 {
        if ui_state.active_widget < ui_state.max_widget_id_this_frame {
            ui_state.active_widget += 1
        }
    } else if ui_state.widget_navigation_requested == .PREVIOUS && ui_state.active_widget > 1 {
        ui_state.active_widget -= 1
    }
    
    // Reset per-frame state
    ui_state.hot_widget = 0
    ui_state.mouse_over_ui = false
    ui_state.widget_navigation_requested = .NONE
    ui_state.max_widget_id_this_frame = 0
    
    // Check if mouse is over any UI panel
    mouse_pos := rl.GetMousePosition()
    right_panel_collision := ui_state.right_panel.visible && rl.CheckCollisionPointRec(mouse_pos, ui_state.right_panel.panel_rect)
    hierarchy_collision := is_mouse_over_hierarchy()
    menubar_collision := rl.CheckCollisionPointRec(mouse_pos, rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), get_menu_bar_height()})
    
    // Check if mouse is over dropdown menus
    dropdown_collision := is_mouse_over_dropdown_menus()
    
    ui_state.mouse_over_ui = right_panel_collision || hierarchy_collision || menubar_collision || dropdown_collision
    
    // Simple drag tracking: if RMB or MMB is currently held AND was pressed outside UI, allow drag-through
    rmb_held := rl.IsMouseButtonDown(rl.MouseButton.RIGHT)
    mmb_held := rl.IsMouseButtonDown(rl.MouseButton.MIDDLE)
    
    // Set drag state when camera buttons are first pressed outside UI
    if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) || rl.IsMouseButtonPressed(rl.MouseButton.MIDDLE) {
        ui_state.drag_started_in_world = !ui_state.mouse_over_ui
    }
    
    // Clear drag state when no camera buttons are held
    if !rmb_held && !mmb_held {
        ui_state.drag_started_in_world = false
    }
    
    // Reset widget ID counter for consistent IDs per frame
    next_widget_id = 1
}

// Finish UI processing - called after all widgets
end_ui :: proc(ui_state: ^UI_State) {
    // Handle mouse clicks outside any widget to deactivate
    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        if ui_state.hot_widget == 0 {
            ui_state.active_widget = 0
        }
    }
    
    // Also deactivate on Escape key
    if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
        ui_state.active_widget = 0
    }
}

// Check if mouse is over UI (prevents 3D interaction)
is_mouse_over_ui :: proc(ui_state: ^UI_State) -> bool {
    return ui_state.mouse_over_ui
}

// Check if UI should block scene input (more sophisticated than just mouse position)
should_block_scene_input :: proc(ui_state: ^UI_State) -> bool {
    // Always allow camera drag-through if RMB/MMB drag started in world
    rmb_held := rl.IsMouseButtonDown(rl.MouseButton.RIGHT)
    mmb_held := rl.IsMouseButtonDown(rl.MouseButton.MIDDLE)
    
    if (rmb_held || mmb_held) && ui_state.drag_started_in_world {
        return false
    }
    
    // Block if mouse is over any UI panel
    return ui_state.mouse_over_ui
}

// Toggle right panel visibility
toggle_right_panel :: proc(ui_state: ^UI_State) {
    ui_state.right_panel.visible = !ui_state.right_panel.visible
}

// Handle window resize
handle_resize :: proc(ui_state: ^UI_State) {
    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())
    
    ui_state.right_panel.panel_rect.x = screen_width - ui_state.right_panel_width
    ui_state.right_panel.panel_rect.y = 0
    ui_state.right_panel.panel_rect.height = screen_height
}

// Handle navigation input - call this when processing keyboard input
handle_navigation_input :: proc(ui_state: ^UI_State) {
    if ui_state.active_widget > 0 {
        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            ui_state.widget_navigation_requested = .NEXT
        }
        if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            ui_state.widget_navigation_requested = .PREVIOUS
        }
    }
}