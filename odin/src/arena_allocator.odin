package main

import "core:mem"
import "base:runtime"
import "core:sync"

// Arena allocator for high-performance temporary allocations
Arena :: struct {
    memory: []byte,
    offset: int,
    temp_count: int,
}

// Create a new arena with specified size
arena_create :: proc(size: int) -> Arena {
    return Arena{
        memory = make([]byte, size),
        offset = 0,
        temp_count = 0,
    }
}

// Destroy arena and free all memory
arena_destroy :: proc(arena: ^Arena) {
    delete(arena.memory)
    arena^ = {}
}

// Reset arena for reuse (keeps memory allocated)
arena_reset :: proc(arena: ^Arena) {
    arena.offset = 0
    arena.temp_count = 0
}

// Allocate memory from arena with alignment
arena_alloc :: proc(arena: ^Arena, size: int, alignment: int = 8) -> rawptr {
    // Align offset
    aligned_offset := (arena.offset + alignment - 1) & ~(alignment - 1)
    
    if aligned_offset + size > len(arena.memory) {
        panic("Arena out of memory")
    }
    
    ptr := &arena.memory[aligned_offset]
    arena.offset = aligned_offset + size
    return rawptr(ptr)
}

// Allocate typed value from arena
arena_new :: proc(arena: ^Arena, $T: typeid) -> ^T {
    ptr := arena_alloc(arena, size_of(T), align_of(T))
    return cast(^T)ptr
}

// Allocate typed array from arena
arena_array :: proc(arena: ^Arena, $T: typeid, count: int) -> []T {
    if count == 0 do return nil
    
    size := size_of(T) * count
    ptr := arena_alloc(arena, size, align_of(T))
    return mem.slice_ptr(cast(^T)ptr, count)
}

// Create temporary allocator context from arena
arena_temp_allocator :: proc(arena: ^Arena) -> mem.Allocator {
    return mem.Allocator{
        procedure = arena_allocator_proc,
        data = arena,
    }
}

// Allocator procedure for arena
arena_allocator_proc :: proc(
    allocator_data: rawptr,
    mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr,
    old_size: int,
    location := #caller_location,
) -> ([]byte, mem.Allocator_Error) {
    arena := cast(^Arena)allocator_data
    
    switch mode {
    case .Alloc, .Alloc_Non_Zeroed:
        ptr := arena_alloc(arena, size, alignment)
        if ptr == nil {
            return nil, .Out_Of_Memory
        }
        
        bytes := mem.slice_ptr(cast(^byte)ptr, size)
        if mode == .Alloc {
            mem.zero_slice(bytes)
        }
        return bytes, nil
        
    case .Free:
        // No-op for arena allocator
        return nil, nil
        
    case .Free_All:
        arena_reset(arena)
        return nil, nil
        
    case .Resize, .Resize_Non_Zeroed:
        // Arena doesn't support resize
        return nil, .Mode_Not_Implemented
        
    case .Query_Features:
        set := cast(^mem.Allocator_Mode_Set)old_memory
        set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All}
        return nil, nil
        
    case .Query_Info:
        info := cast(^mem.Allocator_Query_Info)old_memory
        info.pointer = raw_data(arena.memory)
        info.size = len(arena.memory)
        // Note: used field not available in this Odin version
        return nil, nil
    }
    
    return nil, nil
}

// Thread-local arena for per-layer operations
@(thread_local)
layer_arena: Arena

// Initialize thread-local layer arena
init_layer_arena :: proc(size: int = 16 * 1024 * 1024) { // 16MB default
    layer_arena = arena_create(size)
}

// Clean up thread-local layer arena
cleanup_layer_arena :: proc() {
    arena_destroy(&layer_arena)
}

// Scoped arena usage - automatically resets on scope exit
Scoped_Arena :: struct {
    arena: ^Arena,
    initial_offset: int,
}

scoped_arena :: proc(arena: ^Arena) -> Scoped_Arena {
    return Scoped_Arena{
        arena = arena,
        initial_offset = arena.offset,
    }
}

scoped_arena_end :: proc(scoped: Scoped_Arena) {
    scoped.arena.offset = scoped.initial_offset
}