import { defineConfig } from "vite";
import { sveltekit } from "@sveltejs/kit/vite";
import glsl from "vite-plugin-glsl";
import tailwindcss from "@tailwindcss/vite";

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
  optimizeDeps: {
    include: ["three"],
    exclude: ["@sveltejs/kit"],
  },
  ssr: {
    noExternal: ["three"],
  },
  resolve: {
    dedupe: ["three"],
  },
});
