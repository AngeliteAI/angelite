import { defineConfig } from "vite";
import { sveltekit } from "@sveltejs/kit/vite";
import glsl from "vite-plugin-glsl";

export default defineConfig({
  plugins: [
    sveltekit(),
    glsl({
      include: ["**/*.glsl", "**/*.vert", "**/*.frag"],
      exclude: undefined,
      warnDuplicatedImports: true,
      defaultExtension: "glsl",
      compress: false,
      watch: true,
    }),
  ],
  // Update the optimizeDeps configuration
  optimizeDeps: {
    include: ["three"],
    exclude: ["@sveltejs/kit"],
  },
  ssr: {
    noExternal: ["three"],
  },
  // Add resolve configuration
  resolve: {
    dedupe: ["three"],
  },
});
