<script>
    import Grid from "$lib/grid";
    import { onDestroy, onMount } from "svelte";
    import { enhance } from "$app/forms";

    /** @type {import('./$types').PageProps} */
    let { data, form } = $props();

    let heroCanvas;
    let starField;
    var gridSystem;
    let currentIndex = 0;
    let isAnimating = false;
    let live = false;

    const rotation = [
        { prebold: "BUILD", middle_little: "your", postbold: "VISION 🚀" },
        { prebold: "SHIP", middle_little: "your", postbold: "CODE ⚡" },
        { prebold: "SCALE", middle_little: "your", postbold: "STACK 🛠" },
        { prebold: "LAUNCH", middle_little: "your", postbold: "MVP 🎯" },
        { prebold: "UNLOCK", middle_little: "your", postbold: "POTENTIAL 🔥" },
        { prebold: "POWER", middle_little: "your", postbold: "API 🔌" },
        { prebold: "SHAPE", middle_little: "the", postbold: "FUTURE 🌟" },
        { prebold: "DEPLOY", middle_little: "your", postbold: "DREAM 🚢" },
        { prebold: "REACH", middle_little: "your", postbold: "PEAK 🏔️" },
        { prebold: "FIND", middle_little: "your", postbold: "FLOW ⚡" },
        { prebold: "START", middle_little: "your", postbold: "JOURNEY 🛸" },
        { prebold: "CODE", middle_little: "the", postbold: "FUTURE 🏗" },
        { prebold: "REACH", middle_little: "the", postbold: "STARS 🌙" },
        { prebold: "PUSH", middle_little: "the", postbold: "LIMITS ⚔️" },
        { prebold: "LEAD", middle_little: "the", postbold: "CHANGE 🌊" },
    ];

    const blogPosts = [
        {
            title: "Blog coming soon",
            image: "/blog.webp",
            desc: "",
            category: "Web3",
            readTime: "5 min read",
            gradient: "45deg, #FF6B6B, #4ECDC4",
        },
    ];

    const features = [
        {
            icon: "🎨",
            title: "Visual Schema Design",
            description:
                "Design and understand your application's structure through an intuitive interface",
            metric: "5x",
            metricLabel: "Faster Iterations",
        },
        {
            icon: "⚡",
            title: "API Prototyping",
            description:
                "Test and refine your API design before writing any code",
            code: "// Preview generated endpoints\nGET /api/v1/users/:id/profile",
        },
        {
            icon: "🔐",
            title: "Permission Controls",
            description:
                "Define access patterns visually with built-in security checks",
            metric: "100%",
            metricLabel: "Policy Coverage",
        },
        {
            icon: "📦",
            title: "Easy Deployment",
            description: "Deploy your backend with powerful configuration",
            code: "blockglow deploy my_project",
        },
        {
            icon: "🔄",
            title: "Schema Versioning",
            description: "Track and manage schema changes over time",
            metric: "Full",
            metricLabel: "Change History",
        },
        {
            icon: "💡",
            title: "Smart Suggestions",
            description:
                "Receive contextual hints about potential optimizations",
            code: "Hint: Consider indexing frequently queried fields",
        },
    ];

    function handleFeatureHover(card) {
        card.style.transform = "translateY(-5px)";
    }

    function handleFeatureLeave(card) {
        card.style.transform = "translateY(0)";
    }

    const markdownParser = (text) => {
        // Process line by line
        return text
            .split("\n")
            .map((line) => {
                line = line.trim();
                // Process headers first
                if (line.startsWith("### ")) {
                    return `<h3>${line.slice(4)}</h3>`;
                }
                if (line.startsWith("## ")) {
                    return `<h2>${line.slice(3)}</h2>`;
                }
                if (line.startsWith("# ")) {
                    return `<h1>${line.slice(2)}</h1>`;
                }

                // Then process bold and italic
                return line
                    .replace(/\*\*(.+?)\*\*/g, "<b>$1</b>")
                    .replace(/\*(.+?)\*/g, "<i>$1</i>");
            })
            .join("<br>");
    };

    let borderAngle = 0;

    let borderAnimationFrames = new Map();

    function animateBorder(button) {
        if (button.disabled) {
            return;
        }

        borderAngle = (borderAngle + 0.1) % 360;
        button.style.borderImage = `linear-gradient(
            ${borderAngle}deg,
            blue,
            violet,
            indigo,
            blue
        ) 1`;

        const frameId = requestAnimationFrame(() => animateBorder(button));
        borderAnimationFrames.set(button, frameId);
    }

    function handleHover(e) {
        const button = e.currentTarget;
        if (button.disabled) {
            return;
        }
        button.style.borderWidth = "3px";
        button.style.padding = "calc(0.8em - 2px) calc(2em - 2px)"; // Compensate for border increase
        button.style.borderStyle = "solid";
        animateBorder(button);
    }

    function handleLeave(e) {
        const button = e.currentTarget;
        if (button.disabled) {
            return;
        }
        button.style.borderWidth = "1px";
        button.style.padding = "0.8em 2em"; // Reset to original padding
        button.style.borderStyle = "solid";
        button.style.borderImage = "none";
        button.style.borderColor = "rgba(255, 255, 255, 0.15)";

        const frameId = borderAnimationFrames.get(button);
        if (frameId) {
            cancelAnimationFrame(frameId);
            borderAnimationFrames.delete(button);
        }
    }
    let activeIndex = Math.floor(blogPosts.length / 2);

    function getCardStyle(index) {
        const offset = index - activeIndex;
        const translateX = offset * 60;
        const translateZ = Math.abs(offset) * -100;
        const scale = Math.max(0.8, 1 - Math.abs(offset) * 0.2);
        const opacity = Math.max(0.5, 1 - Math.abs(offset) * 0.3);
        const zIndex = 100 - Math.abs(offset);
        let rotation = offset * 5;

        return `
            transform: translateX(${translateX}%) translateZ(${translateZ}px)
                      scale(${scale}) rotate(${rotation}deg);
            z-index: ${zIndex};
        `;
    }

    function nextSlide() {
        if (activeIndex < blogPosts.length - 1) activeIndex++;
    }

    function prevSlide() {
        if (activeIndex > 0) activeIndex--;
    }

    function update(type, text) {
        const carousel = document.getElementById("hero-carousel");
        const current = document.getElementById("hero-carousel-" + type);
        if (!carousel || !current) return;

        if (current.firstChild) current.firstChild.remove();
        const span = document.createElement("span");
        const prebold = document.createElement("span");
        const middle = document.createElement("span");
        const rainbow = document.createElement("span");
        prebold.className = "caps";
        rainbow.className = "rainbow caps";
        prebold.textContent = text.prebold;
        middle.textContent = text.middle_little;
        span.appendChild(prebold);
        span.appendChild(middle);
        span.appendChild(rainbow);
        rainbow.textContent = text.postbold;
        current.appendChild(span);

        const tempCanvas = document.createElement("canvas");
        const context = tempCanvas.getContext("2d");
        if (!context) return;

        context.font = getComputedStyle(current).font;
        void document.getElementById("hero-carousel-" + type)?.offsetHeight;
        const width = context.measureText(current.textContent || "").width;
        const space = context.measureText(" ").width;
        carousel.style.minWidth = `calc(${width}px + 2 * ${space}px)`;
        rainbow.style.marginLeft = `${space}px`;
        middle.style.marginLeft = `${space}px`;
    }

    function handleButtonHover(event) {
        const button = event.currentTarget;
        if (button.disabled) {
            return;
        }
        const rect = button.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;

        // Update CSS custom properties for gradient position
        button.style.setProperty("--x", `${x}px`);
        button.style.setProperty("--y", `${y}px`);
    }

    let isLongInterval = false;

    function animateCarousel() {
        if (isAnimating) return;
        isAnimating = true;

        var nextIndex = (currentIndex + 1) % rotation.length;
        while (Math.random() < 0.5) {
            nextIndex = (nextIndex + 1) % rotation.length;
        }
        const current = document.getElementById("hero-carousel-current");
        const next = document.getElementById("hero-carousel-next");

        update("next", rotation[nextIndex]);
        next.style.transform = "translateY(110%)";
        current.style.transform = "translateY(0)";

        requestAnimationFrame(() => {
            next.style.transition =
                "transform 0.5s cubic-bezier(0.4, 0, 0.2, 1)";
            current.style.transition =
                "transform 0.5s cubic-bezier(0.4, 0, 0.2, 1)";
            current.style.transform = "translateY(-100%)";
            next.style.transform = "translateY(0)";
        });

        setTimeout(() => {
            current.style.transition = "none";
            next.style.transition = "none";
            update("current", rotation[nextIndex]);
            current.style.transform = "translateY(0)";
            next.style.transform = "translateY(110%)";
            currentIndex = nextIndex;
            isAnimating = false;

            // Schedule next animation with alternating duration
            const nextDuration = isLongInterval ? 3000 : 5000;
            isLongInterval = !isLongInterval;
            timeoutId = setTimeout(animateCarousel, nextDuration);
        }, 500);
    }

    let timeoutId;

    onMount(() => {
        update("current", rotation[0]);

        if (heroCanvas) {
            gridSystem = new Grid(heroCanvas);
            gridSystem.animate();
        }

        // Start the carousel
        timeoutId = setTimeout(animateCarousel, 2000);

        onDestroy(() => {
            if (timeoutId) clearTimeout(timeoutId);
            if (gridSystem) {
                window.removeEventListener("resize", gridSystem.resize);
            }
        });
    });

    function handleCardInteraction(e, card) {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        const rotateX = (y - centerY) / 20;
        const rotateY = (centerX - x) / 20;

        card.style.transform = `${getCardStyle(parseInt(card.dataset.index))}
            rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    }

    function resetCard(card) {
        card.style.transform = getCardStyle(parseInt(card.dataset.index));
    }

    function onSubmit(token) {
        document.getElementById("newsletter").submit();
    }

    onMount(() => {
        window.onSubmit = onSubmit;
    });
</script>

<svelte:head>
    <script
        src="https://www.google.com/recaptcha/enterprise.js?render=6Le_R8UqAAAAAL-GxbHI08tExy7NZXHtjJZGUK-O"
    ></script>
</svelte:head>
<div id="grid">
    <canvas
        bind:this={heroCanvas}
        style="position: absolute; top: 0; left: 0; width: 100%; height: 150vh !important; z-index: 0; opacity: 0.45;"
    />
</div>
<header>
    <span>
        <div id="logo" />
        <div id="menu"></div>
    </span>
</header>
<main>
    <div id="hero">
        <h1 style="position: relative; z-index: 1;">
            <span id="hero-carousel">
                <span id="hero-carousel-current" />
                <span id="hero-carousel-next" />
            </span>
        </h1>
        <h3 style="position: relative; z-index: 1;">
            Build and ship backends visually, with or without code. AI-powered.
        </h3>
        {#if live}
            <div class="hero-buttons">
                <button
                    on:mousemove={handleButtonHover}
                    class="btn btn-rainbow"
                >
                    <span>Start Building</span>
                </button>
                <button
                    class="btn btn-dark"
                    on:mouseenter={handleHover}
                    on:mouseleave={handleLeave}
                >
                    <span>View Demo</span>
                </button>
            </div>
        {:else}
            <div style="width: 100%; display: flex; justify-content: center;">
                <div class="float-input-container">
                    <form
                        action="?/newsletter"
                        id="newsletter"
                        method="POST"
                        use:enhance
                    >
                        <input
                            type="email"
                            class="float-input"
                            placeholder=" "
                            name="email"
                            id="newsletter-email"
                            required
                        />
                        <label for="newsletter-email" class="float-label">
                            Enter your email for updates
                        </label>
                        <button
                            class="submit-button g-recaptcha"
                            data-sitekey="6Le_R8UqAAAAAL-GxbHI08tExy7NZXHtjJZGUK-O"
                            data-callback="onSubmit"
                            data-action="submit"
                        >
                            <svg viewBox="0 0 24 24">
                                <path
                                    d="M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8-8-8z"
                                />
                            </svg>
                        </button>
                    </form>
                </div>
                {#if form?.data.message}
                    <p>{form.data.message}</p>
                {/if}
            </div>
            st
        {/if}

        <div class="features-grid">
            {#each features as feature}
                <div
                    class="feature-card"
                    on:mouseenter={(e) => handleFeatureHover(e.currentTarget)}
                    on:mouseleave={(e) => handleFeatureLeave(e.currentTarget)}
                >
                    <div class="feature-icon">{feature.icon}</div>
                    <h4>{feature.title}</h4>
                    <p>{feature.description}</p>
                    {#if feature.metric}
                        <div class="feature-metric">
                            <span class="metric-value">{feature.metric}</span>
                            <span class="metric-label"
                                >{feature.metricLabel}</span
                            >
                        </div>
                    {/if}
                    {#if feature.code}
                        <pre class="feature-code">{feature.code}</pre>
                    {/if}
                </div>
            {/each}
        </div>

        <div class="cards-carousel">
            <button class="nav-button prev" on:click={prevSlide}>←</button>
            <div class="cards-container">
                {#each blogPosts as post, i}
                    <div
                        class="card"
                        style={getCardStyle(i)}
                        class:active={i === activeIndex}
                        on:mousemove={(e) =>
                            handleCardInteraction(e, e.currentTarget)}
                        on:mouseleave={(e) => resetCard(e.currentTarget)}
                    >
                        <img
                            src={post.image}
                            alt={post.title}
                            class="card-background"
                        />
                        <div class="card-content">
                            <div class="card-meta">
                                <span class="category">{post.category}</span>
                                <span class="read-time">{post.readTime}</span>
                            </div>
                            <h3
                                class="title"
                                style="--gradient: {post.gradient}"
                            >
                                {post.title}
                            </h3>
                            {@html markdownParser(post.desc)}
                        </div>
                        <div class="card-footer">
                            <button class="read-more">Read More</button>
                        </div>
                    </div>
                {/each}
            </div>

            <button class="nav-button next" on:click={nextSlide}>→</button>
        </div>
    </div>
</main>
<footer>
    <p>Copyright Angeltech, Inc. (Blockglow) 2025</p>
</footer>

<style>
    @font-face {
        src: url("/MundialBold.ttf");
        font-family: "Mundial";
        font-weight: bold;
    }
    @font-face {
        src: url("/MundialHair.ttf");
        font-family: "Mundial";
        font-weight: lighter;
    }
    :global(*) {
        font-family: "Mundial", sans-serif;
        font-weight: lighter;
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        color: rgb(235, 250, 250);
    }
    :global(*) {
        /* Add smooth scrolling behavior globally */
        scroll-behavior: smooth;
    }

    :global(::-webkit-scrollbar) {
        width: 12px;
        height: 12px;
        background-color: rgba(18, 18, 26, 0.95);
    }

    :global(::-webkit-scrollbar-track) {
        background: rgba(18, 18, 26, 0.95);
        border-radius: 6px;
    }

    :global(::-webkit-scrollbar-thumb) {
        background: linear-gradient(
            180deg,
            rgba(147, 51, 234, 0.3) 0%,
            rgba(147, 51, 234, 0.5) 100%
        );
        border-radius: 6px;
        border: 3px solid rgba(18, 18, 26, 0.95);
        transition: background 0.2s ease;
    }
    #grid {
        position: relative;
        height: 300vh;
        width: 100%;
        overflow: hidden;
    }
    header,
    main {
        width: 100%;
        pointer-events: none;
        position: absolute;
    }
    :global(::-webkit-scrollbar-thumb:hover) {
        background: linear-gradient(
            180deg,
            rgba(147, 51, 234, 0.5) 0%,
            rgba(147, 51, 234, 0.7) 100%
        );
    }
    footer {
        padding-left: 2em;
    }

    /* Firefox scrollbar styles */
    :global(*) {
        scrollbar-width: thin;
        scrollbar-color: rgba(147, 51, 234, 0.5) rgba(18, 18, 26, 0.95);
    }
    :global(body) {
        background: black;
        overflow-x: hidden;
        position: relative;
    }
    :global(.caps) {
        text-transform: uppercase;
        font-weight: bold;
    }
    .float-input-container {
        pointer-events: auto;
        position: relative;
        margin: 24px 0;
        width: 100%;
        max-width: 420px;
    }

    .float-input-container input {
        background-color: transparent;
        backdrop-filter: blur(4px);
        color: white;
    }

    .float-input {
        width: 100%;
        height: 56px;
        padding: 20px 16px 0;
        border: 2px solid rgba(147, 51, 234, 0.3);
        border-radius: 12px;
        background: white;
        color: #333;
        transition: all 0.2s ease;
    }

    .float-label {
        position: absolute;
        left: 16px;
        top: 20px;
        color: #666;
        pointer-events: none;
        transition: all 0.2s ease;
    }

    .float-input:focus {
        border-color: #9333ea;
        box-shadow: 0 0 0 4px rgba(147, 51, 234, 0.1);
    }

    /* Key Fix: Proper label animation */
    .float-input:focus + .float-label,
    .float-input:not(:placeholder-shown) + .float-label {
        transform: translateY(-12px);
        color: #9333ea;
    }

    /* Hide placeholder initially */
    .float-input::placeholder {
        color: transparent;
    }

    /* Show placeholder only when focused */
    .float-input:focus::placeholder {
        color: #999;
    }

    .submit-button {
        position: absolute;
        right: 8px;
        top: 50%;
        transform: translateY(-50%);
        background: #9333ea;
        border: none;
        border-radius: 8px;
        width: 36px;
        height: 36px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.2s ease;
    }

    .submit-button:hover {
        background: #7928ca;
    }

    .submit-button svg {
        width: 20px;
        height: 20px;
        fill: white;
    }

    :global(.rainbow) {
        background-image: repeating-linear-gradient(
            to left,
            blue,
            violet,
            indigo,
            blue
        );
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-size: 200%;
        background-repeat: repeat;
        animation: move 100s infinite;
        animation-timing-function: linear;
        filter: contrast(60%) brightness(200%) blur(0.4px);
    }

    .btn:disabled {
        cursor: not-allowed;
        opacity: 0.6;
        transform: none !important;
        background: rgba(18, 18, 26, 0.5);
        box-shadow: none;
        border-color: rgba(255, 255, 255, 0.08);
        position: relative;
    }

    .btn:disabled span {
        color: rgba(255, 255, 255, 0.5);
    }

    .btn:disabled:hover {
        transform: none;
        box-shadow: none;
    }

    .btn-dark {
        background: rgba(18, 18, 26, 0.95);
        color: rgba(255, 255, 255, 0.9);
        border: 1px solid rgba(255, 255, 255, 0.15);
        /* Remove the inset box-shadow if it exists */
        box-shadow: none;
    }

    /* Override the general btn hover state for btn-dark specifically */
    .btn-dark:hover {
        transform: translateY(-1.2px);
        border-color: rgba(255, 255, 255, 0.25);
        /* Remove any inherited box-shadow */
        box-shadow: none;
    }

    /* Handle disabled state specifically for dark button */
    .btn-dark:disabled {
        transform: none !important;
        border-color: rgba(255, 255, 255, 0.08);
        background: rgba(18, 18, 26, 0.5);
    }

    /* Ensure the animated border doesn't add unexpected shadows */
    .btn-dark:not(:disabled) {
        border-style: solid;
        border-width: 1px;
    }

    /* Clean up the animated border handling */
    .btn-dark[style*="border-image"] {
        border-width: 3px;
        padding: calc(0.8em - 2px) calc(2em - 2px);
    }

    #sub-hero {
        width: 100%;
        position: relative;
    }

    .btn-rainbow:disabled::before {
        opacity: 0.15;
        background: radial-gradient(
            circle 800px at var(--x) var(--y),
            rgba(64, 64, 255, 0.2),
            rgba(128, 0, 255, 0.05),
            transparent
        );
    }

    .btn:disabled::after {
        content: "";
        position: absolute;
        inset: 0;
        background: repeating-linear-gradient(
            45deg,
            transparent,
            transparent 4px,
            rgba(255, 255, 255, 0.03) 4px,
            rgba(255, 255, 255, 0.03) 8px
        );
        border-radius: inherit;
        pointer-events: none;
    }

    :global(main) {
        position: absolute;
        top: 60px;
    }

    /* Override any hover/active states for disabled buttons */
    .btn:disabled:hover::before,
    .btn:disabled:active::before {
        opacity: 0.15;
    }

    .btn:disabled:hover {
        border-width: 0 !important;
        box-shadow: none;
        transform: translateY(0);
    }

    header {
        position: absolute;
        top: 0px;
        width: 100%;
        display: flex;
        justify-content: center;
        height: 60px;
    }

    header span {
        margin-left: 0.5em;
        margin-right: 0.5em;
        margin-top: 0.25em;
        width: 100%;
        max-width: 1118px;
        display: grid;
        grid-template-columns: 3em 1fr 3em;
    }

    header span #menu {
        grid-column: 0/1;
        display: flex;
        justify-content: center;
        align-items: center;
    }

    header span #menu a {
        margin-left: 1em;
        margin-right: 1em;
    }

    #logo {
        width: 3em;
        height: 3em;
        border: none;
        outline: none;
        background: url(/blockglow.png) no-repeat 0 0;
        background-size: 50%;
        background-position: center;
    }

    main {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
    }

    canvas {
        z-index: -10;
    }

    #hero {
        position: relative;
        top: 0; /* Changed from 60px */
        display: flex;
        flex-direction: column;
        justify-content: flex-start; /* Changed from center */
        align-items: center;
        min-height: 100vh;
        width: 100%;
        padding: 120px 24px 0; /* Added top padding to account for header */
        gap: 4rem; /* Increased from 1.5rem */
        overflow: visible;
    }

    /* Add to existing styles */
    .hero-buttons {
        display: flex;
        gap: 1rem;
        margin-top: 1rem;
        z-index: 1;
    }

    .btn-rainbow span {
        position: relative;
        z-index: 1;
    }

    /* Core button styles */
    .btn {
        padding: 0.8em 2em;
        border-radius: 4px; /* Much boxier */
        cursor: pointer;
        font-weight: 500;
        letter-spacing: 0.02em;
        transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
        position: relative;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.1);
    }

    /* Rainbow button */
    .btn-rainbow {
        background: rgba(18, 18, 26, 0.95);
        color: white;
        border: none;
    }

    .btn-rainbow::before {
        content: "";
        position: absolute;
        inset: 0;
        background: radial-gradient(
            circle 800px at var(--x) var(--y),
            rgba(64, 64, 255, 0.5),
            rgba(128, 0, 255, 0.15),
            transparent
        );
        opacity: 0;
        transition: opacity 0.2s;
    }

    /* Dark button */
    .btn-dark {
        background: rgba(18, 18, 26, 0.95);
        color: rgba(255, 255, 255, 0.9);
        border: 1px solid rgba(255, 255, 255, 0.15);
    }

    /* Cards */
    .card {
        min-height: 50em;
        border-radius: 4px;
        background: rgba(18, 18, 26, 0.98);
        border: 1px solid rgba(255, 255, 255, 0.08);
        box-shadow:
            0 4px 12px rgba(0, 0, 0, 0.5),
            0 1px 3px rgba(0, 0, 0, 0.25);
    }

    .category {
        border-radius: 2px;
        padding: 0.4em 0.8em;
        letter-spacing: 0.03em;
        background: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.1);
    }

    /* Navigation */
    .nav-button {
        width: 40px;
        height: 40px;
        border-radius: 4px;
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.08);
    }

    /* Extra polish */
    @supports (-webkit-backdrop-filter: none) or (backdrop-filter: none) {
        .btn,
        .card,
        .category {
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
        }
    }

    /* Refined hover states */
    .btn:hover {
        transform: translateY(-1.2px);
        box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.2);
    }

    .btn:active {
        box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.15);
    }

    .btn-rainbow:hover::before {
        opacity: 1;
    }

    .btn span {
        position: relative;
        z-index: 1;
    }

    @media (max-width: 640px) {
        .hero-buttons {
            flex-direction: column;
            width: 100%;
            padding: 0 1rem;
        }

        .btn {
            width: 100%;
            text-align: center;
        }
    }

    #hero h1,
    #hero h3 {
        position: relative;
        z-index: 1;
        pointer-events: none;
    }

    #hero-carousel,
    #hero-carousel span {
        pointer-events: none;
    }

    h1 {
        line-height: 1.05;
        letter-spacing: -0.015em;
        margin: 0;
    }

    h3 {
        line-height: 1.4;
        letter-spacing: 0.01em;
        font-weight: 400;
        opacity: 0.9;
    }

    #hero-carousel {
        display: inline-block;
        position: relative;
        height: 1.2em;
        vertical-align: bottom;
        overflow: hidden;
        width: auto;
        transition: min-width 0.3s ease;
        height: 1.05em;
        margin: 0 0.1em;
        background: transparent;
    }

    #hero-carousel span {
        position: absolute;
        left: 0;
        width: 100%;
        transition: none;
        backface-visibility: hidden;
        will-change: transform;
        white-space: nowrap;
        display: block;
        text-align: left;
    }

    #hero-carousel-current {
        transform: translateY(0);
        overflow: visible;
        background: transparent;
    }

    #hero-carousel-next {
        transform: translateY(110%);
        background: transparent;
    }

    .cards-carousel {
        pointer-events: none;
        width: 100vw;
        height: 600px; /* Fixed height instead of 70vh */
        position: relative;
        display: flex;
        justify-content: center;
        align-items: center;
        perspective: 2000px;
        margin-top: 2rem;
        margin-bottom: 4rem; /* Added bottom margin */
        overflow: visible;
    }

    .cards-container {
        position: relative;
        width: 100%;
        max-width: 1200px;
        height: 100%;
        transform-style: preserve-3d;
        padding: 2rem 0; /* Added padding */
    }

    .card {
        pointer-events: auto;
        position: absolute;
        width: 100%;
        max-width: 1200px;
        height: 500px; /* Fixed height */
        border-radius: 24px;
        overflow: hidden;
        transform-style: preserve-3d;
        transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
        background: rgba(18, 18, 26, 0.95);
        backdrop-filter: blur(10px);
        top: 0;
        position: absolute;
    }

    .card img {
        top: 0;
        position: absolute;
        height: 200px;
        object-fit: cover;
    }

    .card-background {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        object-fit: cover;
        transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
        opacity: 0.7;
        transform: scale(1.1);
        filter: blur(8px);
        will-change: transform, filter;
    }

    /* Update the hover state */
    .card:hover .card-background {
        transform: scale(1.15);
        filter: blur(0);
        opacity: 0.9;
    }

    /* Update card-content gradient for better visibility */
    .card-content {
        position: relative;
        height: 100%;
        padding: 2.5em;
        display: grid;
        grid-template-rows: auto auto 1fr auto;
        gap: 1.5em;
        background: linear-gradient(
            180deg,
            rgba(18, 18, 26, 0.4) 0%,
            rgba(18, 18, 26, 0.98) 35%
        );
        transform: translateZ(1px);
        z-index: 1;
    }

    .card {
        /* ... existing card styles ... */
        transform-style: preserve-3d;
        transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
        background: rgba(18, 18, 26, 0.95);
    }

    .card-meta {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .category {
        padding: 0.5em 1em;
        background: rgba(255, 255, 255, 0.1);
        border-radius: 20px;
        backdrop-filter: blur(5px);
        color: rgba(255, 255, 255, 0.9);
    }

    .read-time {
        color: rgba(255, 255, 255, 0.6);
    }

    .card .title {
        font-weight: bold;
        margin: 0;
        background: linear-gradient(var(--gradient));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        transform: translateZ(30px);
        transition: transform 0.3s ease;
        line-height: 1.2 !important;
    }

    .card p,
    .card-content :global(p),
    .card-content :global(h3) {
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.8);
        margin: 0;
        transform: translateZ(20px);
        max-height: 100%;
        overflow: hidden;
    }

    .card-content h3 {
        min-height: 1.6em;
    }

    .card-content {
        position: relative;
        height: 100%;
        padding: 2.5em;
        display: grid;
        grid-template-rows: auto auto 1fr auto;
        gap: 1.5em;
        background: linear-gradient(
            180deg,
            rgba(18, 18, 26, 0.4) 0%,
            rgba(18, 18, 26, 0.98) 35%
        );
        transform: translateZ(1px);
        z-index: 1;
    }
    /* Add the mask for text fade */
    .card-content {
        /* ... existing styles ... */

        /* Update mask gradient to stop before the footer */
        -webkit-mask-image: linear-gradient(
            to bottom,
            black 30%,
            black 80%,
            /* Maintain full opacity longer */ transparent 90%
        );
        mask-image: linear-gradient(
            to bottom,
            black 30%,
            black 80%,
            /* Maintain full opacity longer */ transparent 90%
        );
    }

    /* Add specific override for the card footer to ensure it's always visible */
    .card-footer {
        position: absolute;
        left: 2.5em;
        bottom: 2.5em;
        /* ... existing styles ... */
        -webkit-mask-image: none; /* Remove mask from footer */
        mask-image: none; /* Remove mask from footer */
        margin-top: auto; /* Push to bottom */
        padding-top: 1em; /* Add some spacing from content */
    }
    /* Ensure markdown content inherits styles */
    .card-content :global(*) {
        line-height: 1.6;
    }
    .card-footer {
        display: flex;
        justify-content: flex-start;
        align-items: center;
        transform: translateZ(25px);
    }

    .read-more {
        padding: 0.8em 1.6em;
        background: rgba(255, 255, 255, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.2);
        border-radius: 24px;
        color: white;
        cursor: pointer;
        transition: all 0.3s ease;
        backdrop-filter: blur(5px);
    }

    .card-content {
        position: relative;
        height: 100%;
        padding: 2.5em;
        display: flex;
        flex-direction: column;
        background: linear-gradient(
            180deg,
            rgba(18, 18, 26, 0.4) 0%,
            rgba(18, 18, 26, 0.98) 35%
        );
        transform: translateZ(1px);
        z-index: 1;
    }

    /* Add mask only to the text content */
    .card-content > p,
    .card-content :global(p),
    .card-content :global(h2),
    .card-content :global(h3) {
        -webkit-mask-image: linear-gradient(
            to bottom,
            black 0%,
            black 70%,
            transparent 100%
        );
        mask-image: linear-gradient(
            to bottom,
            black 0%,
            black 70%,
            transparent 100%
        );
    }

    /* Ensure footer stays visible */
    .card-footer {
        margin-top: auto;
        z-index: 2;
        -webkit-mask-image: none;
        mask-image: none;
    }

    .read-more:hover {
        background: rgba(255, 255, 255, 0.2);
        transform: translateY(-2px);
    }

    .card.active {
        z-index: 5;
    }
    .card:not(.active) {
        filter: blur(5px);
    }

    .nav-button {
        pointer-events: all;
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        width: 50px;
        height: 50px;
        border-radius: 25px;
        background: rgba(255, 255, 255, 0.1);
        border: 1px solid rgba(255, 255, 255, 0.2);
        color: white;
        cursor: pointer;
        backdrop-filter: blur(5px);
        transition: all 0.3s ease;
        z-index: 10;
    }

    .nav-button:hover {
        background: rgba(255, 255, 255, 0.2);
        transform: translateY(-50%) scale(1.1);
    }

    .nav-button.prev {
        left: 2em;
    }
    .nav-button.next {
        right: 2em;
    }

    @media (max-width: 768px) {
        .card {
            max-width: 90%;
        }

        .card h3 {
        }

        .nav-button {
            width: 40px;
            height: 40px;
        }

        .nav-button.prev {
            left: 1em;
        }
        .nav-button.next {
            right: 1em;
        }
    }

    .features-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 2rem;
        padding: 2rem;
        max-width: 1200px;
        width: 100%;
        margin: 2rem auto 4rem; /* Added margin */
        z-index: 100;
        pointer-events: none;
    }

    .feature-card {
        background: rgba(18, 18, 26, 0.95);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 2rem;
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        pointer-events: all;
    }

    .feature-icon {
        margin-bottom: 1rem;
    }

    .feature-metric {
        margin-top: 1rem;
        display: flex;
        align-items: baseline;
        gap: 0.5rem;
    }

    .metric-value {
        font-weight: bold;
        background: linear-gradient(45deg, #4a90e2, #9b51e0);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    .feature-code {
        margin-top: 1rem;
        padding: 1rem;
        background: rgba(0, 0, 0, 0.3);
        border-radius: 6px;
        font-family: "JetBrains Mono", "Fira Code", monospace;
        white-space: pre-wrap; /* Preserve whitespace but wrap */
        word-wrap: break-word; /* Break long words */
        max-width: 100%; /* Prevent overflow */
        color: #e4e4e7; /* Light gray for better readability */
        border: 1px solid rgba(255, 255, 255, 0.1);
    }
    @keyframes move {
        0% {
            background-position: 0%;
        }
        100% {
            background-position: 200%;
        }
    }

    /* Base Typography System */
    :root {
        --font-scale: 1.25; /* Major third type scale */
        --base-size: 1rem;
        --text-color: rgb(235, 250, 250);
        --text-color-muted: rgba(235, 250, 250, 0.8);
    }

    /* Typography Scale */
    h1,
    :global(h1) {
        font-size: calc(
            var(--base-size) * var(--font-scale) * var(--font-scale) *
                var(--font-scale) * var(--font-scale)
        );
        line-height: 1.1;
        font-weight: bold;
        letter-spacing: -0.015em;
        margin: 2rem 0 1rem;
    }

    h2,
    :global(h2) {
        font-size: calc(
            var(--base-size) * var(--font-scale) * var(--font-scale) *
                var(--font-scale)
        );
        line-height: 1.2;
        font-weight: bold;
        letter-spacing: -0.01em;
        margin: 1.75rem 0 0.875rem;
    }

    h3,
    :global(h3) {
        font-size: calc(
            var(--base-size) * var(--font-scale) * var(--font-scale)
        );
        line-height: 1.3;
        font-weight: bold;
        margin: 1.5rem 0 0.75rem;
    }

    h4,
    :global(h4) {
        font-size: calc(var(--base-size) * var(--font-scale));
        line-height: 1.4;
        font-weight: bold;
        margin: 1.25rem 0 0.625rem;
    }

    h5,
    :global(h5) {
        font-size: var(--base-size);
        line-height: 1.5;
        font-weight: bold;
        margin: 1rem 0 0.5rem;
    }

    h6,
    :global(h6) {
        font-size: calc(var(--base-size) / var(--font-scale));
        line-height: 1.5;
        font-weight: bold;
        margin: 0.875rem 0 0.4375rem;
    }

    /* Paragraph Styles */
    p,
    :global(p) {
        font-size: var(--base-size);
        line-height: 1.6;
        margin: 0 0 1rem;
        color: var(--text-color-muted);
    }

    /* Responsive Adjustments */
    @media (max-width: 768px) {
        :root {
            --base-size: 0.9rem;
            --font-scale: 1.2;
        }
    }

    @media (max-width: 480px) {
        :root {
            --base-size: 0.85rem;
            --font-scale: 1.15;
        }
    }

    /* Custom Hero Typography */
    #hero h1 {
        font-size: clamp(2.5rem, 5vw, 4.5rem);
        margin: 0;
    }

    #hero h3 {
        font-size: clamp(1rem, 1.8vw, 1.4rem);
        opacity: 0.9;
        margin: 0;
    }

    /* Card Typography Overrides */
    .card .title {
        font-size: 2.4em;
        margin: 0;
        background: linear-gradient(var(--gradient));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        transform: translateZ(30px);
        transition: transform 0.3s ease;
        line-height: 1.2;
    }

    .card-content > p,
    .card-content :global(p),
    .card-content :global(h2),
    .card-content :global(h3) {
        font-size: 1.3em;
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.8);
        margin: 0;
        transform: translateZ(20px);
    }
    .cards-carousel {
        width: 100%;
        height: 400px;
        margin: 3rem auto;
        padding: 0 1rem;
        position: relative;
    }

    .cards-container {
        position: relative;
        width: 100%;
        max-width: 600px;
        margin: 0 auto;
        height: 100%;
    }

    .card {
        width: 100%;
        height: 350px;
        position: absolute;
        border-radius: 12px;
        background: rgb(18, 18, 26);
        overflow: hidden;
        cursor: pointer;
    }

    /* Extra large typography */
    .card .title {
        font-size: 3.5rem; /* Much bigger */
        line-height: 1.1;
        margin-bottom: 1rem;
        font-weight: bold;
        color: white;
    }

    .card-content {
        padding: 2rem;
        height: 100%;
        background: rgb(18, 18, 26);
    }

    .card-content p,
    .card-content :global(p) {
        font-size: 1.8rem; /* Much bigger body text */
        line-height: 1.3;
        color: rgba(255, 255, 255, 0.9);
    }

    /* Simplified metadata */
    .card-meta {
        margin-bottom: 1rem;
        display: flex;
        gap: 1rem;
    }

    .category {
        font-size: 1.4rem;
        font-weight: bold;
        color: #9333ea;
    }

    .read-time {
        font-size: 1.4rem;
        color: rgba(255, 255, 255, 0.7);
    }

    /* Simple card states */
    .card:not(.active) {
        opacity: 0.3;
        transform: scale(0.9);
        pointer-events: none;
    }

    .card.active {
        opacity: 1;
        transform: scale(1);
    }

    /* Simple navigation */
    .nav-button {
        width: 50px;
        height: 50px;
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        background: rgb(30, 30, 40);
        border: none;
        border-radius: 25px;
        color: white;
        font-size: 1.5rem;
        cursor: pointer;
        z-index: 20;
    }

    .nav-button.prev {
        left: 1rem;
    }
    .nav-button.next {
        right: 1rem;
    }

    :global(.grecaptcha-badge) {
        display: none !important;
    }

    /* Basic responsive adjustments */
    @media (max-width: 768px) {
        .card .title {
            font-size: 2.8rem;
        }

        .card-content p,
        .card-content :global(p) {
            font-size: 1.6rem;
        }

        .category,
        .read-time {
            font-size: 1.2rem;
        }
    }

    .cards-carousel {
        width: 100%;
        height: 500px;
        margin: 4rem auto;
        padding: 0 1rem;
        position: relative;
        perspective: 2000px;
    }

    .cards-container {
        position: relative;
        width: 100%;
        max-width: 800px;
        margin: 0 auto;
        height: 100%;
        transform-style: preserve-3d;
    }

    .card {
        width: 100%;
        height: 450px;
        position: absolute;
        border-radius: 24px;
        background: rgba(18, 18, 26, 0.98);
        overflow: hidden;
        cursor: pointer;
        transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
        border: 1px solid rgba(255, 255, 255, 0.1);
    }

    /* MASSIVE typography with gradient effects */
    .card .title {
        font-size: 4.5rem; /* Huge title */
        line-height: 1;
        margin-bottom: 1rem;
        font-weight: 800;
        background: linear-gradient(
            135deg,
            #fff 0%,
            rgba(255, 255, 255, 0.85) 100%
        );
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        text-shadow: 0 0 30px rgba(255, 255, 255, 0.1);
    }

    .card-content {
        padding: 2.5rem;
        height: 100%;
        background: linear-gradient(
            180deg,
            rgba(18, 18, 26, 0.8) 0%,
            rgba(18, 18, 26, 0.98) 100%
        );
        backdrop-filter: blur(10px);
        display: flex;
        flex-direction: column;
    }

    .card-content p,
    .card-content :global(p) {
        font-size: 2.2rem; /* Very large body text */
        line-height: 1.2;
        color: rgba(255, 255, 255, 0.9);
        margin: 0;
    }

    /* Sexy metadata styling */
    .card-meta {
        margin-bottom: 1.5rem;
        display: flex;
        gap: 1.5rem;
        align-items: center;
    }

    .category {
        font-size: 1.6rem;
        font-weight: bold;
        background: linear-gradient(135deg, #9333ea 0%, #4f46e5 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    .read-time {
        font-size: 1.6rem;
        color: rgba(255, 255, 255, 0.7);
    }

    /* Dramatic card states */
    .card:not(.active) {
        opacity: 0.15;
        transform: scale(0.85) translateZ(-400px);
        filter: brightness(0.5);
    }

    .card.active {
        opacity: 1;
        transform: translateZ(0);
        box-shadow:
            0 20px 40px rgba(0, 0, 0, 0.4),
            0 0 100px rgba(147, 51, 234, 0.1);
    }

    .card.active:hover {
        transform: translateY(-10px) translateZ(0);
        box-shadow:
            0 30px 60px rgba(0, 0, 0, 0.5),
            0 0 120px rgba(147, 51, 234, 0.2);
    }

    /* Stylish navigation */
    .nav-button {
        width: 60px;
        height: 60px;
        position: absolute;
        top: 50%;
        transform: translateY(-50%);
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 30px;
        color: white;
        font-size: 1.8rem;
        cursor: pointer;
        z-index: 20;
        backdrop-filter: blur(10px);
        transition: all 0.3s ease;
    }

    .nav-button:hover {
        background: rgba(255, 255, 255, 0.1);
        border-color: rgba(255, 255, 255, 0.2);
        transform: translateY(-50%) scale(1.1);
    }

    .nav-button.prev {
        left: 2rem;
    }
    .nav-button.next {
        right: 2rem;
    }

    /* Card background effect */
    .card::before {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: linear-gradient(
            135deg,
            rgba(147, 51, 234, 0.1) 0%,
            rgba(79, 70, 229, 0.1) 100%
        );
        opacity: 0;
        transition: opacity 0.6s ease;
    }

    .card.active:hover::before {
        opacity: 1;
    }

    @media (max-width: 768px) {
        .card .title {
            font-size: 3.5rem;
        }

        .card-content p,
        .card-content :global(p) {
            font-size: 1.8rem;
        }
    }
</style>
