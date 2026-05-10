#!/bin/bash
f=(~/gits/moot/optimize/*/*.csv)

# Generator: Now printing 4 items (Seed, B, C, File) separated by null bytes
for i in {1..100000}; do
    printf "%s\0%s\0%s\0%s\0" "$RANDOM" "$((RANDOM % 150 + 1))" "$((RANDOM % 10 + 1))" "${f[RANDOM % ${#f[@]}]}"
done | 
xargs -0 -n 4 -P 20 bash -c 'lua ezr.lua -s "$1" -B "$2" -C "$3" --test1 "$4"' _
