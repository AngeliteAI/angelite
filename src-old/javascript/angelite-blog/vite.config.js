import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
  server: {
		allowedHosts: true,
		fs: {
			// Allow serving files from one level up to the project root
			allow: ['../**/*']
		}
	},
});
