#!/bin/bash

# Remove the zig-cache directory
rm -rf zig-cache/

# Build your zig project with tests
zig build test

# Find the test binary within zig-cache and run it with lldb
TEST_BINARY=$(find zig-cache -name test)
lldb "$TEST_BINARY"

