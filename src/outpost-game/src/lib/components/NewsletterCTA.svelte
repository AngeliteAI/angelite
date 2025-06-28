<script>
    import GlassPanel from "./GlassPanel.svelte";

    /**
     * Newsletter CTA component
     * Displays a compact call-to-action for newsletter signup with Google-style floating label
     */
    let email = "";
    let submitted = false;
    let focused = false;
    let loading = false;
    let error = "";

    // Handle form submission
    function handleSubmit() {
        error = "";
        if (!email) {
            error = "Please enter your email address";
            return;
        }
        if (!email.includes("@") || !email.includes(".")) {
            error = "Please enter a valid email address";
            return;
        }

        loading = true;
        // Simulate API call
        setTimeout(() => {
            loading = false;
            submitted = true;
            console.log("Newsletter signup:", email);
        }, 800);
    }
</script>

<GlassPanel
    as="aside"
    class="newsletter-cta h-16 flex items-center p-0 overflow-hidden border-l-2 border-l-indigo-400 w-full "
>
    {#if !submitted}
        <form
            on:submit|preventDefault={handleSubmit}
            class="flex w-full h-full items-center justify-between"
        >
            <div class="flex-grow pl-3 w-full">
                <div class="input-container relative w-full">
                    <input
                        type="email"
                        bind:value={email}
                        id="newsletter-email"
                        on:focus={() => (focused = true)}
                        on:blur={() => (focused = false)}
                        class="w-full bg-transparent border-b border-indigo-400/30 hover:border-indigo-400/60 focus:border-indigo-400 outline-none pt-4 pb-2 text-sm transition-colors"
                        placeholder={focused ? "your@email.com" : ""}
                        class:error-input={error}
                    />
                    <label
                        for="newsletter-email"
                        class="floating-label absolute left-0 transition-all duration-200 text-indigo-200 pointer-events-none font-serif"
                        class:float-up={focused || email}
                    >
                        {error || "Subscribe for updates"}
                    </label>
                </div>
            </div>

            <button
                type="submit"
                class="h-full px-6 bg-indigo-500/40 hover:bg-indigo-500/60
               transition-colors text-sm font-medium whitespace-nowrap relative overflow-hidden"
                disabled={loading}
            >
                {#if loading}
                    <span class="loading-dots">
                        <span>.</span><span>.</span><span>.</span>
                    </span>
                {:else}
                    Subscribe
                {/if}
            </button>
        </form>
    {:else}
        <div class="flex items-center justify-center w-full">
            <span class="text-sm mr-2 text-indigo-300">✓</span>
            <span class="text-sm text-indigo-100">Thanks for subscribing!</span>
            <button
                class="absolute right-3 top-1/2 transform -translate-y-1/2 text-xs opacity-50 hover:opacity-100 transition-opacity"
                on:click={() => {
                    submitted = false;
                    email = "";
                }}
            >
                Reset
            </button>
        </div>
    {/if}
</GlassPanel>

<style>
    /* Button hover effect */
    button[type="submit"] {
        position: relative;
        overflow: hidden;
        letter-spacing: 0.05em;
    }

    button[type="submit"]:hover:not(:disabled) {
        background-color: rgba(99, 102, 241, 0.7);
        box-shadow: 0 0 12px rgba(99, 102, 241, 0.5);
    }

    button[type="submit"]:disabled {
        opacity: 0.7;
        cursor: wait;
    }

    /* Google-style floating label */
    .input-container {
        min-height: 3rem;
    }

    .floating-label {
        font-family: "Merriweather", serif;
        font-size: 0.875rem;
        top: 50%;
        transform: translateY(-50%);
        transition: all 0.2s ease-out;
        font-weight: 500;
    }

    .float-up {
        top: 25%;
        font-size: 0.65rem;
        opacity: 0.9;
        color: rgba(99, 102, 241, 0.9);
        font-weight: bold;
        text-shadow: 0 0 2px rgba(0, 0, 0, 0.2);
    }

    ::placeholder {
        color: rgba(255, 255, 255, 0.4);
        font-style: italic;
        font-size: 0.8rem;
    }

    /* Add subtle glow effect to input on focus */
    input:focus {
        box-shadow: 0 1px 4px -2px rgba(99, 102, 241, 0.4);
    }

    .error-input {
        border-color: rgba(239, 68, 68, 0.7) !important;
    }

    label:has(+ .error-input) {
        color: rgba(239, 68, 68, 0.9) !important;
    }

    /* Loading animation */
    .loading-dots {
        display: inline-flex;
    }

    .loading-dots span {
        animation: loadingDots 1.4s infinite both;
        margin: 0 1px;
    }

    .loading-dots span:nth-child(2) {
        animation-delay: 0.2s;
    }

    .loading-dots span:nth-child(3) {
        animation-delay: 0.4s;
    }

    @keyframes loadingDots {
        0% {
            opacity: 0.2;
        }
        20% {
            opacity: 1;
        }
        100% {
            opacity: 0.2;
        }
    }
</style>
