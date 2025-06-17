cd ../angelite && rm -rf ./dist && npm run build && npm publish && cd ../angelite-ai
npm update && npm install
bun run dev -- --host --port 80
