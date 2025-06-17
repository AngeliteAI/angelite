#!/bin/bash
# filepath: /root/angelite/src/zig/gfx/run.sh
zig run \
  -lc \
  -lvulkan \
  -lxcb \
  -I /usr/include/ \
  -I /usr/include/x86_64-linux-gnu \
  -I /root/angelite/vendor/shaderc/include \
  -L /root/angelite/vendor/shaderc/build/libshaderc \
  -lshaderc \
  main.zig
