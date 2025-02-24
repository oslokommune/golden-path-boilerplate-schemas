#!/bin/bash
# This script deletes all .schemas directories in the current directory and one level down, and moves them to
# /tmp/.schemas.

# Create the destination directory if it doesn't exist
mkdir -p /tmp/.schemas

# Find all .schemas directories that are exactly one level deep
for dir in */; do
  if [ -d "${dir}.schemas" ]; then
    # Create the parent directory in the destination
    mkdir -p "/tmp/.schemas/${dir}"
    echo "Moving ${dir}.schemas to /tmp/.schemas/${dir}"
    mv "${dir}.schemas" "/tmp/.schemas/${dir}"
  fi
done

# Also check for .schemas in the current directory
if [ -d ".schemas" ]; then
  echo "Moving ./.schemas to /tmp/.schemas/root"
  mv ".schemas" "/tmp/.schemas/root"
fi

echo "All .schemas directories have been moved."
