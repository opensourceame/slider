#!/bin/sh
printf '\033c\033]0;%s\a' Sliding Puzzle
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Sliding Puzzle.x86_64" "$@"
