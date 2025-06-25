package main

import "core:math"

// =============================================================================
// 2D Point Types (Fixed-Point for Internal Use)
// =============================================================================

Point2D :: struct {
    x, y: coord_t,
}

// Create point from millimeter coordinates
point2d_from_mm :: proc(x_mm, y_mm: f64) -> Point2D {
    return {mm_to_coord(x_mm), mm_to_coord(y_mm)}
}

// Convert point to millimeter coordinates
point2d_to_mm :: proc(p: Point2D) -> (f64, f64) {
    return coord_to_mm(p.x), coord_to_mm(p.y)
}

// Point arithmetic
point2d_add :: proc(a, b: Point2D) -> Point2D {
    return {a.x + b.x, a.y + b.y}
}

point2d_sub :: proc(a, b: Point2D) -> Point2D {
    return {a.x - b.x, a.y - b.y}
}

point2d_scale :: proc(p: Point2D, factor: f64) -> Point2D {
    return {coord_t(f64(p.x) * factor), coord_t(f64(p.y) * factor)}
}

// Distance between two points
point_distance :: proc(a, b: Point2D) -> coord_t {
    dx := a.x - b.x
    dy := a.y - b.y
    return coord_sqrt(coord_distance_squared(dx, dy))
}

// Distance squared (avoids square root for comparisons)
point_distance_squared :: proc(a, b: Point2D) -> coord_t {
    dx := a.x - b.x
    dy := a.y - b.y
    return coord_distance_squared(dx, dy)
}

// Normalize point vector (return unit vector)
point2d_normalize :: proc(p: Point2D) -> Point2D {
    length_sq := p.x * p.x + p.y * p.y
    if length_sq == 0 do return {1, 0} // Avoid division by zero
    
    length := coord_sqrt(length_sq)
    return {p.x / length, p.y / length}
}

// Negate point vector
point2d_negate :: proc(p: Point2D) -> Point2D {
    return {-p.x, -p.y}
}

// Dot product of two point vectors
point2d_dot :: proc(a, b: Point2D) -> coord_t {
    return a.x * b.x + a.y * b.y
}

point2d_length :: proc(p: Point2D) -> f64 {
    return math.sqrt_f64(f64(p.x * p.x + p.y * p.y))
}

// =============================================================================
// Vector Types (Floating-Point for External Interface)
// =============================================================================

Vec2f :: struct {
    x, y: f32,
}

Vec3f :: struct {
    x, y, z: f32,
}

Vec3d :: struct {
    x, y, z: f64,
}

// 3D vector operations
vec3_add :: proc(a, b: Vec3f) -> Vec3f {
    return {a.x + b.x, a.y + b.y, a.z + b.z}
}

vec3_sub :: proc(a, b: Vec3f) -> Vec3f {
    return {a.x - b.x, a.y - b.y, a.z - b.z}
}

vec3_scale :: proc(v: Vec3f, factor: f32) -> Vec3f {
    return {v.x * factor, v.y * factor, v.z * factor}
}

vec3_dot :: proc(a, b: Vec3f) -> f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z
}

vec3_cross :: proc(a, b: Vec3f) -> Vec3f {
    return {
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
    }
}

vec3_length_squared :: proc(v: Vec3f) -> f32 {
    return v.x * v.x + v.y * v.y + v.z * v.z
}

vec3_length :: proc(v: Vec3f) -> f32 {
    return math.sqrt_f32(vec3_length_squared(v))
}

vec3_normalize :: proc(v: Vec3f) -> Vec3f {
    length := vec3_length(v)
    if length == 0 do return {}
    return vec3_scale(v, 1.0 / length)
}

// 2D vector operations
vec2_add :: proc(a, b: Vec2f) -> Vec2f {
    return {a.x + b.x, a.y + b.y}
}

vec2_sub :: proc(a, b: Vec2f) -> Vec2f {
    return {a.x - b.x, a.y - b.y}
}

vec2_scale :: proc(v: Vec2f, factor: f32) -> Vec2f {
    return {v.x * factor, v.y * factor}
}

vec2_dot :: proc(a, b: Vec2f) -> f32 {
    return a.x * b.x + a.y * b.y
}

vec2_length_squared :: proc(v: Vec2f) -> f32 {
    return v.x * v.x + v.y * v.y
}

vec2_length :: proc(v: Vec2f) -> f32 {
    return math.sqrt_f32(vec2_length_squared(v))
}

vec2_normalize :: proc(v: Vec2f) -> Vec2f {
    length := vec2_length(v)
    if length == 0 do return {}
    return vec2_scale(v, 1.0 / length)
}

// Convert between double and float precision
vec3d_to_f :: proc(v: Vec3d) -> Vec3f {
    return {f32(v.x), f32(v.y), f32(v.z)}
}

vec3f_to_d :: proc(v: Vec3f) -> Vec3d {
    return {f64(v.x), f64(v.y), f64(v.z)}
}

// =============================================================================
// 3D Point Type (Fixed-Point Internal Coordinates)
// =============================================================================

Point3D :: struct {
    x, y, z: coord_t,
}

// Create 3D point from millimeter coordinates
point3d_from_mm :: proc(x_mm, y_mm, z_mm: f64) -> Point3D {
    return {mm_to_coord(x_mm), mm_to_coord(y_mm), mm_to_coord(z_mm)}
}

// Convert 3D point to millimeter coordinates
point3d_to_mm :: proc(p: Point3D) -> (f64, f64, f64) {
    return coord_to_mm(p.x), coord_to_mm(p.y), coord_to_mm(p.z)
}

// Convert between 3D point and float vector
point3d_to_vec3f :: proc(p: Point3D) -> Vec3f {
    x_mm, y_mm, z_mm := point3d_to_mm(p)
    return {f32(x_mm), f32(y_mm), f32(z_mm)}
}

vec3f_to_point3d :: proc(v: Vec3f) -> Point3D {
    return point3d_from_mm(f64(v.x), f64(v.y), f64(v.z))
}

// 3D point arithmetic
point3d_add :: proc(a, b: Point3D) -> Point3D {
    return {a.x + b.x, a.y + b.y, a.z + b.z}
}

point3d_sub :: proc(a, b: Point3D) -> Point3D {
    return {a.x - b.x, a.y - b.y, a.z - b.z}
}

// 3D distance
point3d_distance :: proc(a, b: Point3D) -> coord_t {
    dx := a.x - b.x
    dy := a.y - b.y
    dz := a.z - b.z
    return coord_sqrt(coord_distance_squared_3d(dx, dy, dz))
}

point3d_distance_squared :: proc(a, b: Point3D) -> coord_t {
    dx := a.x - b.x
    dy := a.y - b.y
    dz := a.z - b.z
    return coord_distance_squared_3d(dx, dy, dz)
}

// =============================================================================
// Bounding Box Types
// =============================================================================

BoundingBox2D :: struct {
    min, max: Point2D,
}

BoundingBox3D :: struct {
    min, max: Point3D,
}

// Initialize empty bounding box
bbox2d_empty :: proc() -> BoundingBox2D {
    return {
        min = {max(coord_t), max(coord_t)},
        max = {min(coord_t), min(coord_t)},
    }
}

bbox3d_empty :: proc() -> BoundingBox3D {
    return {
        min = {max(coord_t), max(coord_t), max(coord_t)},
        max = {min(coord_t), min(coord_t), min(coord_t)},
    }
}

// Expand bounding box to include point
bbox2d_include :: proc(bbox: ^BoundingBox2D, p: Point2D) {
    bbox.min.x = coord_min(bbox.min.x, p.x)
    bbox.min.y = coord_min(bbox.min.y, p.y)
    bbox.max.x = coord_max(bbox.max.x, p.x)
    bbox.max.y = coord_max(bbox.max.y, p.y)
}

bbox3d_include :: proc(bbox: ^BoundingBox3D, p: Point3D) {
    bbox.min.x = coord_min(bbox.min.x, p.x)
    bbox.min.y = coord_min(bbox.min.y, p.y)
    bbox.min.z = coord_min(bbox.min.z, p.z)
    bbox.max.x = coord_max(bbox.max.x, p.x)
    bbox.max.y = coord_max(bbox.max.y, p.y)
    bbox.max.z = coord_max(bbox.max.z, p.z)
}