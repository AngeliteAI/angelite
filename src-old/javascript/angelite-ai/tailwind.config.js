const path = require('path');

/** @type {import('tailwindcss').Config} */
  module.exports = {
content: [
    './src/**/*.{html,js,svelte,ts}',
path.join(path.dirname(require.resolve('angelite')), '**/*.{html,js,svelte,ts}'),
],
  theme: {
  colors: {
    // Primary: A soft, glowing blue inspired by angelite crystals, evoking serenity and divinity
    primary: '#6B9EFF', // Muted blue with a heavenly touch
    // Secondary: A subtle, shimmering silver for side elements, like angelic wings catching light
    secondary: '#A3BFFA', // Pale bluish-silver, widely usable for borders, sidebars, or highlights
    // Accent: A bright, celestial cyan to draw attention with an ethereal pop
    accent: '#40C4FF', // Vibrant yet soft, like a sky lit by divine energy
    // Background: A deep, cosmic navy for a rich, dark foundation
    background: '#0D1B2A', // Darker than midnight, with a hint of blue mystique
    // Text: A crisp, cool off-white for readability with an angelic glow
    text: '#E6F0FA', // Light and legible, with a faint blue undertone
    // Text-Secondary: A muted blue-gray for hierarchy and balance
    text_secondary: '#90CAF9', // Softer, supportive tone for less prominent text
    // Success: A radiant, warm gold to signify positivity with a divine flair
    success: '#FFD740', // Golden hue, like a halo’s gleam
    // Error: A deep, velvety red for contrast, softened to fit the angelic theme
    error: '#FF6E6E', // Subtle yet striking, like a warning from above
  },
}
  // other config options...
};
