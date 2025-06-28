# Testing Strategy - OrcaSlicer Odin Rewrite

## 🎯 Goal: "Vibe-Code" with Complete Confidence

This testing strategy enables you to code freely while having immediate, reliable feedback on code quality and correctness. Every component will be thoroughly validated through multiple testing approaches.

## 📊 Testing Pyramid

### Level 1: Unit Tests (Foundation) - 90% Coverage Target
**Files:** `test_*_unit.odin`
- **Pure function testing** - Math, geometry, predicates
- **Data structure testing** - Polygons, meshes, trees
- **Algorithm validation** - Sorting, searching, intersections
- **Edge case handling** - Degenerate inputs, boundary conditions
- **Performance regression** - Ensure optimizations don't break correctness

### Level 2: Integration Tests (Components) - 80% Coverage Target  
**Files:** `test_*_integration.odin`
- **Module interaction** - How components work together
- **Pipeline testing** - Multi-stage processes work correctly
- **Memory management** - No leaks, proper cleanup
- **Error propagation** - Failures handled gracefully
- **Configuration validation** - Settings produce expected behavior

### Level 3: System Tests (End-to-End) - 100% Coverage Target
**Files:** `test_*_system.odin`
- **Real STL processing** - Complete pipeline with actual models
- **Performance benchmarks** - Meet all targets under real load
- **Output validation** - G-code correctness, geometric accuracy
- **Stress testing** - Large models, edge cases, memory limits
- **Regression testing** - Previous bugs don't reappear

### Level 4: Property-Based Tests (Chaos) - Fuzz Everything
**Files:** `test_*_property.odin`
- **Random input generation** - Find inputs you never considered
- **Invariant checking** - Properties that must always hold
- **Crash detection** - Never segfault, always handle gracefully
- **Performance stability** - No exponential blowups on weird inputs

## 🚀 Testing Infrastructure

### 1. Test Runner Framework
```odin
// test_framework.odin - Universal test harness
TestSuite :: struct {
    name: string,
    tests: [dynamic]TestCase,
    setup: proc(),
    teardown: proc(),
    stats: TestStats,
}

TestCase :: struct {
    name: string,
    test_proc: proc() -> TestResult,
    timeout_ms: i32,
    expected_duration_ms: i32,
}

TestResult :: struct {
    passed: bool,
    error_msg: string,
    duration_ms: i32,
    memory_used: int,
}
```

### 2. Real STL Test Corpus
```bash
# test_models/ directory structure
test_models/
├── basic/
│   ├── cube_10mm.stl           # Sanity check
│   ├── sphere_20mm.stl         # Curved surfaces
│   ├── cylinder_15mm.stl       # Circular cross-sections
│   └── pyramid_12mm.stl        # Flat faces, sharp edges
├── complex/
│   ├── gear_mechanism.stl      # Multiple components
│   ├── organic_sculpture.stl   # High triangle count
│   ├── hollow_vase.stl         # Internal cavities
│   └── threaded_bolt.stl       # Fine detail, spirals
├── pathological/
│   ├── degenerate_triangles.stl # Zero-area faces
│   ├── self_intersecting.stl    # Invalid geometry
│   ├── micro_details.stl        # Sub-micron features
│   └── huge_model.stl           # Stress test memory/performance
└── reference/
    ├── known_good_outputs/      # Expected G-code for validation
    └── performance_baselines/   # Timing/memory benchmarks
```

### 3. Visual Debugging System
```odin
// debug_visualizer.odin - See what's actually happening
DebugRenderer :: struct {
    layers: [dynamic]DebugLayer,
    current_layer: int,
    output_format: enum { SVG, HTML, JSON },
}

// Export visual debugging data
debug_export_layer :: proc(layer: ^Layer, filename: string)
debug_export_polygons :: proc(polys: []Polygon, filename: string)
debug_export_aabb_tree :: proc(tree: ^AABBTree, filename: string)
debug_export_slicing_process :: proc(mesh: ^TriangleMesh, filename: string)
```

### 4. Performance Monitoring
```odin
// performance_monitor.odin - Track everything
PerfMonitor :: struct {
    timers: map[string]Timer,
    memory_tracker: MemoryTracker,
    counters: map[string]int,
    thresholds: map[string]PerfThreshold,
}

PerfThreshold :: struct {
    max_time_ms: i32,
    max_memory_mb: int,
    max_allocations: int,
}

// Auto-fail tests that exceed performance targets
@(test)
test_aabb_construction_performance :: proc(t: ^testing.T) {
    monitor := perf_monitor_create()
    defer perf_monitor_destroy(&monitor)
    
    perf_monitor_start(&monitor, "aabb_construction")
    
    mesh := load_test_mesh("test_models/complex/gear_mechanism.stl")
    tree := aabb_build(&mesh)
    
    stats := perf_monitor_stop(&monitor, "aabb_construction")
    
    // ARM64 targets from PERFORMANCE_TARGETS.md
    testing.expect(t, stats.time_ms < 100, "AABB construction too slow")
    testing.expect(t, stats.memory_mb < 50, "AABB construction uses too much memory")
    testing.expect(t, stats.allocations < 1000, "Too many allocations")
}
```

### 5. Automated Test Generation
```odin
// test_generator.odin - Create tests automatically
generate_polygon_tests :: proc() {
    // Generate hundreds of polygon test cases
    for i in 0..<1000 {
        poly := generate_random_polygon(min_points=3, max_points=100)
        test_polygon_area(poly)
        test_point_in_polygon(poly)
        test_polygon_offset(poly)
    }
}

generate_mesh_tests :: proc() {
    // Generate diverse mesh test cases
    for complexity in [ComplexityLevel.SIMPLE, .MEDIUM, .COMPLEX] {
        mesh := generate_random_mesh(complexity)
        test_mesh_slicing(mesh)
        test_aabb_construction(mesh)
        test_boolean_operations(mesh)
    }
}
```

## 🧪 Specific Test Categories

### 1. Mathematical Correctness
- **Geometric predicates** - Orientation, intersection, distance
- **Coordinate systems** - mm ↔ micron ↔ coord conversions
- **Floating point stability** - No precision loss, deterministic results
- **Edge cases** - Zero values, infinity, NaN handling

### 2. Algorithmic Robustness  
- **AABB tree construction** - O(n log n) complexity, balanced tree
- **Triangle-plane intersection** - All degenerate cases handled
- **Polygon operations** - Union, intersection, difference, offset
- **Gap closing** - Distance/angle tolerances, connectivity

### 3. Memory Management
- **No leaks** - Every allocation has corresponding free
- **Bounds checking** - Array access validation
- **Stack overflow protection** - Deep recursion limits
- **Memory pressure** - Graceful degradation under low memory

### 4. Performance Validation
- **ARM64 optimization** - SIMD utilization, cache efficiency
- **Throughput targets** - ≥10K layers/second processing
- **Memory targets** - <1GB for 500MB STL files
- **Scaling behavior** - Linear/log complexity verified

### 5. Output Quality
- **G-code validity** - ≥99.9% pass rate on test corpus
- **Geometric accuracy** - <1% volume error vs input
- **Visual validation** - Generated paths match expected patterns
- **Printer compatibility** - Works on real hardware

## 🛠 Implementation Plan

### Week 1: Foundation Testing
1. **Set up test framework** - Runner, assertions, reporting
2. **Unit test all math** - Geometry, predicates, coordinates
3. **Create basic STL corpus** - 10 fundamental test models
4. **Visual debugging** - SVG export for polygons/layers

### Week 2: Component Testing  
1. **Integration test pipelines** - AABB, slicing, boolean ops
2. **Memory testing** - Leak detection, bounds checking
3. **Performance baselines** - Benchmark current implementations
4. **Property-based testing** - Random input generation

### Week 3: System Validation
1. **End-to-end tests** - Complete STL → G-code pipeline
2. **Real model testing** - Complex geometries, edge cases
3. **Stress testing** - Large models, memory limits
4. **Regression testing** - Previous bugs, performance degradation

### Week 4: Quality Assurance
1. **Coverage analysis** - Ensure 90%+ line coverage
2. **Performance validation** - Meet all ARM64 targets
3. **Output validation** - G-code quality metrics
4. **Documentation** - Test results, known limitations

## 🎮 "Vibe-Code" Experience

### Instant Feedback Loop
```bash
# Every save triggers relevant tests
./test --watch --fast    # Run unit tests on file change (< 1s)
./test --integration     # Run integration tests (< 10s)  
./test --system         # Run full system tests (< 60s)
./test --regression     # Run regression suite (< 5min)
```

### Confidence Indicators
```bash
# Dashboard showing current confidence level
=== OrcaSlicer Confidence Dashboard ===
Unit Tests:        ✅ 1,234 / 1,250 (98.7%)
Integration Tests: ✅ 156 / 160 (97.5%)  
System Tests:      ✅ 45 / 48 (93.8%)
Performance:       ✅ All targets met
Memory:            ✅ No leaks detected
Coverage:          ✅ 94.2% line coverage

🎯 CONFIDENCE LEVEL: HIGH (95.3%)
🚀 Ready for production use!
```

### Smart Test Selection
```odin
// Only run tests affected by your changes
test_selector :: proc(changed_files: []string) -> []TestCase {
    affected_tests := make([dynamic]TestCase)
    
    for file in changed_files {
        if strings.contains(file, "geometry") {
            append(&affected_tests, geometry_tests...)
        }
        if strings.contains(file, "boolean") {
            append(&affected_tests, boolean_tests...)
        }
        // etc.
    }
    
    return affected_tests[:]
}
```

## 🎯 Success Metrics

### Code Quality
- **Zero crashes** on any valid input
- **Deterministic results** - same input → same output
- **Graceful degradation** - performance degrades predictably
- **Clear error messages** - developer knows exactly what went wrong

### Development Velocity  
- **Sub-second feedback** for most changes
- **Clear test failures** - easy to understand and fix
- **Comprehensive coverage** - confidence to refactor anywhere
- **Performance visibility** - immediately see optimization impact

### Production Readiness
- **Real-world validation** - tested on actual print jobs
- **Performance targets met** - all ARM64 goals achieved
- **Quality metrics** - G-code validity, geometric accuracy
- **Stability proven** - stress tested, no edge case crashes

This testing strategy transforms development from "hope it works" to "know it works". You'll be able to code freely, knowing that any issues will be caught immediately with clear, actionable feedback.

Ready to build this testing paradise? 🚀
