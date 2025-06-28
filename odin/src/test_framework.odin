package main

import "core:fmt"
import "core:time"
import "core:mem"
import "core:strings"
import "core:os"
import "core:slice"

// ===== TEST FRAMEWORK =====
// Universal testing harness for OrcaSlicer Odin rewrite
// Provides: assertions, timing, memory tracking, visual output

TestResult :: enum {
    PASS,
    FAIL,
    SKIP,
    TIMEOUT,
}

TestCase :: struct {
    name: string,
    test_proc: proc() -> bool,
    timeout_ms: i32,
    expected_duration_ms: i32,
    category: TestCategory,
}

TestCategory :: enum {
    UNIT,           // Pure functions, algorithms
    INTEGRATION,    // Component interaction  
    SYSTEM,         // End-to-end pipeline
    PERFORMANCE,    // Speed/memory benchmarks
    PROPERTY,       // Random/fuzz testing
}

TestStats :: struct {
    passed: int,
    failed: int,
    skipped: int,
    timeout: int,
    total_duration_ms: i32,
    memory_used_bytes: int,
}

TestSuite :: struct {
    name: string,
    tests: [dynamic]TestCase,
    stats: TestStats,
    setup_proc: proc(),
    teardown_proc: proc(),
    output_file: string,
}

// Global test registry
g_test_suites: [dynamic]TestSuite

// ===== TEST RUNNER =====

test_framework_init :: proc() {
    g_test_suites = make([dynamic]TestSuite)
}

test_framework_cleanup :: proc() {
    for &suite in g_test_suites {
        delete(suite.tests)
    }
    delete(g_test_suites)
}

test_suite_create :: proc(name: string) -> ^TestSuite {
    suite := TestSuite{
        name = name,
        tests = make([dynamic]TestCase),
        stats = {},
        output_file = fmt.tprintf("test_output_%s.html", name),
    }
    append(&g_test_suites, suite)
    return &g_test_suites[len(g_test_suites) - 1]
}

test_case_add :: proc(suite: ^TestSuite, name: string, test_proc: proc() -> bool, 
                     category: TestCategory = .UNIT, timeout_ms: i32 = 5000) {
    test_case := TestCase{
        name = name,
        test_proc = test_proc,
        timeout_ms = timeout_ms,
        category = category,
    }
    append(&suite.tests, test_case)
}

test_suite_run :: proc(suite: ^TestSuite, filter: string = "") -> TestStats {
    fmt.printf("\n=== Running Test Suite: %s ===\n", suite.name)
    
    if suite.setup_proc != nil {
        suite.setup_proc()
    }
    defer if suite.teardown_proc != nil {
        suite.teardown_proc()
    }
    
    suite.stats = {}
    start_time := time.now()
    start_memory := mem.total_used()
    
    // Track memory at start
    tracking_allocator := mem.tracking_allocator_init(&mem.default_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    
    for &test_case in suite.tests {
        // Apply filter if specified
        if filter != "" && !strings.contains(test_case.name, filter) {
            continue
        }
        
        result := test_case_run(&test_case)
        
        switch result {
        case .PASS:
            suite.stats.passed += 1
            fmt.printf("  ✅ %s\n", test_case.name)
        case .FAIL:
            suite.stats.failed += 1
            fmt.printf("  ❌ %s\n", test_case.name)
        case .SKIP:
            suite.stats.skipped += 1
            fmt.printf("  ⏭️  %s (SKIPPED)\n", test_case.name)
        case .TIMEOUT:
            suite.stats.timeout += 1
            fmt.printf("  ⏰ %s (TIMEOUT)\n", test_case.name)
        }
    }
    
    end_time := time.now()
    end_memory := mem.total_used()
    
    suite.stats.total_duration_ms = i32(time.duration_milliseconds(time.diff(start_time, end_time)))
    suite.stats.memory_used_bytes = end_memory - start_memory
    
    // Check for memory leaks
    if len(tracking_allocator.allocation_map) > 0 {
        fmt.printf("  ⚠️  Memory leaks detected: %d allocations not freed\n", 
                   len(tracking_allocator.allocation_map))
        
        // List first few leaks for debugging
        count := 0
        for _, alloc in tracking_allocator.allocation_map {
            if count >= 5 do break
            fmt.printf("    Leak: %d bytes at %p\n", alloc.size, alloc.memory)
            count += 1
        }
    }
    
    mem.tracking_allocator_destroy(&tracking_allocator)
    
    test_suite_print_summary(suite)
    test_suite_export_html(suite)
    
    return suite.stats
}

test_case_run :: proc(test_case: ^TestCase) -> TestResult {
    start_time := time.now()
    
    // Run test with timeout protection
    result_channel := make(chan bool, 1)
    
    // Launch test in separate goroutine (if Odin supports it, otherwise run directly)
    success := test_case.test_proc()
    
    end_time := time.now()
    duration_ms := i32(time.duration_milliseconds(time.diff(start_time, end_time)))
    
    if duration_ms > test_case.timeout_ms {
        return .TIMEOUT
    }
    
    return success ? .PASS : .FAIL
}

test_suite_print_summary :: proc(suite: ^TestSuite) {
    total_tests := suite.stats.passed + suite.stats.failed + suite.stats.skipped + suite.stats.timeout
    
    fmt.printf("\n--- Test Suite Summary: %s ---\n", suite.name)
    fmt.printf("Total Tests: %d\n", total_tests)
    fmt.printf("✅ Passed:   %d (%.1f%%)\n", suite.stats.passed, 
               f64(suite.stats.passed) / f64(total_tests) * 100.0)
    fmt.printf("❌ Failed:   %d (%.1f%%)\n", suite.stats.failed,
               f64(suite.stats.failed) / f64(total_tests) * 100.0)
    fmt.printf("⏭️  Skipped:  %d\n", suite.stats.skipped)
    fmt.printf("⏰ Timeout:  %d\n", suite.stats.timeout)
    fmt.printf("⏱️  Duration: %d ms\n", suite.stats.total_duration_ms)
    fmt.printf("🧠 Memory:   %d bytes\n", suite.stats.memory_used_bytes)
    
    success_rate := f64(suite.stats.passed) / f64(total_tests) * 100.0
    if success_rate >= 95.0 {
        fmt.printf("🎯 CONFIDENCE LEVEL: HIGH (%.1f%%)\n", success_rate)
    } else if success_rate >= 80.0 {
        fmt.printf("⚠️  CONFIDENCE LEVEL: MEDIUM (%.1f%%)\n", success_rate)
    } else {
        fmt.printf("🚨 CONFIDENCE LEVEL: LOW (%.1f%%)\n", success_rate)
    }
}

test_suite_export_html :: proc(suite: ^TestSuite) {
    // Create HTML report for visual debugging
    html_content := strings.builder_make()
    defer strings.builder_destroy(&html_content)
    
    fmt.sbprintf(&html_content, "<html><head><title>Test Results: %s</title>", suite.name)
    fmt.sbprintf(&html_content, "<style>")
    fmt.sbprintf(&html_content, "body { font-family: monospace; margin: 20px; }")
    fmt.sbprintf(&html_content, ".pass { color: green; }")
    fmt.sbprintf(&html_content, ".fail { color: red; }")
    fmt.sbprintf(&html_content, ".skip { color: orange; }")
    fmt.sbprintf(&html_content, ".timeout { color: purple; }")
    fmt.sbprintf(&html_content, ".summary { background: #f0f0f0; padding: 10px; margin: 10px 0; }")
    fmt.sbprintf(&html_content, "</style></head><body>")
    
    fmt.sbprintf(&html_content, "<h1>Test Results: %s</h1>", suite.name)
    
    // Summary section
    total_tests := suite.stats.passed + suite.stats.failed + suite.stats.skipped + suite.stats.timeout
    success_rate := f64(suite.stats.passed) / f64(total_tests) * 100.0
    
    fmt.sbprintf(&html_content, "<div class='summary'>")
    fmt.sbprintf(&html_content, "<h2>Summary</h2>")
    fmt.sbprintf(&html_content, "<p>Total Tests: %d</p>", total_tests)
    fmt.sbprintf(&html_content, "<p>Success Rate: %.1f%%</p>", success_rate)
    fmt.sbprintf(&html_content, "<p>Duration: %d ms</p>", suite.stats.total_duration_ms)
    fmt.sbprintf(&html_content, "<p>Memory Used: %d bytes</p>", suite.stats.memory_used_bytes)
    fmt.sbprintf(&html_content, "</div>")
    
    // Individual test results
    fmt.sbprintf(&html_content, "<h2>Test Cases</h2>")
    fmt.sbprintf(&html_content, "<ul>")
    
    for test_case in suite.tests {
        class_name := "unknown"
        status := "?"
        
        // This is simplified - in real implementation, we'd track individual results
        fmt.sbprintf(&html_content, "<li class='%s'>%s: %s</li>", 
                     class_name, test_case.name, status)
    }
    
    fmt.sbprintf(&html_content, "</ul>")
    fmt.sbprintf(&html_content, "</body></html>")
    
    // Write to file
    html_string := strings.to_string(html_content)
    os.write_entire_file(suite.output_file, transmute([]byte)html_string)
    
    fmt.printf("📊 Test report exported: %s\n", suite.output_file)
}

// ===== ASSERTION HELPERS =====

test_assert :: proc(condition: bool, message: string = "") -> bool {
    if !condition {
        if message != "" {
            fmt.printf("    ASSERTION FAILED: %s\n", message)
        } else {
            fmt.printf("    ASSERTION FAILED\n")
        }
        return false
    }
    return true
}

test_assert_eq :: proc(a, b: $T, message: string = "") -> bool {
    if a != b {
        if message != "" {
            fmt.printf("    ASSERTION FAILED: %s (expected %v, got %v)\n", message, a, b)
        } else {
            fmt.printf("    ASSERTION FAILED: expected %v, got %v\n", a, b)
        }
        return false
    }
    return true
}

test_assert_near :: proc(a, b: f64, tolerance: f64 = 1e-9, message: string = "") -> bool {
    diff := abs(a - b)
    if diff > tolerance {
        if message != "" {
            fmt.printf("    ASSERTION FAILED: %s (|%v - %v| = %v > %v)\n", 
                       message, a, b, diff, tolerance)
        } else {
            fmt.printf("    ASSERTION FAILED: |%v - %v| = %v > %v\n", a, b, diff, tolerance)
        }
        return false
    }
    return true
}

test_assert_not_null :: proc(ptr: rawptr, message: string = "") -> bool {
    if ptr == nil {
        if message != "" {
            fmt.printf("    ASSERTION FAILED: %s (pointer is null)\n", message)
        } else {
            fmt.printf("    ASSERTION FAILED: pointer is null\n")
        }
        return false
    }
    return true
}

// ===== PERFORMANCE HELPERS =====

PerfTimer :: struct {
    start_time: time.Time,
    end_time: time.Time,
    name: string,
}

perf_timer_start :: proc(name: string) -> PerfTimer {
    return PerfTimer{
        start_time = time.now(),
        name = name,
    }
}

perf_timer_stop :: proc(timer: ^PerfTimer) -> i32 {
    timer.end_time = time.now()
    duration_ms := i32(time.duration_milliseconds(time.diff(timer.start_time, timer.end_time)))
    fmt.printf("    ⏱️  %s: %d ms\n", timer.name, duration_ms)
    return duration_ms
}

test_assert_performance :: proc(timer: PerfTimer, max_ms: i32, message: string = "") -> bool {
    duration_ms := i32(time.duration_milliseconds(time.diff(timer.start_time, timer.end_time)))
    if duration_ms > max_ms {
        if message != "" {
            fmt.printf("    PERFORMANCE FAILED: %s (%d ms > %d ms limit)\n", 
                       message, duration_ms, max_ms)
        } else {
            fmt.printf("    PERFORMANCE FAILED: %d ms > %d ms limit\n", duration_ms, max_ms)
        }
        return false
    }
    return true
}

// ===== RUNNER UTILITIES =====

test_run_all :: proc(filter: string = "") {
    fmt.println("🚀 Starting OrcaSlicer Test Suite")
    fmt.println("==================================")
    
    total_stats := TestStats{}
    
    for &suite in g_test_suites {
        if filter != "" && !strings.contains(suite.name, filter) {
            continue
        }
        
        stats := test_suite_run(&suite, filter)
        total_stats.passed += stats.passed
        total_stats.failed += stats.failed
        total_stats.skipped += stats.skipped
        total_stats.timeout += stats.timeout
        total_stats.total_duration_ms += stats.total_duration_ms
        total_stats.memory_used_bytes += stats.memory_used_bytes
    }
    
    fmt.println("\n🎯 OVERALL RESULTS")
    fmt.println("==================")
    total_tests := total_stats.passed + total_stats.failed + total_stats.skipped + total_stats.timeout
    success_rate := f64(total_stats.passed) / f64(total_tests) * 100.0
    
    fmt.printf("Total Tests: %d\n", total_tests)
    fmt.printf("Success Rate: %.1f%%\n", success_rate)
    fmt.printf("Total Duration: %d ms\n", total_stats.total_duration_ms)
    fmt.printf("Total Memory: %d bytes\n", total_stats.memory_used_bytes)
    
    if success_rate >= 95.0 {
        fmt.println("🎉 READY FOR VIBE-CODING!")
    } else if success_rate >= 80.0 {
        fmt.println("⚠️  NEEDS SOME WORK")
    } else {
        fmt.println("🚨 CRITICAL ISSUES - FIX BEFORE CODING")
    }
}

test_run_fast :: proc() {
    // Run only unit tests for quick feedback
    test_run_all("unit")
}

test_run_category :: proc(category: TestCategory) {
    category_name := ""
    switch category {
    case .UNIT: category_name = "unit"
    case .INTEGRATION: category_name = "integration"
    case .SYSTEM: category_name = "system"
    case .PERFORMANCE: category_name = "performance"
    case .PROPERTY: category_name = "property"
    }
    
    fmt.printf("🎯 Running %s tests only\n", category_name)
    
    for &suite in g_test_suites {
        filtered_tests := make([dynamic]TestCase)
        defer delete(filtered_tests)
        
        for test_case in suite.tests {
            if test_case.category == category {
                append(&filtered_tests, test_case)
            }
        }
        
        if len(filtered_tests) > 0 {
            // Create temporary suite with filtered tests
            original_tests := suite.tests
            suite.tests = filtered_tests
            test_suite_run(&suite)
            suite.tests = original_tests
        }
    }
}
