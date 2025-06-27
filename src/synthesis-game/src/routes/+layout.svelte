<script>
    import "../app.css";
    import GradientBackground from "$lib/components/GradientBackground.svelte";
    import { onMount } from "svelte";
    import { fade } from "svelte/transition";

    let { children } = $props();

    // For cursor effects
    let mounted = false;
    let mouseX = 0;
    let mouseY = 0;

    // Track cursor position
    function handleMouseMove(event) {
        mouseX = event.clientX;
        mouseY = event.clientY;

        const cursorGlow = document.querySelector(".cursor-glow");
        if (cursorGlow) {
            cursorGlow.style.left = `${mouseX}px`;
            cursorGlow.style.top = `${mouseY}px`;
            cursorGlow.style.opacity = "0.7";
        }
    }

    onMount(() => {
        mounted = true;
        document.addEventListener("mousemove", handleMouseMove);

        return () => {
            document.removeEventListener("mousemove", handleMouseMove);
        };
    });
</script>

<div class="app-container">
    <GradientBackground />

    {#if mounted}
        <div class="cursor-glow"></div>
    {/if}

    <main in:fade={{ duration: 800, delay: 400 }}>
        {@render children()}
    </main>
</div>

<style>
    .app-container {
        position: relative;
        min-height: 100vh;
        width: 100%;
        overflow-x: hidden;
    }

    main {
        position: relative;
        z-index: 1;
        width: 100%;
        min-height: 100vh;
    }

    /* Cursor glow effect */
    .cursor-glow {
        position: fixed;
        width: 300px;
        height: 300px;
        border-radius: 50%;
        pointer-events: none;
        background: radial-gradient(
            circle,
            rgba(99, 102, 241, 0.15) 0%,
            rgba(99, 102, 241, 0.05) 40%,
            transparent 70%
        );
        transform: translate(-50%, -50%);
        z-index: 100;
        opacity: 0;
        transition: opacity 0.5s ease;
        mix-blend-mode: screen;
    }

    @import url("https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&family=Merriweather:ital,opsz,wght@0,18..144,300..900;1,18..144,300..900&display=swap");

    :global(:root) {
        --scale-ratio: 1.25;
        --text-xs: 0.75rem;
        --text-sm: calc(var(--text-xs) * var(--scale-ratio));
        --text-base: calc(var(--text-sm) * var(--scale-ratio));
        --text-lg: calc(var(--text-base) * var(--scale-ratio));
        --text-xl: calc(var(--text-lg) * var(--scale-ratio));
        --text-2xl: calc(var(--text-xl) * var(--scale-ratio));
        --text-3xl: calc(var(--text-2xl) * var(--scale-ratio));
        --text-4xl: calc(var(--text-3xl) * var(--scale-ratio));

        --color-primary: rgba(99, 102, 241, 1);
        --color-primary-light: rgba(129, 140, 248, 1);
        --color-secondary: rgba(236, 72, 153, 1);
        --color-tertiary: rgba(34, 211, 238, 1);

        --transition-slow: 0.7s cubic-bezier(0.16, 1, 0.3, 1);
        --transition-medium: 0.5s cubic-bezier(0.16, 1, 0.3, 1);
        --transition-fast: 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }

    :global(h1),
    :global(h2),
    :global(h3) {
        font-family: "Merriweather", serif;
        letter-spacing: 0.015em;
        line-height: 1.2;
        font-weight: 700;
    }

    :global(h1) {
        font-size: var(--text-3xl);
        margin-bottom: 0.75em;
        font-weight: 800;
    }

    :global(h2) {
        font-size: var(--text-2xl);
        margin-bottom: 0.5em;
    }

    :global(h3) {
        font-size: var(--text-xl);
        margin-bottom: 0.5em;
    }

    :global(p) {
        font-family: "Inter", sans-serif;
        letter-spacing: -0.01em;
        line-height: 1.6;
        margin-bottom: 1em;
    }

    :global(body) {
        background-color: #181824;
        color: #fff;
        font-size: var(--text-base);
        overflow-x: hidden;
    }

    /* Enhance link styling */
    :global(a) {
        color: var(--color-primary-light);
        text-decoration: none;
        transition: all var(--transition-fast);
        position: relative;
    }

    :global(a:hover) {
        color: var(--color-primary);
    }

    :global(a:after) {
        content: "";
        position: absolute;
        width: 0;
        height: 1px;
        bottom: -1px;
        left: 0;
        background-color: var(--color-primary);
        transition: width var(--transition-fast);
    }

    :global(a:hover:after) {
        width: 100%;
    }

    /* Add subtle animations */
    :global(.fade-in) {
        opacity: 0;
        animation: fadeIn var(--transition-medium) forwards;
    }

    @keyframes fadeIn {
        from {
            opacity: 0;
            transform: translateY(10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }

    /* Add page transitions */
    :global(::selection) {
        background: rgba(99, 102, 241, 0.3);
        color: white;
    }

    :global(body) {
        overflow-x: hidden;
        transition: background-color 0.5s ease;
    }

    /* Scrollbar styling */
    :global(::-webkit-scrollbar) {
        width: 10px;
    }

    :global(::-webkit-scrollbar-track) {
        background: rgba(0, 0, 0, 0.3);
    }

    :global(::-webkit-scrollbar-thumb) {
        background: rgba(99, 102, 241, 0.5);
        border-radius: 5px;
    }

    :global(::-webkit-scrollbar-thumb:hover) {
        background: rgba(99, 102, 241, 0.7);
    }
</style>
