import { RECAPTCHA_SECRET_KEY } from "$env/static/private";
import { pool, preparedStatements } from "$lib/db.js";

/** @type {import('./$types').Actions} */
export const actions = {
  newsletter: async (event) => {
    const formData = await event.request.formData();
    const email = formData.get("email")?.toString().toLowerCase();
    const token = formData.get("g-recaptcha-response");

    // Input validation
    if (!email?.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      return {
        success: false,
        message: "📧 Please enter a valid email address",
      };
    }

    if (!token) {
      return {
        success: false,
        message:
          "🤖 Oops! We need to verify you're not a bot. Quick captcha check?",
      };
    }

    try {
      // Verify reCAPTCHA
      const captchaResponse = await fetch(
        `https://www.google.com/recaptcha/api/siteverify`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            secret: RECAPTCHA_SECRET_KEY,
            response: token,
          }),
        },
      );

      const captchaData = await captchaResponse.json();
      if (!captchaResponse.ok) {
        return {
          success: false,
          message: "⚠️ reCAPTCHA verification failed. Please try again.",
        };
      }

      // Store in database
      const result = await pool.query({
        ...preparedStatements.insertSubscriber,
        values: [email],
      });

      // Check if email was inserted (not a duplicate)
      if (result.rowCount === 0) {
        return {
          success: true,
          message: "✨ Welcome back! You're already on our list!",
        };
      }

      return {
        success: true,
        message: "🚀 You're in! Get ready for some epic updates in your inbox",
      };
    } catch (err) {
      console.error("Subscription error:", err);

      // Don't expose internal errors to users
      return {
        success: false,
        message: "💫 Houston, we had a glitch. Give it another shot?",
      };
    }
  },
};
