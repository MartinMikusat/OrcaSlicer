package main

import "core:fmt"
import "core:time"
import "core:mem"
import "core:math"

// Simple test structures for arena allocator testing
TestPoint :: struct {
    x, y: f64,
}

TestSegment :: struct {
    start, end: TestPoint,
    id: u32,
}

// Test arena allocator performance vs standard allocation
test_arena_simple :: proc() {
    fmt.println("=== Arena Allocator Performance Test ===")
    
    // Test parameters
    num_layers := 100
    segments_per_layer := 1000
    iterations := 10
    
    fmt.printf("Testing with %d layers, %d segments per layer, %d iterations\n",
               num_layers, segments_per_layer, iterations)
    
    // Standard allocation timing
    fmt.println("\n--- Standard Allocation ---")
    standard_total: f64 = 0
    
    for iter in 0..<iterations {
        start := time.now()
        
        for layer in 0..<num_layers {
            // Allocate segments
            segments := make([dynamic]TestSegment, 0, segments_per_layer)
            
            // Add segments
            for i in 0..<segments_per_layer {
                append(&segments, TestSegment{
                    start = TestPoint{f64(i), f64(layer)},
                    end = TestPoint{f64(i+1), f64(layer)},
                    id = u32(i),
                })
            }
            
            // Process segments (simulate work)
            total_length: f64 = 0
            for seg in segments {
                dx := seg.end.x - seg.start.x
                dy := seg.end.y - seg.start.y
                total_length += math.sqrt(dx*dx + dy*dy)
            }
            
            // Clean up
            delete(segments)
        }
        
        elapsed := time.duration_milliseconds(time.since(start))
        standard_total += elapsed
    }
    
    standard_avg := standard_total / f64(iterations)
    fmt.printf("Average time: %.2fms\n", standard_avg)
    
    // Arena allocation timing
    fmt.println("\n--- Arena Allocation ---")
    arena_total: f64 = 0
    
    // Create arena once
    arena := arena_create(32 * 1024 * 1024) // 32MB
    defer arena_destroy(&arena)
    
    for iter in 0..<iterations {
        start := time.now()
        
        for layer in 0..<num_layers {
            // Reset arena for this layer
            arena_reset(&arena)
            
            // Allocate segments from arena
            segments := arena_array(&arena, TestSegment, segments_per_layer)
            segment_count := 0
            
            // Add segments
            for i in 0..<segments_per_layer {
                segments[segment_count] = TestSegment{
                    start = TestPoint{f64(i), f64(layer)},
                    end = TestPoint{f64(i+1), f64(layer)},
                    id = u32(i),
                }
                segment_count += 1
            }
            
            // Process segments (simulate work)
            total_length: f64 = 0
            for i in 0..<segment_count {
                seg := segments[i]
                dx := seg.end.x - seg.start.x
                dy := seg.end.y - seg.start.y
                total_length += math.sqrt(dx*dx + dy*dy)
            }
            
            // No cleanup needed - arena will be reset
        }
        
        elapsed := time.duration_milliseconds(time.since(start))
        arena_total += elapsed
    }
    
    arena_avg := arena_total / f64(iterations)
    fmt.printf("Average time: %.2fms\n", arena_avg)
    
    // Compare results
    fmt.printf("\n--- Performance Comparison ---\n")
    fmt.printf("Standard allocation: %.2fms\n", standard_avg)
    fmt.printf("Arena allocation: %.2fms\n", arena_avg)
    fmt.printf("Speedup: %.2fx\n", standard_avg / arena_avg)
    fmt.printf("Time saved: %.2fms (%.1f%%)\n", 
               standard_avg - arena_avg,
               (standard_avg - arena_avg) / standard_avg * 100)
    
    fmt.println("\n✓ Arena allocator performance test completed")
}

// Test SOA vs AOS performance
test_soa_simple :: proc() {
    fmt.println("\n=== Structure of Arrays (SoA) Performance Test ===")
    
    num_segments := 100000
    iterations := 100
    
    // Array of Structures timing
    fmt.println("\n--- Array of Structures (AoS) ---")
    aos_total: f64 = 0
    
    for iter in 0..<iterations {
        start := time.now()
        
        // Allocate AoS
        segments := make([dynamic]TestSegment, num_segments)
        defer delete(segments)
        
        // Initialize
        for i in 0..<num_segments {
            angle := f64(i) * 0.01
            segments[i] = TestSegment{
                start = TestPoint{math.cos(angle) * 10, math.sin(angle) * 10},
                end = TestPoint{math.cos(angle) * 20, math.sin(angle) * 20},
                id = u32(i),
            }
        }
        
        // Process - calculate total length
        total_length: f64 = 0
        for i in 0..<num_segments {
            dx := segments[i].end.x - segments[i].start.x
            dy := segments[i].end.y - segments[i].start.y
            total_length += math.sqrt(dx*dx + dy*dy)
        }
        
        elapsed := time.duration_milliseconds(time.since(start))
        aos_total += elapsed
    }
    
    aos_avg := aos_total / f64(iterations)
    fmt.printf("Average time: %.2fms\n", aos_avg)
    
    // Structure of Arrays timing
    fmt.println("\n--- Structure of Arrays (SoA) ---")
    soa_total: f64 = 0
    
    for iter in 0..<iterations {
        start := time.now()
        
        // Allocate SoA
        start_x := make([dynamic]f64, num_segments)
        start_y := make([dynamic]f64, num_segments)
        end_x := make([dynamic]f64, num_segments)
        end_y := make([dynamic]f64, num_segments)
        defer delete(start_x)
        defer delete(start_y)
        defer delete(end_x)
        defer delete(end_y)
        
        // Initialize
        for i in 0..<num_segments {
            angle := f64(i) * 0.01
            start_x[i] = math.cos(angle) * 10
            start_y[i] = math.sin(angle) * 10
            end_x[i] = math.cos(angle) * 20
            end_y[i] = math.sin(angle) * 20
        }
        
        // Process - calculate total length (vectorizable)
        total_length: f64 = 0
        for i in 0..<num_segments {
            dx := end_x[i] - start_x[i]
            dy := end_y[i] - start_y[i]
            total_length += math.sqrt(dx*dx + dy*dy)
        }
        
        elapsed := time.duration_milliseconds(time.since(start))
        soa_total += elapsed
    }
    
    soa_avg := soa_total / f64(iterations)
    fmt.printf("Average time: %.2fms\n", soa_avg)
    
    // Compare results
    fmt.printf("\n--- Performance Comparison ---\n")
    fmt.printf("Array of Structures: %.2fms\n", aos_avg)
    fmt.printf("Structure of Arrays: %.2fms\n", soa_avg)
    fmt.printf("Speedup: %.2fx\n", aos_avg / soa_avg)
    fmt.printf("Time saved: %.2fms (%.1f%%)\n", 
               aos_avg - soa_avg,
               (aos_avg - soa_avg) / aos_avg * 100)
    
    fmt.println("\n✓ SoA performance test completed")
}

// Test memory allocation patterns
test_memory_patterns_simple :: proc() {
    fmt.println("\n=== Memory Allocation Pattern Test ===")
    
    // Test different allocation patterns
    patterns := []struct{name: string, size: int}{
        {"Small frequent (1KB)", 1024},
        {"Medium (64KB)", 64 * 1024},
        {"Large (1MB)", 1024 * 1024},
    }
    
    iterations := 100  // Reduced for faster testing
    allocations_per_iter := 50
    
    for pattern in patterns {
        fmt.printf("\n--- %s allocations ---\n", pattern.name)
        
        // Standard allocator
        std_start := time.now()
        for i in 0..<iterations {
            ptrs := make([dynamic][]byte, allocations_per_iter)
            
            for j in 0..<allocations_per_iter {
                ptrs[j] = make([]byte, pattern.size)
            }
            
            for ptr in ptrs {
                delete(ptr)
            }
            delete(ptrs)
        }
        std_time := time.duration_milliseconds(time.since(std_start))
        
        // Arena allocator
        arena := arena_create(pattern.size * allocations_per_iter * 2)
        defer arena_destroy(&arena)
        
        arena_start := time.now()
        for i in 0..<iterations {
            arena_reset(&arena)
            
            for j in 0..<allocations_per_iter {
                _ = arena_array(&arena, byte, pattern.size)
            }
            // No cleanup needed
        }
        arena_time := time.duration_milliseconds(time.since(arena_start))
        
        fmt.printf("Standard: %.2fms, Arena: %.2fms, Speedup: %.2fx\n",
                   std_time, arena_time, std_time / arena_time)
    }
    
    fmt.println("\n✓ Memory pattern test completed")
}