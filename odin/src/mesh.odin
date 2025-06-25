package main

import "core:slice"

// =============================================================================
// Triangle Index Type
// =============================================================================

TriangleIndex :: struct {
    vertices: [3]u32, // Indices into vertex array
    edges:    [3]u32, // Edge IDs for topology tracking (computed on demand)
}

// =============================================================================
// Edge Connectivity for Advanced Segment Chaining
// =============================================================================

Edge :: struct {
    vertex_a:    u32,  // First vertex index
    vertex_b:    u32,  // Second vertex index
    triangle_a:  u32,  // First triangle using this edge
    triangle_b:  u32,  // Second triangle using this edge (INVALID_INDEX if boundary)
}

EdgeMap :: struct {
    edges:            [dynamic]Edge,        // All edges in the mesh
    vertex_to_edges:  map[u64][dynamic]u32, // Hash(vertex_pair) -> edge_ids
}

INVALID_INDEX :: u32(0xFFFFFFFF)

// Create empty edge map
edge_map_create :: proc() -> EdgeMap {
    return {
        edges = make([dynamic]Edge),
        vertex_to_edges = make(map[u64][dynamic]u32),
    }
}

// Destroy edge map and free memory
edge_map_destroy :: proc(edge_map: ^EdgeMap) {
    delete(edge_map.edges)
    for key, edge_list in edge_map.vertex_to_edges {
        delete(edge_list)
    }
    delete(edge_map.vertex_to_edges)
}

// Clear edge map contents
edge_map_clear :: proc(edge_map: ^EdgeMap) {
    clear(&edge_map.edges)
    for key, edge_list in edge_map.vertex_to_edges {
        delete(edge_list)
    }
    clear(&edge_map.vertex_to_edges)
}

// Hash function for vertex pair
vertex_pair_hash :: proc(a, b: u32) -> u64 {
    // Ensure consistent ordering
    min_v, max_v := min(a, b), max(a, b)
    return (u64(min_v) << 32) | u64(max_v)
}

// Build edge connectivity map from triangle mesh
build_edge_topology :: proc(mesh: ^TriangleMesh) {
    edge_map_clear(&mesh.edge_map)
    
    // First pass: create edges and build hash map
    for triangle, tri_idx in mesh.its.indices {
        vertices := triangle.vertices
        
        // Process each edge of the triangle
        for i in 0..<3 {
            v1 := vertices[i]
            v2 := vertices[(i + 1) % 3]
            
            hash := vertex_pair_hash(v1, v2)
            
            // Check if edge already exists
            edge_found := false
            if edge_ids, exists := mesh.edge_map.vertex_to_edges[hash]; exists {
                for edge_id in edge_ids {
                    edge := &mesh.edge_map.edges[edge_id]
                    if edge.triangle_b == INVALID_INDEX {
                        // This is a boundary edge, add second triangle
                        edge.triangle_b = u32(tri_idx)
                        edge_found = true
                        break
                    }
                }
            }
            
            if !edge_found {
                // Create new edge
                edge := Edge{
                    vertex_a = min(v1, v2),
                    vertex_b = max(v1, v2), 
                    triangle_a = u32(tri_idx),
                    triangle_b = INVALID_INDEX,
                }
                
                edge_id := u32(len(mesh.edge_map.edges))
                append(&mesh.edge_map.edges, edge)
                
                // Add to hash map
                if hash not_in mesh.edge_map.vertex_to_edges {
                    mesh.edge_map.vertex_to_edges[hash] = make([dynamic]u32)
                }
                append(&mesh.edge_map.vertex_to_edges[hash], edge_id)
                
                // Store edge ID in triangle
                mesh.its.indices[tri_idx].edges[i] = edge_id
            }
        }
    }
    
    mesh.topology_dirty = false
}

// Get edge ID for triangle edge
get_triangle_edge_id :: proc(mesh: ^TriangleMesh, triangle_idx: u32, edge_idx: u32) -> u32 {
    if mesh.topology_dirty {
        build_edge_topology(mesh)
    }
    
    assert(triangle_idx < u32(len(mesh.its.indices)), "Triangle index out of bounds")
    assert(edge_idx < 3, "Edge index must be 0, 1, or 2")
    
    return mesh.its.indices[triangle_idx].edges[edge_idx]
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
    its:       IndexedTriangleSet,
    stats:     MeshStats,
    dirty:     bool, // Stats need recalculation
    edge_map:  EdgeMap, // Topology information for advanced chaining
    topology_dirty: bool, // Topology needs rebuilding
}

// Create empty triangle mesh
mesh_create :: proc() -> TriangleMesh {
    return {
        its     = its_create(),
        stats   = {},
        dirty   = true,
        edge_map = edge_map_create(),
        topology_dirty = true,
    }
}

// Destroy triangle mesh
mesh_destroy :: proc(mesh: ^TriangleMesh) {
    its_destroy(&mesh.its)
    edge_map_destroy(&mesh.edge_map)
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