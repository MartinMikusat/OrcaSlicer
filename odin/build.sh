#!/bin/bash
# Build script for OrcaSlicer Odin rewrite
# Usage: ./build.sh [debug|release]

BUILD_TYPE=${1:-debug}

echo "Building OrcaSlicer Odin ($BUILD_TYPE)..."

# Create bin directory if it doesn't exist
mkdir -p bin

if [ "$BUILD_TYPE" = "debug" ]; then
    odin build src -out:bin/orcaslicer_debug -debug
else
    odin build src -out:bin/orcaslicer -opt:3
fi

if [ $? -eq 0 ]; then
    echo "Build successful!"
else
    echo "Build failed!"
    exit 1
fi