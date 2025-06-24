package main

import "core:bytes"
import "core:encoding/endian"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:strconv"

// =============================================================================
// STL File Format Constants
// =============================================================================

STL_HEADER_SIZE :: 80
STL_TRIANGLE_SIZE :: 50  // 12 floats (48 bytes) + 2 bytes attribute

// STL triangle structure for binary format
STLTriangle :: struct {
    normal: [3]f32,
    vertices: [3][3]f32, // 3 vertices, each with x,y,z
    attribute: u16,
}

// =============================================================================
// STL File Type Detection
// =============================================================================

STLFileType :: enum {
    UNKNOWN,
    ASCII,
    BINARY,
}

// Detect STL file type by examining header
stl_detect_file_type :: proc(filepath: string) -> STLFileType {
    file, err := os.open(filepath)
    if err != os.ERROR_NONE {
        return .UNKNOWN
    }
    defer os.close(file)
    
    // Read first few bytes to check format
    header_buffer: [6]u8
    bytes_read, read_err := os.read(file, header_buffer[:])
    if read_err != os.ERROR_NONE || bytes_read < 6 {
        return .UNKNOWN
    }
    
    header_text := string(header_buffer[:])
    
    // ASCII STL files start with "solid "
    if strings.has_prefix(header_text, "solid ") {
        // Need to check if it's actually ASCII or binary with "solid " in header
        // Reset to beginning and try to parse as ASCII
        os.seek(file, 0, 0)
        
        // Read entire first line
        first_line_buffer: [256]u8
        line_bytes, _ := os.read(file, first_line_buffer[:])
        first_line := strings.trim_space(string(first_line_buffer[:line_bytes]))
        
        // If the line after "solid" looks like ASCII STL, it's ASCII
        if strings.contains(first_line, "solid") {
            // Simple check - ASCII should not have many null bytes
            null_count := 0
            for b in first_line_buffer[:line_bytes] {
                if b == 0 do null_count += 1
            }
            if null_count < line_bytes / 4 { // Less than 25% null bytes
                return .ASCII
            }
        }
    }
    
    // If not ASCII, assume binary
    return .BINARY
}

// =============================================================================
// Binary STL Loading
// =============================================================================

stl_load_binary :: proc(filepath: string) -> (TriangleMesh, bool) {
    file, err := os.open(filepath)
    if err != os.ERROR_NONE {
        fmt.printf("Error opening STL file: %s\n", filepath)
        return {}, false
    }
    defer os.close(file)
    
    // Skip 80-byte header
    os.seek(file, STL_HEADER_SIZE, 0)
    
    // Read triangle count
    triangle_count_bytes: [4]u8
    bytes_read, read_err := os.read(file, triangle_count_bytes[:])
    if read_err != os.ERROR_NONE || bytes_read != 4 {
        fmt.println("Error reading triangle count from STL file")
        return {}, false
    }
    
    triangle_count, _ := endian.get_u32(triangle_count_bytes[:], .Little)
    fmt.printf("Loading binary STL with %d triangles\n", triangle_count)
    
    mesh := mesh_create()
    
    // Read each triangle
    for i in 0..<triangle_count {
        triangle_data: [STL_TRIANGLE_SIZE]u8
        bytes_read, read_err = os.read(file, triangle_data[:])
        if read_err != os.ERROR_NONE || bytes_read != STL_TRIANGLE_SIZE {
            fmt.printf("Error reading triangle %d from STL file\n", i)
            mesh_destroy(&mesh)
            return {}, false
        }
        
        // Parse triangle data (little endian)
        triangle := parse_binary_triangle(triangle_data[:])
        
        // Add triangle to mesh
        v0 := Vec3f{triangle.vertices[0][0], triangle.vertices[0][1], triangle.vertices[0][2]}
        v1 := Vec3f{triangle.vertices[1][0], triangle.vertices[1][1], triangle.vertices[1][2]}
        v2 := Vec3f{triangle.vertices[2][0], triangle.vertices[2][1], triangle.vertices[2][2]}
        
        mesh_add_triangle(&mesh, v0, v1, v2)
    }
    
    fmt.printf("Successfully loaded %d triangles from binary STL\n", triangle_count)
    return mesh, true
}

// Parse binary triangle data
parse_binary_triangle :: proc(data: []u8) -> STLTriangle {
    triangle: STLTriangle
    
    offset := 0
    
    // Normal vector (3 floats)
    for i in 0..<3 {
        triangle.normal[i], _ = endian.get_f32(data[offset:offset+4], .Little)
        offset += 4
    }
    
    // Vertices (3 vertices * 3 coordinates each)
    for vertex in 0..<3 {
        for coord in 0..<3 {
            triangle.vertices[vertex][coord], _ = endian.get_f32(data[offset:offset+4], .Little)
            offset += 4
        }
    }
    
    // Attribute bytes
    triangle.attribute, _ = endian.get_u16(data[offset:offset+2], .Little)
    
    return triangle
}

// =============================================================================
// ASCII STL Loading
// =============================================================================

stl_load_ascii :: proc(filepath: string) -> (TriangleMesh, bool) {
    file_data, read_ok := os.read_entire_file(filepath)
    if !read_ok {
        fmt.printf("Error reading ASCII STL file: %s\n", filepath)
        return {}, false
    }
    defer delete(file_data)
    
    content := string(file_data)
    lines := strings.split_lines(content)
    defer delete(lines)
    
    mesh := mesh_create()
    triangle_count := 0
    
    i := 0
    for i < len(lines) {
        line := strings.trim_space(lines[i])
        
        // Look for "facet normal" to start a triangle
        if strings.has_prefix(line, "facet normal") {
            triangle, ok := parse_ascii_triangle(lines[i:])
            if !ok {
                fmt.printf("Error parsing triangle at line %d\n", i + 1)
                mesh_destroy(&mesh)
                return {}, false
            }
            
            mesh_add_triangle(&mesh, triangle[0], triangle[1], triangle[2])
            triangle_count += 1
            
            // Skip to end of this triangle (should be "endfacet")
            for j in i..<len(lines) {
                if strings.has_prefix(strings.trim_space(lines[j]), "endfacet") {
                    i = j + 1
                    break
                }
            }
        } else {
            i += 1
        }
    }
    
    fmt.printf("Successfully loaded %d triangles from ASCII STL\n", triangle_count)
    return mesh, true
}

// Parse ASCII triangle from lines starting at facet normal
parse_ascii_triangle :: proc(lines: []string) -> ([3]Vec3f, bool) {
    vertices: [3]Vec3f
    vertex_count := 0
    
    for i in 0..<len(lines) {
        line := lines[i]
        trimmed := strings.trim_space(line)
        
        if strings.has_prefix(trimmed, "vertex ") {
            if vertex_count >= 3 {
                return vertices, false // Too many vertices
            }
            
            // Parse vertex coordinates
            parts := strings.split(trimmed, " ")
            defer delete(parts)
            
            if len(parts) != 4 { // "vertex" + 3 coordinates
                return vertices, false
            }
            
            x, x_ok := strconv.parse_f32(parts[1])
            y, y_ok := strconv.parse_f32(parts[2]) 
            z, z_ok := strconv.parse_f32(parts[3])
            
            if !x_ok || !y_ok || !z_ok {
                return vertices, false
            }
            
            vertices[vertex_count] = Vec3f{x, y, z}
            vertex_count += 1
        } else if strings.has_prefix(trimmed, "endfacet") {
            break
        }
    }
    
    return vertices, vertex_count == 3
}

// =============================================================================
// Main STL Loading Function
// =============================================================================

stl_load :: proc(filepath: string) -> (TriangleMesh, bool) {
    file_type := stl_detect_file_type(filepath)
    
    switch file_type {
    case .ASCII:
        return stl_load_ascii(filepath)
    case .BINARY:
        return stl_load_binary(filepath)
    case .UNKNOWN:
        fmt.printf("Unknown STL file format: %s\n", filepath)
        return {}, false
    }
    
    // Should never reach here
    return {}, false
}

// =============================================================================
// STL Saving (Binary Format)
// =============================================================================

stl_save_binary :: proc(mesh: ^TriangleMesh, filepath: string) -> bool {
    file, err := os.open(filepath, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
    if err != os.ERROR_NONE {
        fmt.printf("Error creating STL file: %s\n", filepath)
        return false
    }
    defer os.close(file)
    
    // Write 80-byte header (filled with zeros)
    header := make([]u8, STL_HEADER_SIZE)
    defer delete(header)
    
    os.write(file, header)
    
    // Write triangle count
    triangle_count := u32(len(mesh.its.indices))
    triangle_count_bytes: [4]u8
    endian.put_u32(triangle_count_bytes[:], .Little, triangle_count)
    os.write(file, triangle_count_bytes[:])
    
    // Write each triangle
    for i in 0..<len(mesh.its.indices) {
        triangle_data := create_binary_triangle(&mesh.its, u32(i))
        os.write(file, triangle_data[:])
    }
    
    fmt.printf("Successfully saved %d triangles to binary STL: %s\n", triangle_count, filepath)
    return true
}

// Create binary triangle data
create_binary_triangle :: proc(its: ^IndexedTriangleSet, triangle_idx: u32) -> [STL_TRIANGLE_SIZE]u8 {
    data: [STL_TRIANGLE_SIZE]u8
    offset := 0
    
    // Calculate normal
    normal := its_triangle_normal(its, triangle_idx)
    
    // Write normal (3 floats)
    endian.put_f32(data[offset:offset+4], .Little, normal.x); offset += 4
    endian.put_f32(data[offset:offset+4], .Little, normal.y); offset += 4
    endian.put_f32(data[offset:offset+4], .Little, normal.z); offset += 4
    
    // Write vertices
    triangle := its.indices[triangle_idx]
    for vertex_idx in triangle.vertices {
        vertex := its.vertices[vertex_idx]
        endian.put_f32(data[offset:offset+4], .Little, vertex.x); offset += 4
        endian.put_f32(data[offset:offset+4], .Little, vertex.y); offset += 4
        endian.put_f32(data[offset:offset+4], .Little, vertex.z); offset += 4
    }
    
    // Attribute bytes (usually 0)
    endian.put_u16(data[offset:offset+2], .Little, 0)
    
    return data
}