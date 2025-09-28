package core

import rl "vendor:raylib"

// Fundamental types used across packages
Transform :: struct {
    position: rl.Vector3,
    rotation: rl.Vector3,        // Euler angles in degrees
    scale: rl.Vector3,
}

Object_Type :: enum {
    CUBE,
    SPHERE,
    CYLINDER,
    MESH,  // Imported mesh type
}

// Mesh reference data for imported models
Mesh_Data :: struct {
    model: rl.Model,           // Raylib model handle
    source_file: string,       // Original glTF filename
    mesh_count: int,           // Number of meshes in model
    material_count: int,       // Number of materials
    bounds: rl.BoundingBox,    // Pre-calculated bounds
}