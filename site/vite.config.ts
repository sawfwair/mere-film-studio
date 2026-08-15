import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

const devPort = Number(process.env.PORT ?? 4477);
const previewPort = Number(process.env.PREVIEW_PORT ?? 5477);

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    host: '127.0.0.1',
    port: devPort,
    strictPort: true
  },
  preview: {
    host: '127.0.0.1',
    port: previewPort,
    strictPort: true
  }
});
