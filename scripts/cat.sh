#!/bin/bash

ignorefile=.catignore

# Check if a directory path is provided as an argument
if [ "$#" -eq 1 ]; then
    dirpath="$1"
else
    dirpath="."
fi

# Enable shell options for handling wildcards and hidden files
shopt -s nullglob dotglob

# Function to check if a file should be ignored
should_ignore() {
    local file="${1#./}"  # Remove leading './' if present
    local pattern
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
        [[ -z "$pattern" || "$pattern" == \#* ]] && continue
        if [[ "$file" == $pattern || "$file" == */$pattern || "$file" == $pattern* || "$file" == */$pattern* ]]; then
            return 0
        fi
    done < "$dirpath/$ignorefile"
    return 1
}

# Check if the $ignorefile exists in the specified directory
if [ -f "$dirpath/$ignorefile" ]; then
    # Find all files in the specified directory and its subdirectories
    find "$dirpath" -type f | while IFS= read -r file; do
        if ! should_ignore "${file#./}"; then
            if [ -f "$file" ] && ! file --mime "$file" | grep -q 'binary'; then
                echo -e "\n********\nFilename: $file\nContent:\n"
                cat "$file"
            fi
        fi
    done
else
    echo "$ignorefile not found in $dirpath. Processing all non-binary files."
    # If .catignore is not found, cat all non-binary files
    find "$dirpath" -type f | while IFS= read -r file; do
        if [ -f "$file" ] && ! file --mime "$file" | grep -q 'binary'; then
            echo -e "\n********\nFilename: $file\nContent:\n"
            cat "$file"
        fi
    done
fi
