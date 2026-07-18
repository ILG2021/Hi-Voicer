import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  test: {
    environment: "jsdom",
    environmentOptions: {
      jsdom: {
        url: "http://localhost",
      },
    },
    globals: true,
  },
  server: {
    port: 1420,
    strictPort: true,
    // Rust/Tauri owns this directory. Do not let Vite watch locked build DLLs.
    watch: {
      ignored: [/[\\/]src-tauri[\\/]/],
    },
  },
  envPrefix: ["VITE_", "TAURI_"],
});
