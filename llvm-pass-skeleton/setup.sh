#!/bin/bash
set -e
mkdir -p build
cd build
cmake ..
make
cd ..
echo "Running clang with the LLVM pass plugin..."
clang -fpass-plugin=$(echo build/skeleton/SkeletonPass.*) a.c
