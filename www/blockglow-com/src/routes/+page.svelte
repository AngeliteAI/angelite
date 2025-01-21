<script>
    import { onDestroy, onMount } from "svelte";

    const rotation = [
        { prebold: "BUILD", middle_little: "your", postbold: "VISION 🚀" },
        { prebold: "SHIP", middle_little: "your", postbold: "CODE ⚡" },
        { prebold: "SCALE", middle_little: "your", postbold: "STACK 🛠" },
        { prebold: "LAUNCH", middle_little: "your", postbold: "MVP 🎯" },
        { prebold: "UNLOCK", middle_little: "your", postbold: "POTENTIAL 🔥" },
        { prebold: "POWER", middle_little: "your", postbold: "API 🔌" },
        { prebold: "SHAPE", middle_little: "the", postbold: "FUTURE 🌟" },
        { prebold: "DEPLOY", middle_little: "your", postbold: "DREAM 🚢" },
        { prebold: "REACH", middle_little: "your", postbold: "PEAK 📈" },
        { prebold: "FIND", middle_little: "your", postbold: "FLOW ⚡" },
        { prebold: "START", middle_little: "your", postbold: "JOURNEY 🛸" },
        { prebold: "CODE", middle_little: "the", postbold: "FUTURE 🏗" },
        { prebold: "REACH", middle_little: "the", postbold: "STARS 🌙" },
        { prebold: "PUSH", middle_little: "the", postbold: "LIMITS ⚔️" },
        { prebold: "LEAD", middle_little: "the", postbold: "CHANGE ↗️" },
    ];

    let currentIndex = 0;
    let isAnimating = false;

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

        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");
        if (!context) return;

        context.font = getComputedStyle(current).font;
        void document.getElementById("hero-carousel-" + type)?.offsetHeight;
        const width = context.measureText(current.textContent || "").width;
        const space = context.measureText(" ").width;
        carousel.style.minWidth = `calc(${width}px + 2 * ${space}px)`;
        rainbow.style.marginLeft = `${space}px`;
        middle.style.marginLeft = `${space}px`;
    }

    function init() {}

    onMount(() => {
        update("current", rotation[0]);
        const interval = setInterval(() => {
            if (isAnimating) return;
            isAnimating = true;

            var nextIndex = (currentIndex + 1) % rotation.length;
            while (Math.random() < 0.5) {
                nextIndex = (nextIndex + 1) % rotation.length;
            }
            const current = document.getElementById("hero-carousel-current");
            const next = document.getElementById("hero-carousel-next");

            // Set initial positions
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
                // Reset for next animation
                current.style.transition = "none";
                next.style.transition = "none";

                update("current", rotation[nextIndex]);
                current.style.transform = "translateY(0)";
                next.style.transform = "translateY(110%)";

                currentIndex = nextIndex;
                isAnimating = false;
            }, 500);
        }, 3600);
        onDestroy(() => {
            clearInterval(interval);
        });
    });
</script>

<header>
    <div id="logo" />
</header>
<main>
    <div id="hero">
        <h1>
            <span id="hero-carousel">
                <span id="hero-carousel-current">{rotation[0]}</span>
                <span id="hero-carousel-next">{rotation[1]}</span>
            </span>
        </h1>
        <h3>Build and ship your backend with real-time collaboration and AI</h3>
    </div>
</main>

<style>
    @font-face {
        src: url("/mont-heavy.otf");
        font-family: "Mont";
        font-weight: bold;
    }
    @font-face {
        src: url("/mont-light.otf");
        font-family: "Mont";
        font-weight: lighter;
    }
    :global(*) {
        font-family: "Mont", sans-serif;
        font-weight: lighter;
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        color: rgb(235, 250, 250);
        background-color: rgb(18, 18, 26);
    }
    :global(.caps) {
        text-transform: uppercase;
        font-weight: bold;
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
    header {
        margin-left: 0.5em;
        margin-right: 0.5em;
        margin-top: 0.25em;
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
    #hero {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        font-size: 1.5em;
        height: 90vh; /* More dramatic full-height approach */
        width: 100%;
        padding: 0 24px;
        text-align: center;
        gap: 1.5rem; /* Consistent spacing */
    }

    h1 {
        font-size: clamp(
            2.5rem,
            5vw,
            4.5rem
        ); /* Dynamic but controlled sizing */
        line-height: 1.05; /* Tighter line height for headlines */
        letter-spacing: -0.015em; /* Subtle letter spacing adjustment */
        max-width: 18ch; /* Control line length */
        margin: 0;
    }

    h5 {
        font-size: clamp(1rem, 1.8vw, 1.4rem);
        line-height: 1.4;
        letter-spacing: 0.01em;
        font-weight: 400;
        opacity: 0.9; /* Subtle hierarchy */
        max-width: 28ch;
    }

    #hero-carousel {
        display: inline-block;
        position: relative;
        height: 1.2em;
        vertical-align: bottom;
        overflow: hidden;
        width: auto;
        transition: min-width 0.3s ease;
        height: 1.05em; /* Match line height */
        margin: 0 0.1em; /* Subtle spacing */
    }

    @media (max-width: 600px) {
        h1 {
            font-size: clamp(2rem, 8vw, 2.5rem);
        }

        #hero {
            padding: 0 16px;
            gap: 1rem;
        }

        #hero-carousel {
            margin: 0.1em 0;
        }
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

    @media (max-width: 600px) {
        h1 {
            font-size: 1.8rem;
            white-space: normal;
        }

        #hero-carousel {
            display: block;
            margin: 0.2em 0;
        }
    }

    #hero-carousel-current {
        transform: translateY(0);
        overflow: visible;
    }

    #hero-carousel-next {
        transform: translateY(110%);
    }

    @keyframes move {
        0% {
            background-position: 0%;
        }
        100% {
            background-position: 200%;
        }
    }
</style>
