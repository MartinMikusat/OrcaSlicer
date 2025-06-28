#!/bin/bash

# OrcaSlicer Test Runner
# Provides easy commands for different types of testing

set -e  # Exit on any error

ODIN_DIR="./odin"
TEST_FILE="$ODIN_DIR/test.odin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo "OrcaSlicer Test Runner"
    echo "====================="
    echo ""
    echo "Usage: ./test.sh [command] [filter]"
    echo ""
    echo "Commands:"
    echo "  fast       - Quick unit tests only (< 1s)"
    echo "  unit       - All unit tests"
    echo "  integration- Integration tests" 
    echo "  system     - System/end-to-end tests"
    echo "  performance- Performance benchmarks"
    echo "  all        - All tests"
    echo "  watch      - Run unit tests on file changes"
    echo "  build      - Just build, don't run tests"
    echo "  clean      - Clean test outputs"
    echo ""
    echo "Examples:"
    echo "  ./test.sh fast           # Quick feedback"
    echo "  ./test.sh unit geometry  # Only geometry unit tests"
    echo "  ./test.sh performance    # Performance benchmarks"
    echo "  ./test.sh all           # Full test suite"
}

run_tests() {
    local category="$1"
    local filter="$2"
    
    echo -e "${BLUE}🚀 Running $category tests...${NC}"
    
    cd "$ODIN_DIR"
    
    if [ -n "$filter" ]; then
        echo -e "${YELLOW}📋 Filter: $filter${NC}"
        odin run test.odin -- "$category" "$filter"
    else
        odin run test.odin -- "$category"
    fi
    
    local exit_code=$?
    cd ..
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Tests completed successfully!${NC}"
    else
        echo -e "${RED}❌ Tests failed with exit code $exit_code${NC}"
        exit $exit_code
    fi
}

build_tests() {
    echo -e "${BLUE}🔨 Building test suite...${NC}"
    cd "$ODIN_DIR"
    odin build test.odin -out:test_runner
    local exit_code=$?
    cd ..
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Build completed successfully!${NC}"
    else
        echo -e "${RED}❌ Build failed with exit code $exit_code${NC}"
        exit $exit_code
    fi
}

clean_tests() {
    echo -e "${YELLOW}🧹 Cleaning test outputs...${NC}"
    rm -f "$ODIN_DIR/test_runner"
    rm -f "$ODIN_DIR"/*.html
    rm -f "$ODIN_DIR"/test_output_*.html
    echo -e "${GREEN}✅ Cleanup completed!${NC}"
}

watch_tests() {
    echo -e "${BLUE}👀 Watching for file changes (Ctrl+C to stop)...${NC}"
    echo -e "${YELLOW}Will run unit tests on any .odin file change${NC}"
    
    # Use fswatch on macOS, inotifywait on Linux
    if command -v fswatch >/dev/null 2>&1; then
        fswatch -o "$ODIN_DIR"/*.odin | while read f; do
            echo -e "${BLUE}📝 File changed, running unit tests...${NC}"
            run_tests "unit" ""
            echo -e "${YELLOW}👀 Watching for more changes...${NC}"
        done
    elif command -v inotifywait >/dev/null 2>&1; then
        while inotifywait -e modify "$ODIN_DIR"/*.odin; do
            echo -e "${BLUE}📝 File changed, running unit tests...${NC}"
            run_tests "unit" ""
            echo -e "${YELLOW}👀 Watching for more changes...${NC}"
        done
    else
        echo -e "${RED}❌ File watching not available (install fswatch or inotify-tools)${NC}"
        echo -e "${YELLOW}💡 Falling back to manual testing mode${NC}"
        run_tests "unit" ""
    fi
}

# Main script logic
case "${1:-fast}" in
    "fast")
        run_tests "fast" "$2"
        ;;
    "unit")
        run_tests "unit" "$2"
        ;;
    "integration")
        run_tests "integration" "$2"
        ;;
    "system")
        run_tests "system" "$2"
        ;;
    "performance")
        run_tests "performance" "$2"
        ;;
    "all")
        run_tests "all" "$2"
        ;;
    "watch")
        watch_tests
        ;;
    "build")
        build_tests
        ;;
    "clean")
        clean_tests
        ;;
    "help"|"-h"|"--help")
        print_usage
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac
