import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ocean: {
          50: "#eff8ff",
          100: "#dbeefe",
          500: "#0e7fc4",
          600: "#0a6499",
          700: "#0a5077",
        },
      },
    },
  },
  plugins: [],
};

export default config;
