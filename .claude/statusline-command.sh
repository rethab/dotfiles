#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project=$(echo "$input" | jq -r '.workspace.project_dir')

# Get context window usage percentage
# Note: This is a placeholder calculation as actual context usage isn't available in the JSON
# We'll simulate it based on transcript size or other available metrics
transcript_path=$(echo "$input" | jq -r '.transcript_path')
context_percentage=0

if [[ -f "$transcript_path" ]]; then
    # Estimate context usage based on transcript file size
    # This is an approximation - actual context calculation would be more complex
    file_size=$(wc -c < "$transcript_path" 2>/dev/null || echo 0)
    # Assume ~200k token limit for Claude 3.5 Sonnet, roughly 800k characters
    # Adjust this calculation based on actual model limits
    max_chars=800000
    context_percentage=$((file_size * 100 / max_chars))
    
    # Cap at 100%
    if [[ $context_percentage -gt 100 ]]; then
        context_percentage=100
    fi
fi

# Color coding for context percentage
context_color=""
if [[ $context_percentage -lt 30 ]]; then
    context_color=$'\033[32m'  # Green for low usage
elif [[ $context_percentage -lt 50 ]]; then
    context_color=$'\033[33m'  # Yellow for medium usage
else
    context_color=$'\033[31m'  # Red for high usage
fi

# Build the status line
printf $'\033[36m%s\033[0m in \033[32m%s\033[0m | Context: %s%d%%\033[0m' \
    "$model" \
    "$(basename "$cwd")" \
    "$context_color" \
    "$context_percentage"
