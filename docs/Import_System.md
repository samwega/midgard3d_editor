# Import System Documentation

The Midgard 3D Editor supports importing 3D models in multiple formats through a unified import system built on Raylib's model loading capabilities.

## Supported Formats

### glTF (.gltf / .glb)
- **Best for**: Game assets, complex scenes, PBR materials
- **Features**: Full material support, animations (future), embedded textures (.glb)
- **Texture Support**: Automatic loading from embedded or external files

### OBJ (.obj + .mtl)
- **Best for**: Architectural models, static meshes, simple objects
- **Features**: Basic material support, widely compatible
- **Texture Support**: Requires proper MTL file and texture organization

## File Organization Requirements

### OBJ Files - CRITICAL SETUP

For OBJ files to import correctly with materials and textures, follow this exact structure:

```
your_model/
├── model.obj          # Main geometry file
├── model.mtl          # MUST have same name as .obj file
└── textures/          # Texture files (recommended subfolder)
    ├── diffuse.jpg
    ├── normal.jpg
    └── specular.jpg
```

**CRITICAL**: The MTL file MUST have the exact same base name as the OBJ file:
- ✅ `house.obj` + `house.mtl` 
- ❌ `house.obj` + `materials.mtl` (will not work)

### MTL File Format

The MTL file defines materials and must reference textures correctly:

```mtl
# Example MTL file
newmtl Material_001
  Ka 0.200000 0.200000 0.200000    # Ambient color
  Kd 0.800000 0.800000 0.800000    # Diffuse color
  Ks 0.000000 0.000000 0.000000    # Specular color
  Ns 0.000000                      # Shininess
  map_Kd textures/diffuse.jpg      # Diffuse texture path
  map_Ka textures/ambient.jpg      # Ambient texture path
  map_Ks textures/specular.jpg     # Specular texture path
  map_bump textures/normal.jpg     # Normal/bump map
```

**Texture Path Rules**:
1. Paths in MTL are **relative to the OBJ file location**
2. Use forward slashes `/` even on Windows
3. Common folder names: `textures/`, `maps/`, or same directory as OBJ
4. Supported formats: `.jpg`, `.png`, `.tga`, `.bmp`

### glTF Files

glTF files are more self-contained:

```
your_model/
├── model.gltf         # Scene description
├── model.bin          # Binary geometry data (optional)
└── textures/          # External texture files (if not embedded)
    └── *.jpg/png
```

Or for GLB (binary format):
```
your_model/
└── model.glb          # Everything embedded in single file
```

## Import Process

### Using the Import Dialog

#### Native Windows File Dialog (Recommended)

1. **Activate Import**: Press `4` or `Ctrl+I`
2. **Navigate**: Use the standard Windows file picker to browse folders
3. **Filter**: Select file type filter (default: "3D Model Files" shows .obj/.gltf/.glb)
4. **Select**: Click on your model file and press "Open"

**Features**:
- ✅ Standard Windows file browser interface
- ✅ File type filtering (3D models, OBJ only, glTF only, etc.)
- ✅ Directory navigation and shortcuts
- ✅ File previews (where supported by Windows)
- ✅ Automatic path completion and validation

#### Text Fallback Mode 

If the native dialog fails, the system automatically falls back to text input:

1. **Enter File Path**: Type the complete path to your model file
   - Example: `assets/models/house/house.obj`
   - Example: `C:/MyModels/car.gltf`  
2. **Confirm**: Press `Enter` to import
3. **Cancel**: Press `Escape` to close dialog

**Note**: Text mode shows "(Fallback Mode)" in the instructions.

### File Path Examples

#### Relative Paths (Recommended)
```
assets/models/building/building.obj
assets/models/car.glb
content/meshes/furniture.gltf
```

#### Absolute Paths
```
C:/Users/YourName/3DModels/house.obj
D:/Assets/character.glb
```

### Import Results

After import, check the console output for status information:

```
Loaded OBJ model: 3 meshes, 2 materials - assets/models/house/house.obj
Created mesh data for OBJ format: assets/models/house/house.obj
```

## Troubleshooting

### Common OBJ Issues

**Problem**: Model imports but appears gray/untextured
- **Cause**: MTL file not found or incorrectly named
- **Solution**: Ensure MTL file has same name as OBJ file
- **Check**: Look for console message: "No MTL file found at: [path]"

**Problem**: Model imports but some textures missing
- **Cause**: Texture paths in MTL file are incorrect
- **Solution**: Verify texture paths relative to OBJ file location
- **Check**: Console shows warnings about missing textures

**Problem**: "Model file not found" error
- **Cause**: Incorrect file path in import dialog
- **Solution**: Verify the complete path to your OBJ file
- **Tip**: Use forward slashes `/` even on Windows

### Diagnostic Information

The import system provides detailed diagnostics:

#### OBJ Validation Warnings
- Missing UV coordinates → Texturing won't work
- Missing normals → Will generate automatically  
- No faces found → May be point cloud data
- Missing MTL file → Will use default materials

#### Texture Validation
- Missing texture files are reported by filename
- Invalid texture dimensions are detected
- Unsupported formats are rejected

### File Structure Validation

Before import, the system checks:
1. ✅ OBJ file exists and is readable
2. ✅ MTL file exists with matching name
3. ✅ Referenced textures exist at specified paths
4. ✅ Files contain valid geometry data

## Performance Considerations

### Model Complexity
- **Recommended**: < 10,000 triangles per model
- **Maximum**: Limited by GPU memory
- **Optimization**: Use LOD models for complex scenes

### Texture Size
- **Recommended**: Power-of-2 dimensions (512x512, 1024x1024)
- **Maximum**: Depends on GPU capabilities
- **Optimization**: Compress textures for production use

### Material Count
- **Performance**: Fewer materials = better performance
- **Batching**: Models with same material render together
- **Recommendation**: Combine materials where possible

## System Architecture

### Import Flow
1. **File Dialog** (`src/serialization/file_dialog.odin`) - Path input
2. **Model Loader** (`src/model_import/model_loader.odin`) - Format detection & loading
3. **Post-Processing** - Format-specific validation and optimization
4. **Scene Integration** - Object creation and positioning

### Key Components

#### `model_import` Package
- `load_model()` - Universal model loader
- `post_process_obj_model()` - OBJ-specific processing
- `validate_obj_materials()` - Material validation
- `create_mesh_data()` - Scene integration

#### Import Status System
- Real-time import feedback
- Comprehensive error reporting  
- Performance metrics display
- Located in `src/ui/import_status.odin`

## Future Improvements

### Recently Implemented ✅
1. **Native File Browser** - Windows file picker integration (COMPLETED)

### Planned Features
1. **Drag & Drop Import** - Direct file dropping support
2. **Import Presets** - Saved import configurations
3. **Format Conversion** - Converting between formats
4. **Texture Optimization** - Automatic texture compression
5. **Cross-Platform Native Dialogs** - macOS and Linux file dialogs

### Known Limitations
1. No real-time preview during import
2. Limited material property mapping
3. No animation support (planned)
4. Native dialogs only available on Windows (text fallback on other platforms)

## Best Practices

### File Organization
```
project_root/
├── midgard.exe
└── assets/
    └── models/
        ├── architecture/
        │   ├── house/
        │   │   ├── house.obj
        │   │   ├── house.mtl
        │   │   └── textures/
        │   └── bridge/
        └── vehicles/
            └── car/
                ├── car.obj
                ├── car.mtl  
                └── textures/
```

### Naming Conventions
- Use descriptive, consistent names
- Avoid spaces and special characters
- Keep paths reasonably short
- Use lowercase for cross-platform compatibility

### Quality Assurance
1. Always test import before using in production
2. Verify textures display correctly
3. Check material properties in inspector
4. Validate model bounds and scale
5. Test performance impact on scene

---

## Quick Reference

### Import Shortcuts
- `4` or `Ctrl+I` - Open import dialog
- `Enter` - Confirm import
- `Escape` - Cancel import

### Supported Extensions  
- `.gltf` - glTF JSON format
- `.glb` - glTF binary format
- `.obj` - Wavefront OBJ format

### File Requirements
- **OBJ**: Requires matching `.mtl` file for materials
- **glTF**: Can be self-contained or reference external files
- **Textures**: Must be accessible from MTL/glTF texture paths

### Console Commands for Debugging
Check the console output during import for diagnostic information:
- Import success/failure messages
- Material loading status  
- Texture validation results
- Performance statistics