#!/bin/bash
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")"
OUT=$(cygpath -m "$PWD/../../01_BRANDING/renders")
for v in main_en main_es horizontal_en horizontal_es compact_en symbol; do
  "$B" -b -P logo.py -- $v "$OUT/logo_${v}_raw.png" 2>&1 | grep -E "RENDERED|Error|Traceback"
done
