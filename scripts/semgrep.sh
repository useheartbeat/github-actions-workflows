#!/bin/bash

PARENT_DIR=${1:-$(pwd)}

OUTPUT_FILE="semgreptrivyoutput.txt"

> "$OUTPUT_FILE"

# Loop through each subdirectory in the parent directory
for dir in "$PARENT_DIR"/*/; do
    if [ -d "$dir" ]; then
        echo "Entering directory: $dir"
        cd "$dir" || continue

        semgrep scan . >> "$PARENT_DIR/$OUTPUT_FILE" 2>&1
        trivy fs . >> "$PARENT_DIR/$OUTPUT_FILE" 2>&1

        echo "Command executed in $dir, output appended to $OUTPUT_FILE"

        cd "$PARENT_DIR" || exit
    fi
done

echo "Script completed. Output written to $OUTPUT_FILE."