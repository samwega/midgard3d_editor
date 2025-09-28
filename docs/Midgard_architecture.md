## Midgard Editor - Current Architecture

### Core Design Principles

1. **Single Package** - All code compiles as one Odin package with organized subdirectories
2. **Module Organization** - Clear separation of concerns within the package
3. **Pure Quaternion Mathematics** - **MANDATORY** - All rotation operations use quaternions to eliminate gimbal lock and ensure unlimited rotation freedom
4. **Minimal Dependencies** - Modules depend only on what they need
5. **Export-Ready** - Structure prepared for future data export features
6. **Clean Interfaces** - Well-defined module boundaries

### Current Directory Structure

```
midgard_3d_editor/
├── src/                          # Single Odin package
│   ├── main.odin                # Entry point
│   ├── core/
│   │   └── types.odin           # Shared fundamental types
│   ├── scene/
│   │   ├── scene.odin           # Scene, Scene_Object definitions
│   │   └── operations.odin      # Add/remove/modify objects
│   ├── camera/
│   │   ├── camera.odin          # Camera_State, camera types
│   │   └── controls.odin        # Camera control logic
│   ├── input/
│   │   └── input.odin           # Input_State and input processing
│   ├── selection/               # ✓ IMPLEMENTED
│   │   ├── raycast.odin         # Mouse-to-world ray casting
│   │   └── selection.odin       # Selection state management
│   ├── serialization/           # ✓ IMPLEMENTED
│   │   ├── save_load.odin       # JSON scene serialization
│   │   └── file_dialog.odin     # File dialog UI system
│   ├── ui/                      # ✓ IMPLEMENTED
│   │   ├── ui_state.odin        # UI state management
│   │   ├── widgets.odin         # Immediate-mode widget library
│   │   ├── inspector.odin       # Object property editor panel
│   │   ├── hierarchy.odin       # Scene hierarchy panel
│   │   └── menu_bar.odin        # File menu and top menu bar
│   ├── rendering/               # ✓ IMPLEMENTED
│   │   ├── renderer.odin        # Main render orchestration
│   │   ├── grid.odin            # Grid and axis rendering
│   │   ├── objects.odin         # 3D object rendering
│   │   └── ui.odin              # 2D UI rendering
│   ├── resources/               # ✓ IMPLEMENTED
│   │   ├── fonts.odin           # Font loading and management
│   │   └── hdri.odin            # Skybox system and HDRI loading
│   ├── editor/                  # ✓ IMPLEMENTED
│   │   └── editor.odin          # Editor_State and coordination
│   ├── plugins/                 # ✓ IMPLEMENTED
│   │   ├── plugins.odin         # Plugin system core (registration, lifecycle, UI)
│   │   ├── bundled/             # Bundled plugins shipped with editor
│   │   │   └── obj_import/      # OBJ model import plugin
│   │   │       ├── plugin.odin      # Plugin interface and callbacks
│   │   │       ├── loader.odin      # OBJ model loading logic
│   │   │       ├── validation.odin  # File safety validation
│   │   │       └── mtl_processing.odin # MTL material processing
│   │   └── community/           # Directory for community plugins
│   ├── editor_state/            # ✓ IMPLEMENTED
│   │   └── editor_state.odin    # Editor state definition (breaks circular deps)
│   ├── model_import/            # ✓ IMPLEMENTED (core formats only)
│   │   └── model_loader.odin    # glTF/GLB model loading (Raylib integration)
│   ├── gizmo/                   # ✓ IMPLEMENTED
│   │   ├── gizmo_state.odin     # Gizmo state management
│   │   ├── gizmo_render.odin    # Gizmo rendering
│   │   └── gizmo_interaction.odin # Gizmo interaction handling
│   └── debug/
│       └── memory.odin          # Debug utilities
├── assets/
│   ├── fonts/                   # Font files
│   ├── shaders/                 # Skybox and custom shaders
│   └── skyboxes/                # Example skybox images
└── docs/
    ├── Camera_System.md                     # Camera controls documentation
    ├── Gizmo_System.md                      # Transformation tools documentation
    ├── Import_System.md                     # Model import system documentation
    ├── Inspector_System.md                  # UI system documentation
    ├── Midgard_architecture.md              # This document
    ├── Plugin_System.md                     # Plugin system documentation
    ├── Rendering_System.md                  # Rendering pipeline documentation
    ├── Selection_System.md                  # Object selection documentation
    ├── Serialization_System.md              # Scene persistence documentation
    ├── Skybox_System.md                     # Skybox system documentation
```

---

## Current Implementation Status

All core systems are implemented and functional:

### ✓ IMPLEMENTED SYSTEMS

- **Core Types**: Fundamental data structures (Transform, Object_Type, Mesh_Data)
- **Scene Management**: Scene graph and object operations
- **Camera System**: Quaternion-based orbital and free-look camera controls with unlimited rotation freedom
- **Input Handling**: Mouse and keyboard input processing
- **Selection System**: Ray-casting and object selection with visual feedback
- **Serialization System**: JSON scene persistence with file operations
- **UI System**: Immediate-mode widgets, inspector panel, and file menu
- **Rendering**: 3D rendering, adaptive grid, and UI rendering
- **Resources**: Font loading with graceful fallbacks and skybox system
- **Model Import System**: Core glTF/GLB loading + extensible plugin architecture
- **Plugin System**: Build-time configurable plugins with runtime management
- **Editor**: Main loop coordination and state management
- **Gizmo System**: Interactive 3D transformation tools using pure quaternion mathematics for stable object manipulation
- **Skybox System**: Environmental background rendering with multi-format support

### Key Features

- **3D Scene Editor**: Godot-style interface with object manipulation
- **Save/Load System**: JSON scene persistence with file dialogs and keyboard shortcuts
- **Adaptive Grid**: Distance-responsive 2-level grid system
- **Object Selection**: Left-click selection with orange/yellow visual feedback
- **Camera Controls**: Quaternion-based right-click free-look and middle-click orbit/pan with unlimited 360° rotation
- **Inspector Panel**: Real-time property editing for selected objects
- **Menu System**: Professional file menu with unsaved changes tracking
- **Font System**: Multiple font loading with automatic fallbacks
- **Model Import**: Core glTF/GLB support + OBJ via plugin, extensible architecture for additional formats
- **Plugin System**: Build-time enabled plugins with P key runtime management panel
- **Gizmo System**: Professional quaternion-based 3D transformation tools with sphere-based rotation visualization
- **HDR Skybox System**: True HDR environmental backgrounds with custom Radiance HDR parser, RLE decompression, float texture pipeline, and real-time exposure/rotation controls

---

## Module Dependencies

Clean dependency flow within the single package:
```
main
 └─> editor (orchestration)
      ├─> scene ──> core (types)
      ├─> camera ──> input
      ├─> selection ──> scene, core
      ├─> serialization ──> scene, core, model_import
      ├─> ui ──> core
      ├─> plugins ──> editor_state, core
      ├─> rendering ──> scene, camera, selection, serialization, ui, plugins, resources
      ├─> model_import ──> core
      ├─> gizmo ──> scene, core
      └─> resources (fonts, skybox)
```

### Module Responsibilities

- **core/types.odin**: Fundamental data structures (Transform, Object_Type, Mesh_Data)
- **scene/**: Scene graph management and object operations
- **camera/**: Quaternion-based camera state and control systems (orbital/free-look with unlimited rotation)
- **input/input.odin**: Input handling and state management
- **selection/**: Ray-casting and object selection with visual feedback
- **serialization/**: JSON scene persistence and file dialog system
- **ui/**: Immediate-mode UI system with inspector, hierarchy, and menu bar
- **resources/**: Asset loading (fonts, HDR skybox system) with automatic fallbacks and custom file format support
- **plugins/plugins.odin**: Plugin system core with registration, lifecycle, and runtime management
- **editor_state/editor_state.odin**: Editor state definition (isolated to break circular dependencies)
- **model_import/model_loader.odin**: Core model loading (glTF/GLB via Raylib)
- **rendering/**: 3D rendering, adaptive grid, and UI rendering
- **editor/editor.odin**: High-level coordination and main loop
- **debug/memory.odin**: Debug utilities (memory tracking removed)
- **gizmo/**: Professional quaternion-based transformation tools with sphere-based rotation gizmo

### Main Loop (60 FPS)

1. **Plugin system initialization** (once at startup)
2. **Input processing** (input module)
3. **File dialog handling** (serialization module)
4. **Menu action processing** (ui → editor coordination)
5. **Camera updates** (camera module) 
6. **Selection updates** (selection module)
7. **Scene management** (scene module)
8. **Plugin updates** (plugins module - per frame)
9. **UI updates** (ui module)
10. **Rendering** (rendering module - including skybox rendering)

---

## Key Architectural Decisions

### 1. **Single Package Architecture**

- **Simplicity**: All code compiles as one unit, no complex import paths
- **Performance**: No package boundaries to cross during compilation
- **Flexibility**: Easy refactoring without worrying about package dependencies
- **Appropriate Scale**: Current ~3000 lines fits well in single package

### 2. **Module Organization**

- **core/**: Fundamental types shared across modules
- **scene/**: Scene graph and object management 
- **camera/**: Dual-mode camera system (orbital/free-look)
- **input/**: Centralized input state management
- **selection/**: Ray-casting with visual feedback system
- **ui/**: Immediate-mode widgets with inspector integration
- **rendering/**: All drawing code centralized for easier maintenance
- **resources/**: Asset loading with automatic fallbacks
- **editor/**: High-level orchestration and main loop

### 3. **Save/Load System Architecture**

- **JSON Serialization**: Human-readable scene files with type conversion from Raylib types
- **Flag-Based Dialogs**: Non-blocking file dialogs using completion flags instead of complex closures
- **Unsaved Change Tracking**: Automatic marking of modifications across all scene operations
- **Professional File Menu**: Standard file operations (New, Open, Save, Save As) with keyboard shortcuts

### 4. **Future Scalability**

- **Multi-package ready**: Can split into packages when needed (>10k lines)
- **Export systems**: Structure prepared for data export features
- **Plugin interfaces**: Clean module boundaries support future plugins
- **Renderer abstraction**: Rendering isolated for potential backend swaps

---

## Build Commands

```bash
# Release build
odin build src -out:midgard.exe

# Optimized build with timing
odin build src -o:speed -show-timings -out:midgard.exe

# Run the editor
./midgard.exe
```

---

## Benefits of Current Architecture

1. **Fast Compilation**: Single package compiles quickly
2. **Code Navigation**: Clear modular organization within package
3. **Maintenance**: Easy to understand and modify
4. **Scalable**: Can evolve to multi-package when needed
5. **Export Ready**: Structure prepared for data export systems

---

## Future Development

1. **Export System**: Add JSON/binary scene data export
2. **Plugin Architecture**: Leverage clean module boundaries
3. **Multi-package Split**: When codebase exceeds 10,000 lines
4. **Hot Reload**: Debug system can support live code updates

The current ~4000 line codebase fits perfectly in this single-package structure.

---

## System Documentation

- **Inspector System**: See `Inspector_System.md` for detailed UI system documentation
- **Memory Tracking**: Memory tracking system was removed (see CLAUDE.md for details)
- **Gizmo System**: See `Gizmo_System.md` for detailed transformation tools documentation
- **Skybox System**: See `Skybox_System.md` for detailed environmental rendering documentation

---

## glTF Import System

### Implementation Details

The `gltf_import` module provides 3D model loading capabilities using Raylib's built-in model loader:

#### Core Components

- **gltf_loader.odin**: Main import functionality
  - `load_gltf_model()`: Load .gltf/.glb files via Raylib
  - `create_mesh_data()`: Create mesh data structure with bounds calculation
  - `calculate_model_bounds()`: Calculate bounding box for selection ray-casting
  - `cleanup_mesh_data()`: Memory management for loaded models

#### Integration Points

- **Core Types**: Extended `Object_Type` enum with `MESH`, added `Mesh_Data` structure
- **Scene System**: Scene objects can reference mesh data, proper cleanup on deletion
- **Selection**: Mesh bounds calculation for accurate ray-casting
- **Rendering**: Mesh rendering with material preservation and wireframe highlights
- **Serialization**: Mesh source file paths saved in JSON, graceful fallback for missing files
- **UI**: Inspector and hierarchy support for mesh objects

#### File Format Support

- **.gltf**: JSON + external files format
- **.glb**: Binary format
- **Materials**: Preserved from source files
- **Textures**: Loaded automatically by Raylib
- **Fallback**: Missing files convert to red cubes with error messages

#### Usage

- **Import**: Ctrl+I or 4 key opens import dialog
- **Placement**: Models spawn 5 units in front of camera
- **Selection**: Meshes work identically to primitives for manipulation
- **Persistence**: Source file paths saved in scene JSON for reload

---

## Gizmo System

### Implementation Details

The `gizmo` module provides professional-grade 3D transformation tools for object manipulation:

#### Core Components

- **gizmo_state.odin**: Gizmo state management, modes, and handle types
- **gizmo_render.odin**: Professional sphere-based visualization with distance-compensated scaling
- **gizmo_interaction.odin**: Robust mouse interaction and rotation mathematics

#### Transformation Modes

- **TRANSLATE**: Traditional arrow-based translation gizmo with axis and plane constraints
- **ROTATE**: Sphere-based rotation gizmo with Blender-style visualization and intuitive controls
- **SCALE**: Cube handles for axis and uniform scaling with visual feedback
- **TRANSFORM**: A universal gizmo combining translation, rotation, and scale.
- **NONE**: Disabled state for unobstructed scene navigation

#### Rotation Gizmo Features

- **Sphere-based visualization**: Three colored circles positioned on invisible sphere around object
- **World-space rotation**: Rotations applied around world coordinate axes
- **Camera-relative rotation**: White outer circle for camera-to-object axis rotation
- **Distance compensation**: Consistent screen-space sizing at all camera distances
- **Front-face culling**: Only visible halves of circles drawn to eliminate visual confusion
- **Intuitive controls**: Natural rotation direction matching visual circle movement

#### Integration Points

- **Scene System**: Works with all object types (primitives and imported meshes)
- **Selection**: Activates automatically on selected objects
- **Camera**: Screen-space calculations adapt to camera position and orientation
- **Input**: Consumes mouse input when active to prevent selection conflicts
- **Rendering**: Professional visualization with proper depth handling and visual feedback

#### Usage

- **Mode Switching**: Q=NONE, W=TRANSLATE, E=ROTATE, R=SCALE (when not flying)
- **Axis Constraints**: X/Y/Z keys for single-axis operation, Ctrl+X/Y/Z to toggle, Shift+X/Y/Z for plane constraints
- **Grid Snapping**: G key toggles grid snapping for precise positioning
- **Visual Feedback**: Yellow highlights for hovered handles, consistent color coding (X=Red, Y=Green, Z=Blue)