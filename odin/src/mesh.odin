package main

import "core:slice"

// =============================================================================
// Triangle Index Type
// =============================================================================

TriangleIndex :: struct {
    vertices: [3]u32, // Indices into vertex array
}

// =============================================================================
// Indexed Triangle Set - Core mesh representation
// =============================================================================

IndexedTriangleSet :: struct {
    vertices: [dynamic]Vec3f,        // 3D vertex positions
    indices:  [dynamic]TriangleIndex, // Triangle vertex indices
}

// Create empty triangle set
its_create :: proc() -> IndexedTriangleSet {
    return {
        vertices = make([dynamic]Vec3f),
        indices  = make([dynamic]TriangleIndex),
    }
}

// Destroy triangle set and free memory
its_destroy :: proc(its: ^IndexedTriangleSet) {
    delete(its.vertices)
    delete(its.indices)
}

// Clear triangle set contents
its_clear :: proc(its: ^IndexedTriangleSet) {
    clear(&its.vertices)
    clear(&its.indices)
}

// Add vertex to triangle set, returns index
its_add_vertex :: proc(its: ^IndexedTriangleSet, v: Vec3f) -> u32 {
    append(&its.vertices, v)
    return u32(len(its.vertices) - 1)
}

// Add triangle to triangle set
its_add_triangle :: proc(its: ^IndexedTriangleSet, v0, v1, v2: u32) {
    assert(v0 < u32(len(its.vertices)), "Triangle vertex index out of bounds")
    assert(v1 < u32(len(its.vertices)), "Triangle vertex index out of bounds")
    assert(v2 < u32(len(its.vertices)), "Triangle vertex index out of bounds")
    
    triangle := TriangleIndex{vertices = {v0, v1, v2}}
    append(&its.indices, triangle)
}

// Get triangle vertices
its_get_triangle_vertices :: proc(its: ^IndexedTriangleSet, triangle_idx: u32) -> (Vec3f, Vec3f, Vec3f) {
    assert(triangle_idx < u32(len(its.indices)), "Triangle index out of bounds")
    
    triangle := its.indices[triangle_idx]
    return its.vertices[triangle.vertices[0]], 
           its.vertices[triangle.vertices[1]], 
           its.vertices[triangle.vertices[2]]
}

// Calculate triangle normal
its_triangle_normal :: proc(its: ^IndexedTriangleSet, triangle_idx: u32) -> Vec3f {
    v0, v1, v2 := its_get_triangle_vertices(its, triangle_idx)
    
    // Calculate edge vectors
    edge1 := vec3_sub(v1, v0)
    edge2 := vec3_sub(v2, v0)
    
    // Normal is cross product of edges
    normal := vec3_cross(edge1, edge2)
    return vec3_normalize(normal)
}

// Calculate triangle area
its_triangle_area :: proc(its: ^IndexedTriangleSet, triangle_idx: u32) -> f32 {
    v0, v1, v2 := its_get_triangle_vertices(its, triangle_idx)
    
    edge1 := vec3_sub(v1, v0)
    edge2 := vec3_sub(v2, v0)
    
    cross := vec3_cross(edge1, edge2)
    return vec3_length(cross) * 0.5
}

// Calculate bounding box of triangle set
its_bounding_box :: proc(its: ^IndexedTriangleSet) -> BoundingBox3D {
    if len(its.vertices) == 0 {
        return bbox3d_empty()
    }
    
    bbox := BoundingBox3D{
        min = vec3f_to_point3d(its.vertices[0]),
        max = vec3f_to_point3d(its.vertices[0]),
    }
    
    for vertex in its.vertices[1:] {
        point := vec3f_to_point3d(vertex)
        bbox3d_include(&bbox, point)
    }
    
    return bbox
}

// =============================================================================
// Mesh Statistics and Validation
// =============================================================================

MeshStats :: struct {
    num_vertices:  u32,
    num_triangles: u32,
    num_edges:     u32,
    is_manifold:   bool,
    has_holes:     bool,
    volume:        f32,
    surface_area:  f32,
}

// Calculate basic mesh statistics
its_calculate_stats :: proc(its: ^IndexedTriangleSet) -> MeshStats {
    stats := MeshStats{
        num_vertices  = u32(len(its.vertices)),
        num_triangles = u32(len(its.indices)),
        // Basic stats for now - more complex analysis later
        is_manifold   = false, // TODO: implement manifold check
        has_holes     = false, // TODO: implement hole detection
    }
    
    // Calculate surface area
    total_area: f32 = 0
    for i in 0..<len(its.indices) {
        total_area += its_triangle_area(its, u32(i))
    }
    stats.surface_area = total_area
    
    // TODO: Volume calculation requires more complex algorithm
    stats.volume = 0
    
    return stats
}

// Basic mesh validation
its_validate :: proc(its: ^IndexedTriangleSet) -> bool {
    // Check if all triangle indices are valid
    for triangle in its.indices {
        for vertex_idx in triangle.vertices {
            if vertex_idx >= u32(len(its.vertices)) {
                return false
            }
        }
    }
    
    // Check for degenerate triangles (same vertex used multiple times)
    for triangle in its.indices {
        if triangle.vertices[0] == triangle.vertices[1] ||
           triangle.vertices[1] == triangle.vertices[2] ||
           triangle.vertices[0] == triangle.vertices[2] {
            return false
        }
    }
    
    return true
}

// =============================================================================
// Triangle Mesh - Higher level wrapper
// =============================================================================

TriangleMesh :: struct {
    its:   IndexedTriangleSet,
    stats: MeshStats,
    dirty: bool, // Stats need recalculation
}

// Create empty triangle mesh
mesh_create :: proc() -> TriangleMesh {
    return {
        its   = its_create(),
        stats = {},
        dirty = true,
    }
}

// Destroy triangle mesh
mesh_destroy :: proc(mesh: ^TriangleMesh) {
    its_destroy(&mesh.its)
}

// Get mesh statistics, recalculating if needed
mesh_get_stats :: proc(mesh: ^TriangleMesh) -> MeshStats {
    if mesh.dirty {
        mesh.stats = its_calculate_stats(&mesh.its)
        mesh.dirty = false
    }
    return mesh.stats
}

// Mark mesh as dirty (stats need recalculation)
mesh_mark_dirty :: proc(mesh: ^TriangleMesh) {
    mesh.dirty = true
}

// Add triangle to mesh
mesh_add_triangle :: proc(mesh: ^TriangleMesh, v0, v1, v2: Vec3f) {
    idx0 := its_add_vertex(&mesh.its, v0)
    idx1 := its_add_vertex(&mesh.its, v1) 
    idx2 := its_add_vertex(&mesh.its, v2)
    its_add_triangle(&mesh.its, idx0, idx1, idx2)
    mesh_mark_dirty(mesh)
}