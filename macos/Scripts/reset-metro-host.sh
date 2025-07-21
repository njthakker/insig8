#!/bin/bash

# Reset Metro host to localhost
export RCT_METRO_HOST=localhost
export RCT_METRO_PORT=8081

# Kill any existing Metro processes
pkill -f "metro"

# Clear Metro cache
rm -rf $TMPDIR/metro-*
rm -rf ~/Library/Caches/com.facebook.ReactNativeBuild/*

echo "Metro host reset to localhost:8081"
echo "Metro cache cleared"
echo ""
echo "To start Metro bundler, run:"
echo "cd /Users/neel/Desktop/Projects/insig8 && npm start"