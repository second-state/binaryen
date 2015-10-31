#!/bin/sh

echo "calling emcc"
emcc $1 -o a.html --separate-asm -O2 -profiling

# we now have a.asm.js and a.js

echo 'constructing a.normal.js' # just normal combination of the files. no wasm yet
cat src/templates/normal.js > a.normal.js
cat a.asm.js >> a.normal.js
cat a.js >> a.normal.js

echo 'constructing a.wasm.js' # use wasm polyfill in place of asm.js THIS IS NOT A DRILL
cp a.asm.js a.asm.code.js
cat src/templates/wasm.js > a.wasm.js
cat bin/wasm.js >> a.wasm.js
cat a.js >> a.wasm.js

