import { RECAPTCHA_SECRET_KEY } from "$env/static/private";

/** @type {import('./$types').Actions} */
export const actions = {
  newsletter: async (event) => {
    const formData = await event.request.formData();
    const email = formData.get("email");
    const token = formData.get("g-recaptcha-response");

    if (!token) {
      return {
        success: false,
        message:
          "🤖 Oops! We need to verify you're not a bot. Quick captcha check?",
      };
    }

    const captchaRequest = {
      event: {
        secret: "${RECAPTCHA_SECRET_KEY}",
        response: token,
      },
    };

    try {
      const response = await fetch(
        `https://www.google.com/recaptcha/api/siteverify`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify(captchaRequest),
        },
      );

      const data = await response.json();

      if (!response.ok) {
        return {
          success: false,
          message: "⚠️ Yikes! reCAPTCHA had a hiccup. Mind trying again?",
        };
      }
      console.log("success");
      console.log(email);

      return {
        success: true,
        message: "🚀 You're in! Get ready for some epic updates in your inbox",
      };
    } catch (err) {
      console.error("Captcha verification error:", err);
      return {
        success: false,
        message: "💫 Houston, we had a glitch. Give it another shot?",
      };
    }
  },
};
