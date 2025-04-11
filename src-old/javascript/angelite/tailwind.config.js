/** @type {import('tailwindcss').Config} */
export default {
  
  content: [
    './src/**/*.{html,js,svelte,ts}',
  ],
  // ...
  theme: {
      colors: {
        // Add your custom colors here
        primary: '4D88FF',
        accent: '#00FFFF',
        background: '#0A0A2A',
        text: '#001F3F',
        secondary: '#B0B0B0',
        success: '#FF3B30',
        error: '#34C759',
      },
  },
  // other config options...
}
