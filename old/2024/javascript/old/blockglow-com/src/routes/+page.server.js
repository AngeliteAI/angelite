import { RECAPTCHA_SECRET_KEY } from "$env/static/private";
import fs from "fs";

/** @satisfies {import('./$types').Actions} */
export const actions = {
  newsletter: async (event) => {
    const formData = await event.request.formData();
    const email = formData.get("email")?.toString().toLowerCase();
    const token = formData.get("g-recaptcha-response");

    // Input validation
    if (!email?.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      return {
        status: 400,
        data: {
          success: false,
          message: "📧 Please enter a valid email address",
        },
      };
    }

    if (!token) {
      return {
        status: 400,
        data: {
          success: false,
          message:
            "🤖 Oops! We need to verify you're not a bot. Quick captcha check?",
        },
      };
    }

    const filePath = "./signups";

    try {
      fs.appendFileSync(filePath, email + ",");

      // On success
      return {
        data: {
          success: true,
          message:
            "🚀 You're in! Get ready for some epic updates in your inbox",
        },
      };
    } catch (err) {
      console.error("Subscription error:", err);
      return {
        status: 500,
        data: {
          success: false,
          message: "💫 Houston, we had a glitch. Give it another shot?",
        },
      };
    }
  },
};
