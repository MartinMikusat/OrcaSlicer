# OrcaSlicer Odin Rewrite - Test Makefile
# Provides convenient shortcuts for testing

.PHONY: test-fast test-unit test-integration test-system test-performance test-all test-watch test-build test-clean help

# Default target - quick unit tests
test: test-fast

# Quick unit tests for immediate feedback (< 1s)
test-fast:
	@echo "🚀 Running quick unit tests..."
	@./test.sh fast

# All unit tests 
test-unit:
	@echo "🧪 Running all unit tests..."
	@./test.sh unit

# Integration tests
test-integration:
	@echo "🔗 Running integration tests..."
	@./test.sh integration

# System/end-to-end tests
test-system:
	@echo "🌐 Running system tests..."
	@./test.sh system

# Performance benchmarks
test-performance:
	@echo "⚡ Running performance tests..."
	@./test.sh performance

# All tests
test-all:
	@echo "🎯 Running complete test suite..."
	@./test.sh all

# Watch mode - run tests on file changes
test-watch:
	@echo "👀 Starting test watch mode..."
	@./test.sh watch

# Build tests without running
test-build:
	@echo "🔨 Building test suite..."
	@./test.sh build

# Clean test outputs
test-clean:
	@echo "🧹 Cleaning test outputs..."
	@./test.sh clean

# Filter tests by pattern
# Usage: make test-unit-filter FILTER=geometry
test-unit-filter:
	@echo "🔍 Running filtered unit tests..."
	@./test.sh unit $(FILTER)

test-integration-filter:
	@echo "🔍 Running filtered integration tests..."
	@./test.sh integration $(FILTER)

# Vibe-coding workflow targets
vibe-check: test-fast
	@echo "✨ Quick vibe check complete!"

vibe-full: test-all
	@echo "🎉 Full confidence check complete!"

# Development workflow
dev-setup: test-build
	@echo "🛠️  Development environment ready!"

dev-check: test-unit test-integration
	@echo "✅ Development check complete!"

# Continuous Integration targets
ci-fast: test-unit
	@echo "⚡ CI fast tests complete!"

ci-full: test-all
	@echo "🎯 CI full tests complete!"

# Performance monitoring
perf-check: test-performance
	@echo "📊 Performance benchmarks complete!"

# Help target
help:
	@echo "OrcaSlicer Test Commands"
	@echo "========================"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make test              - Quick unit tests (default)"
	@echo "  make test-fast         - Quick unit tests"
	@echo "  make test-unit         - All unit tests"
	@echo "  make test-integration  - Integration tests"
	@echo "  make test-system       - System tests"
	@echo "  make test-performance  - Performance benchmarks"
	@echo "  make test-all          - Complete test suite"
	@echo ""
	@echo "Development Workflow:"
	@echo "  make vibe-check        - Quick confidence check"
	@echo "  make vibe-full         - Full confidence check"
	@echo "  make dev-setup         - Setup development environment"
	@echo "  make dev-check         - Development validation"
	@echo ""
	@echo "Utilities:"
	@echo "  make test-watch        - Watch mode (run tests on changes)"
	@echo "  make test-build        - Build tests without running"
	@echo "  make test-clean        - Clean test outputs"
	@echo ""
	@echo "Filtered Testing:"
	@echo "  make test-unit-filter FILTER=geometry"
	@echo "  make test-integration-filter FILTER=memory"
	@echo ""
	@echo "For more details: ./test.sh help"
