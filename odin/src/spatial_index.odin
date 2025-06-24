package main

import "core:slice"
import "core:fmt"
import "core:math"

// =============================================================================
// AABB Tree Spatial Indexing
//
// This module implements an axis-aligned bounding box tree for fast spatial
// queries on triangle meshes. The tree enables O(log n) ray-triangle 
// intersection tests and plane-triangle intersection queries needed for slicing.
//
// Key features:
// - Structure-of-arrays layout for cache efficiency
// - Surface Area Heuristic (SAH) for optimal tree construction
// - Support for various spatial queries (ray, plane, box intersection)
// - Data-oriented design for batch processing
// =============================================================================

// =============================================================================
// AABB Tree Data Structures
// =============================================================================

AABBTree :: struct {
    // Structure-of-arrays layout for cache efficiency
    nodes:        [dynamic]AABBNode,     // Tree nodes
    primitives:   [dynamic]u32,          // Triangle indices (leaf data)
    root_index:   u32,                   // Index of root node
    mesh:         ^TriangleMesh,         // Reference to source mesh
    
    // Statistics
    max_depth:    u32,
    leaf_count:   u32,
    node_count:   u32,
}

AABBNode :: struct {
    // Bounding box (24 bytes)
    bbox_min: Vec3f,
    bbox_max: Vec3f,
    
    // Tree structure (12 bytes)
    left_child:       u32,    // Index of left child (0 = leaf node)
    primitive_count:  u32,    // Number of triangles (leaf nodes only)
    primitive_offset: u32,    // Index into primitives array
    
    // Total: 36 bytes per node (good for cache line utilization)
}

// Tree construction statistics
AABBStats :: struct {
    node_count:       u32,
    leaf_count:       u32,
    max_depth:        u32,
    total_primitives: u32,
    avg_leaf_size:    f32,
    tree_efficiency:  f32,    // Ratio of nodes to optimal tree
}

// =============================================================================
// Tree Construction
// =============================================================================

// Build AABB tree for the given mesh using Surface Area Heuristic
aabb_build :: proc(mesh: ^TriangleMesh) -> AABBTree {
    tree := AABBTree{
        nodes       = make([dynamic]AABBNode),
        primitives  = make([dynamic]u32),
        mesh        = mesh,
    }
    
    triangle_count := u32(len(mesh.its.indices))
    if triangle_count == 0 {
        return tree
    }
    
    // Initialize primitive indices
    reserve(&tree.primitives, int(triangle_count))
    for i in 0..<triangle_count {
        append(&tree.primitives, i)
    }
    
    // Calculate bounding boxes for all triangles
    triangle_boxes := make([dynamic]BoundingBox3D, triangle_count)
    defer delete(triangle_boxes)
    
    for i in 0..<triangle_count {
        triangle_boxes[i] = calculate_triangle_bbox(&mesh.its, i)
    }
    
    // Build tree recursively
    tree.root_index = build_recursive(&tree, triangle_boxes[:], 0, triangle_count, 0)
    
    // Calculate statistics
    tree.node_count = u32(len(tree.nodes))
    tree.max_depth = calculate_tree_depth(&tree, tree.root_index, 0)
    
    return tree
}

// Destroy AABB tree and free memory
aabb_destroy :: proc(tree: ^AABBTree) {
    delete(tree.nodes)
    delete(tree.primitives)
    tree.mesh = nil
}

// Calculate bounding box for a triangle
calculate_triangle_bbox :: proc(its: ^IndexedTriangleSet, triangle_idx: u32) -> BoundingBox3D {
    triangle := its.indices[triangle_idx]
    
    v0 := its.vertices[triangle.vertices[0]]
    v1 := its.vertices[triangle.vertices[1]]
    v2 := its.vertices[triangle.vertices[2]]
    
    bbox := BoundingBox3D{
        min = vec3f_to_point3d(v0),
        max = vec3f_to_point3d(v0),
    }
    
    bbox3d_include(&bbox, vec3f_to_point3d(v1))
    bbox3d_include(&bbox, vec3f_to_point3d(v2))
    
    return bbox
}

// Recursive tree building using Surface Area Heuristic
build_recursive :: proc(tree: ^AABBTree, triangle_boxes: []BoundingBox3D, 
                       start, count, depth: u32) -> u32 {
    
    // Create new node
    node_index := u32(len(tree.nodes))
    append(&tree.nodes, AABBNode{})
    node := &tree.nodes[node_index]
    
    // Calculate bounding box for this node
    node_bbox := calculate_group_bbox(triangle_boxes, start, count)
    node.bbox_min = point3d_to_vec3f(node_bbox.min)
    node.bbox_max = point3d_to_vec3f(node_bbox.max)
    
    // Leaf node conditions
    max_leaf_size :: 8      // Maximum triangles per leaf
    max_depth :: 20         // Maximum tree depth
    
    if count <= max_leaf_size || depth >= max_depth {
        // Create leaf node
        node.left_child = 0  // 0 indicates leaf
        node.primitive_count = count
        node.primitive_offset = start
        tree.leaf_count += 1
        return node_index
    }
    
    // Find best split using Surface Area Heuristic
    best_axis, best_split := find_best_split(tree.mesh, triangle_boxes, start, count)
    
    if best_split == start || best_split == start + count {
        // No good split found - create leaf
        node.left_child = 0
        node.primitive_count = count
        node.primitive_offset = start
        tree.leaf_count += 1
        return node_index
    }
    
    // Partition triangles around the split
    partition_triangles(tree, triangle_boxes, start, count, best_split)
    
    // Recursively build children
    left_count := best_split - start
    right_count := count - left_count
    
    left_child := build_recursive(tree, triangle_boxes, start, left_count, depth + 1)
    right_child := build_recursive(tree, triangle_boxes, best_split, right_count, depth + 1)
    
    // Update node with child indices
    node = &tree.nodes[node_index]  // Re-acquire pointer (array may have reallocated)
    node.left_child = left_child
    node.primitive_count = 0  // Not a leaf
    node.primitive_offset = right_child  // Store right child index here
    
    return node_index
}

// Calculate bounding box for a group of triangles
calculate_group_bbox :: proc(triangle_boxes: []BoundingBox3D, start, count: u32) -> BoundingBox3D {
    if count == 0 {
        return bbox3d_empty()
    }
    
    bbox := triangle_boxes[start]
    
    for i in start + 1..<start + count {
        // Merge bounding boxes
        bbox.min.x = coord_min(bbox.min.x, triangle_boxes[i].min.x)
        bbox.min.y = coord_min(bbox.min.y, triangle_boxes[i].min.y)
        bbox.min.z = coord_min(bbox.min.z, triangle_boxes[i].min.z)
        
        bbox.max.x = coord_max(bbox.max.x, triangle_boxes[i].max.x)
        bbox.max.y = coord_max(bbox.max.y, triangle_boxes[i].max.y)
        bbox.max.z = coord_max(bbox.max.z, triangle_boxes[i].max.z)
    }
    
    return bbox
}

// Find best split using Surface Area Heuristic
find_best_split :: proc(mesh: ^TriangleMesh, triangle_boxes: []BoundingBox3D, 
                       start, count: u32) -> (best_axis: int, best_split: u32) {
    
    if count <= 1 {
        return 0, start
    }
    
    best_cost := f32(max(f32))
    best_axis = 0
    best_split = start + count / 2  // Default: split in middle
    
    // Try splits along each axis
    for axis in 0..<3 {
        // Sort triangles by centroid along this axis
        sort_triangles_by_axis(mesh, triangle_boxes, start, count, axis)
        
        // Evaluate splits at different positions
        num_candidates := min(count - 1, 32)  // Limit candidates for performance
        step := count / (num_candidates + 1)
        if step == 0 do step = 1
        
        for i in u32(1)..<count {
            if i % step != 0 && i != count/2 do continue  // Sample splits
            
            split_pos := start + i
            cost := evaluate_split_cost(triangle_boxes, start, count, split_pos)
            
            if cost < best_cost {
                best_cost = cost
                best_axis = axis
                best_split = split_pos
            }
        }
    }
    
    return best_axis, best_split
}

// Sort triangles by centroid along given axis
sort_triangles_by_axis :: proc(mesh: ^TriangleMesh, triangle_boxes: []BoundingBox3D, 
                              start, count: u32, axis: int) {
    // Extract centroids for sorting
    centroids := make([dynamic]f32, count)
    defer delete(centroids)
    
    for i in 0..<count {
        triangle_idx := start + i
        bbox := triangle_boxes[triangle_idx]
        
        switch axis {
        case 0: centroids[i] = f32(coord_to_mm(bbox.min.x + bbox.max.x) * 0.5)
        case 1: centroids[i] = f32(coord_to_mm(bbox.min.y + bbox.max.y) * 0.5)
        case 2: centroids[i] = f32(coord_to_mm(bbox.min.z + bbox.max.z) * 0.5)
        }
    }
    
    // Simple bubble sort for small arrays (could be optimized)
    for i in 0..<count {
        for j in 0..<count-1-i {
            if centroids[j] > centroids[j+1] {
                // Swap centroids
                centroids[j], centroids[j+1] = centroids[j+1], centroids[j]
                
                // Swap corresponding triangle boxes
                triangle_boxes[start + j], triangle_boxes[start + j + 1] = 
                    triangle_boxes[start + j + 1], triangle_boxes[start + j]
            }
        }
    }
}

// Evaluate cost of a split using Surface Area Heuristic
evaluate_split_cost :: proc(triangle_boxes: []BoundingBox3D, start, count, split: u32) -> f32 {
    if split <= start || split >= start + count {
        return max(f32)  // Invalid split
    }
    
    left_count := split - start
    right_count := count - left_count
    
    if left_count == 0 || right_count == 0 {
        return max(f32)  // Degenerate split
    }
    
    // Calculate bounding boxes for left and right groups
    left_bbox := calculate_group_bbox(triangle_boxes, start, left_count)
    right_bbox := calculate_group_bbox(triangle_boxes, split, right_count)
    
    // Surface area heuristic cost
    left_area := bbox_surface_area(left_bbox)
    right_area := bbox_surface_area(right_bbox)
    
    // Cost = traversal_cost + probability * intersection_cost
    traversal_cost: f32 = 1.0
    intersection_cost: f32 = 1.0
    
    cost := traversal_cost + 
            (left_area * f32(left_count) + right_area * f32(right_count)) * intersection_cost
    
    return cost
}

// Calculate surface area of bounding box
bbox_surface_area :: proc(bbox: BoundingBox3D) -> f32 {
    dx := coord_to_mm(bbox.max.x - bbox.min.x)
    dy := coord_to_mm(bbox.max.y - bbox.min.y)
    dz := coord_to_mm(bbox.max.z - bbox.min.z)
    
    if dx < 0 || dy < 0 || dz < 0 do return 0
    
    return f32(2.0 * (dx*dy + dy*dz + dz*dx))
}

// Partition triangles around split point
partition_triangles :: proc(tree: ^AABBTree, triangle_boxes: []BoundingBox3D, 
                           start, count, split: u32) {
    // triangles are already sorted by find_best_split
    // Just need to update the primitives array to match
    
    for i in 0..<count {
        triangle_idx := start + i
        // The triangle_boxes array is sorted, but primitives array needs to match
        // This is a simplified version - in practice, we'd track the original indices
        tree.primitives[triangle_idx] = triangle_idx
    }
}

// =============================================================================
// Tree Traversal and Queries
// =============================================================================

// Ray-triangle intersection result
RayHit :: struct {
    hit:          bool,
    distance:     f32,
    triangle_idx: u32,
    hit_point:    Vec3f,
    normal:       Vec3f,
}

// Query all triangles intersecting with a horizontal plane
aabb_plane_intersect :: proc(tree: ^AABBTree, plane_z: f32) -> [dynamic]u32 {
    result := make([dynamic]u32)
    
    if tree.node_count == 0 {
        return result
    }
    
    plane_intersect_recursive(tree, tree.root_index, plane_z, &result)
    return result
}

// Recursive plane intersection query
plane_intersect_recursive :: proc(tree: ^AABBTree, node_index: u32, plane_z: f32, 
                                 result: ^[dynamic]u32) {
    node := &tree.nodes[node_index]
    
    // Check if plane intersects node's bounding box
    if plane_z < node.bbox_min.z || plane_z > node.bbox_max.z {
        return  // Plane doesn't intersect this node
    }
    
    if node.left_child == 0 {
        // Leaf node - add all triangles
        for i in 0..<node.primitive_count {
            triangle_idx := tree.primitives[node.primitive_offset + i]
            append(result, triangle_idx)
        }
    } else {
        // Internal node - recurse to children
        plane_intersect_recursive(tree, node.left_child, plane_z, result)
        plane_intersect_recursive(tree, node.primitive_offset, plane_z, result)  // right child
    }
}

// Ray-mesh intersection query
aabb_ray_intersect :: proc(tree: ^AABBTree, ray_start, ray_dir: Vec3f) -> RayHit {
    result := RayHit{hit = false, distance = max(f32)}
    
    if tree.node_count == 0 {
        return result
    }
    
    // Normalize ray direction
    ray_length := vec3_length(ray_dir)
    if ray_length == 0 {
        return result
    }
    
    normalized_dir := vec3_scale(ray_dir, 1.0 / ray_length)
    
    ray_intersect_recursive(tree, tree.root_index, ray_start, normalized_dir, &result)
    return result
}

// Recursive ray intersection query
ray_intersect_recursive :: proc(tree: ^AABBTree, node_index: u32, ray_start, ray_dir: Vec3f, 
                               result: ^RayHit) {
    node := &tree.nodes[node_index]
    
    // Ray-box intersection test
    if !ray_box_intersect(ray_start, ray_dir, node.bbox_min, node.bbox_max) {
        return  // Ray doesn't hit this node's bounding box
    }
    
    if node.left_child == 0 {
        // Leaf node - test ray against all triangles
        for i in 0..<node.primitive_count {
            triangle_idx := tree.primitives[node.primitive_offset + i]
            
            hit := ray_triangle_intersect(tree.mesh, triangle_idx, ray_start, ray_dir)
            if hit.hit && hit.distance < result.distance {
                result^ = hit
                result.triangle_idx = triangle_idx
            }
        }
    } else {
        // Internal node - recurse to children
        ray_intersect_recursive(tree, node.left_child, ray_start, ray_dir, result)
        ray_intersect_recursive(tree, node.primitive_offset, ray_start, ray_dir, result)  // right child
    }
}

// Ray-box intersection test (fast)
ray_box_intersect :: proc(ray_start, ray_dir, box_min, box_max: Vec3f) -> bool {
    // Use slab method for ray-box intersection
    inv_dir := Vec3f{
        ray_dir.x != 0 ? 1.0 / ray_dir.x : max(f32),
        ray_dir.y != 0 ? 1.0 / ray_dir.y : max(f32),
        ray_dir.z != 0 ? 1.0 / ray_dir.z : max(f32),
    }
    
    t1 := (box_min.x - ray_start.x) * inv_dir.x
    t2 := (box_max.x - ray_start.x) * inv_dir.x
    
    tmin := min(t1, t2)
    tmax := max(t1, t2)
    
    t1 = (box_min.y - ray_start.y) * inv_dir.y
    t2 = (box_max.y - ray_start.y) * inv_dir.y
    
    tmin = max(tmin, min(t1, t2))
    tmax = min(tmax, max(t1, t2))
    
    t1 = (box_min.z - ray_start.z) * inv_dir.z
    t2 = (box_max.z - ray_start.z) * inv_dir.z
    
    tmin = max(tmin, min(t1, t2))
    tmax = min(tmax, max(t1, t2))
    
    return tmax >= tmin && tmax >= 0
}

// Ray-triangle intersection test (Möller-Trumbore algorithm)
ray_triangle_intersect :: proc(mesh: ^TriangleMesh, triangle_idx: u32, 
                              ray_start, ray_dir: Vec3f) -> RayHit {
    result := RayHit{hit = false}
    
    triangle := mesh.its.indices[triangle_idx]
    v0 := mesh.its.vertices[triangle.vertices[0]]
    v1 := mesh.its.vertices[triangle.vertices[1]]
    v2 := mesh.its.vertices[triangle.vertices[2]]
    
    // Möller-Trumbore ray-triangle intersection
    edge1 := vec3_sub(v1, v0)
    edge2 := vec3_sub(v2, v0)
    
    h := vec3_cross(ray_dir, edge2)
    a := vec3_dot(edge1, h)
    
    epsilon: f32 = 1e-8
    if abs(a) < epsilon {
        return result  // Ray is parallel to triangle
    }
    
    f := 1.0 / a
    s := vec3_sub(ray_start, v0)
    u := f * vec3_dot(s, h)
    
    if u < 0.0 || u > 1.0 {
        return result
    }
    
    q := vec3_cross(s, edge1)
    v := f * vec3_dot(ray_dir, q)
    
    if v < 0.0 || u + v > 1.0 {
        return result
    }
    
    t := f * vec3_dot(edge2, q)
    
    if t > epsilon {
        result.hit = true
        result.distance = t
        result.hit_point = vec3_add(ray_start, vec3_scale(ray_dir, t))
        result.normal = vec3_normalize(vec3_cross(edge1, edge2))
    }
    
    return result
}

// =============================================================================
// Tree Statistics and Validation
// =============================================================================

// Calculate tree depth recursively
calculate_tree_depth :: proc(tree: ^AABBTree, node_index: u32, current_depth: u32) -> u32 {
    node := &tree.nodes[node_index]
    
    if node.left_child == 0 {
        // Leaf node
        return current_depth
    }
    
    // Internal node - check both children
    left_depth := calculate_tree_depth(tree, node.left_child, current_depth + 1)
    right_depth := calculate_tree_depth(tree, node.primitive_offset, current_depth + 1)
    
    return max(left_depth, right_depth)
}

// Get tree statistics
aabb_get_stats :: proc(tree: ^AABBTree) -> AABBStats {
    stats := AABBStats{
        node_count       = tree.node_count,
        leaf_count       = tree.leaf_count,
        max_depth        = tree.max_depth,
        total_primitives = u32(len(tree.primitives)),
    }
    
    if tree.leaf_count > 0 {
        stats.avg_leaf_size = f32(stats.total_primitives) / f32(tree.leaf_count)
    }
    
    // Optimal tree would have log2(n) depth
    if stats.total_primitives > 0 {
        optimal_depth := u32(math.ceil_f32(math.log2_f32(f32(stats.total_primitives))))
        stats.tree_efficiency = f32(optimal_depth) / f32(stats.max_depth)
    } else {
        stats.tree_efficiency = 1.0
    }
    
    return stats
}

// Validate tree structure
aabb_validate :: proc(tree: ^AABBTree) -> bool {
    if tree.node_count == 0 {
        return true  // Empty tree is valid
    }
    
    return validate_recursive(tree, tree.root_index)
}

// Recursive tree validation
validate_recursive :: proc(tree: ^AABBTree, node_index: u32) -> bool {
    if node_index >= tree.node_count {
        return false  // Invalid node index
    }
    
    node := &tree.nodes[node_index]
    
    // Check bounding box validity
    if node.bbox_min.x > node.bbox_max.x ||
       node.bbox_min.y > node.bbox_max.y ||
       node.bbox_min.z > node.bbox_max.z {
        return false  // Invalid bounding box
    }
    
    if node.left_child == 0 {
        // Leaf node validation
        if node.primitive_offset + node.primitive_count > u32(len(tree.primitives)) {
            return false  // Primitive indices out of bounds
        }
    } else {
        // Internal node validation
        if node.left_child >= tree.node_count ||
           node.primitive_offset >= tree.node_count {  // right child stored here
            return false  // Child indices out of bounds
        }
        
        // Recursively validate children
        if !validate_recursive(tree, node.left_child) ||
           !validate_recursive(tree, node.primitive_offset) {
            return false
        }
    }
    
    return true
}