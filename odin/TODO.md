# OrcaSlicer Odin TODO List

This document tracks specific, actionable tasks for the OrcaSlicer Odin rewrite. For comprehensive documentation, see `DEVELOPMENT_GUIDE.md`.

## 🚨 Critical Bugs (Fix First!)

### 1. AABB Tree O(n³) Construction Bug
**Severity:** CRITICAL - Makes large meshes unusable  
**Time Estimate:** 1-2 days  
**Status:** 🔴 TODO

```odin
// Current disaster (spatial_index.odin:265-277)
// Bubble sort causing O(n³) complexity!
for i in 0..<count {
    for j in 0..<count-1-i {
        // Replace this entire section
    }
}
```

**Fix:**
- [ ] Replace bubble sort with `slice.sort_by`
- [ ] Test with 5K, 10K, 50K triangle meshes
- [ ] Verify <100ms for 10K triangles
- [ ] Update benchmarks to confirm fix

## 📅 Phase 2A: Production Polygon Processing

### Week 1-2: Gap Closing Algorithm (START HERE)
**Status:** 🔴 TODO  
**File:** Create `odin/src/gap_closing.odin`

- [ ] Basic gap detection algorithm
  - [ ] Find open polygon endpoints
  - [ ] Build spatial index of endpoints
  - [ ] Find candidates within max_gap distance
- [ ] Gap quality metrics
  - [ ] Distance cost (normalized)
  - [ ] Angle deviation cost
  - [ ] Combined scoring function
- [ ] Gap closing implementation
  - [ ] Connect best candidate pairs
  - [ ] Handle polygon reversal cases
  - [ ] Merge connected polygons
- [ ] Configuration system
  - [ ] max_gap_distance (default 2mm)
  - [ ] max_angle_deviation (default 45°)
  - [ ] enable_debug output
- [ ] Integration with layer_slicer.odin
  - [ ] Call after segments_to_polygons
  - [ ] Track statistics (gaps closed)
  - [ ] Test with broken polygons

### Week 3-5: Degenerate Case Handling
**Status:** 🔴 TODO  
**File:** Update `odin/src/geometry_predicates.odin`

- [ ] Comprehensive triangle-plane classification
  - [ ] Detect horizontal faces (all vertices on plane)
  - [ ] Handle vertex-on-plane cases (bitmask approach)
  - [ ] Process edge-on-plane scenarios
  - [ ] Classify face orientation (top/bottom/general)
- [ ] Enhanced intersection result structure
  - [ ] Add face_type enum
  - [ ] Include vertex_mask for on-plane vertices
  - [ ] Support multiple output segments
- [ ] Special case handlers
  - [ ] handle_horizontal_face()
  - [ ] handle_vertex_on_plane()
  - [ ] handle_edge_on_plane()
- [ ] Integration and testing
  - [ ] Update layer_slicer to use new predicates
  - [ ] Test with degenerate STL models
  - [ ] Verify no missing geometry

### Week 6-9: Advanced Segment Chaining
**Status:** 🔴 TODO  
**File:** Update `odin/src/layer_slicer.odin`

- [ ] Mesh topology tracking
  - [ ] Build edge-to-triangle connectivity map
  - [ ] Track edge IDs through slicing process
  - [ ] Store topology info in LineSegment struct
- [ ] Multi-pass chaining algorithm
  - [ ] Pass 1: Topology-based connection
  - [ ] Pass 2: Exact endpoint matching (1μm)
  - [ ] Pass 3: Gap closing (up to 2mm)
- [ ] Error recovery mechanisms
  - [ ] Handle disconnected segments
  - [ ] Merge duplicate segments
  - [ ] Validate polygon closure
- [ ] Performance optimization
  - [ ] Use hash maps for edge lookup
  - [ ] Minimize segment copying
  - [ ] Profile and optimize hot paths

### Week 10-13: Boolean Operations
**Status:** 🔴 TODO  
**File:** Create `odin/src/boolean_ops.odin`

- [ ] Basic polygon clipping
  - [ ] Sutherland-Hodgman algorithm (simple cases)
  - [ ] Handle convex polygon clipping
  - [ ] Test with overlapping rectangles
- [ ] Vatti clipping algorithm
  - [ ] Scanline event processing
  - [ ] Active edge table management
  - [ ] Handle self-intersecting polygons
- [ ] Boolean operation types
  - [ ] Union (A ∪ B)
  - [ ] Intersection (A ∩ B)
  - [ ] Difference (A - B)
  - [ ] XOR (A ⊕ B)
- [ ] ExPolygon support
  - [ ] Hole detection algorithm
  - [ ] Proper winding number calculation
  - [ ] Contour orientation (CCW outer, CW holes)
- [ ] Morphological operations
  - [ ] Offset (inflate/deflate)
  - [ ] Closing (offset out then in)
  - [ ] Opening (offset in then out)

## 📅 Phase 2B: Performance & Polish

### Week 14-15: Multi-Threading
**Status:** 🔴 TODO  
**File:** Update multiple files

- [ ] Thread pool implementation
  - [ ] Worker thread management
  - [ ] Job queue with stealing
  - [ ] Synchronization primitives
- [ ] Parallel layer processing
  - [ ] Distribute layers across threads
  - [ ] Handle shared AABB tree access
  - [ ] Merge results efficiently
- [ ] Parallel tree construction
  - [ ] Split large subtrees across threads
  - [ ] Parallel SAH evaluation
  - [ ] Thread-safe node allocation

### Week 16-17: Final Optimizations
**Status:** 🔴 TODO

- [ ] SIMD optimizations
  - [ ] Vectorized ray-box intersection
  - [ ] Batch point-in-polygon tests
  - [ ] SIMD-friendly data layouts
- [ ] Memory optimizations
  - [ ] Custom allocators for hot paths
  - [ ] Reduce AABB node to 32 bytes
  - [ ] Memory pool for polygons
- [ ] Profile-guided optimization
  - [ ] Identify hot functions
  - [ ] Optimize critical loops
  - [ ] Reduce allocations

## 📊 Success Metrics

### Functional Requirements
- [ ] 99%+ polygon completion rate
- [ ] <1% volume error vs input
- [ ] Zero crashes on test suite
- [ ] Handle all test STL files

### Performance Requirements
- [ ] <10ms AABB construction (1K triangles)
- [ ] <100ms AABB construction (10K triangles)
- [ ] >10K slices/second throughput
- [ ] <2GB memory for 500MB STL

## 🧪 Test Suite

### STL Test Files Needed
- [ ] Simple cube (validation)
- [ ] Complex mechanical part (real-world)
- [ ] Hollow object with holes (ExPolygon)
- [ ] High-poly organic shape (performance)
- [ ] Degenerate geometry (edge cases)
- [ ] Self-intersecting mesh (robustness)

### Benchmark Suite
- [ ] AABB construction performance
- [ ] Slicing throughput measurement
- [ ] Memory usage tracking
- [ ] Multi-threading scalability

## 📝 Documentation Tasks

- [ ] Update DEVELOPMENT_GUIDE.md with progress
- [ ] Document new algorithms as implemented
- [ ] Create visual debugging tools
- [ ] Write performance tuning guide

## 🎯 Current Sprint (This Week)

**Priority Order:**
1. Fix AABB O(n³) bug (1-2 days)
2. Start gap closing implementation (2-3 days)
3. Set up test STL collection

**Daily Tasks:**
- Morning: Fix AABB performance bug
- Afternoon: Implement gap detection
- Evening: Test and document progress

---

**Last Updated:** Current session  
**Next Review:** End of week  
**Overall Timeline:** 16 weeks to production parity