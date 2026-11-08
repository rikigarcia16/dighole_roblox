#!/bin/bash
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")"
OUT=$(cygpath -m "$PWD/../../02_ROBLOX_ICONS/renders"); mkdir -p "$OUT"
for v in "$@"; do
  RES=1024 SAMPLES=160 "$B" -b -P icons.py -- $v "$OUT/${v}_raw.png" 2>&1 | grep -E "RENDERED|Error|Traceback"
  RES=1024 MASK=1 "$B" -b -P icons.py -- $v "$OUT/${v}_mask.png" 2>&1 | grep -E "RENDERED|Error|Traceback"
done
