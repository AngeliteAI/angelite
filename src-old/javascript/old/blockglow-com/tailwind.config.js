/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{html,js,svelte,ts}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Mundial",
          ...require("tailwindcss/defaultTheme").fontFamily.sans,
        ],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("tailwindcss-motion")({
      presets: {
        "typewriter-24": {
          initial: {
            width: "0%",
            opacity: "0",
          },
          enter: {
            width: "100%",
            opacity: "1",
            transition: {
              type: "steps(24)",
              duration: "2s",
            },
          },
          exit: {
            width: "0%",
            opacity: "0",
            transition: {
              type: "steps(24)",
              duration: "1.5s",
            },
          },
        },
      },
    }),
  ],
};
