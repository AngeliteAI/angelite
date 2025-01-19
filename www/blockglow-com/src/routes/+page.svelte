<script>
    import { onMount } from "svelte";

    const rotation = ["light", "thought", "data", "code"];
    let currentIndex = 0;
    let isAnimating = false;
    function init() {
        const carousel = document.getElementById("hero-carousel");
        const current = document.getElementById("hero-carousel-current");
        const canvas = document.createElement("canvas");
        const context = canvas.getContext("2d");
        context.font = getComputedStyle(current).font;
        carousel.style.minWidth = `calc(${context.measureText(current.textContent).width}px + 2em)`;
    }

    onMount(() => {
        init();
        setInterval(() => {
            if (isAnimating) return;
            isAnimating = true;

            const nextIndex = (currentIndex + 1) % rotation.length;
            const carousel = document.getElementById("hero-carousel");
            const current = document.getElementById("hero-carousel-current");
            const next = document.getElementById("hero-carousel-next");

            // Set initial positions
            next.textContent = rotation[nextIndex];
            next.style.transform = "translateY(100%)";
            current.style.transform = "translateY(0)";

            const canvas = document.createElement("canvas");
            const context = canvas.getContext("2d");
            context.font = getComputedStyle(current).font;
            carousel.style.minWidth = `calc(${context.measureText(next.textContent).width}px + 2em)`;

            // Force reflow
            void next.offsetHeight;

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

                current.textContent = rotation[nextIndex];
                current.style.transform = "translateY(0)";
                next.style.transform = "translateY(100%)";

                currentIndex = nextIndex;
                isAnimating = false;
            }, 500);
        }, 5000);
    });
</script>

<main>
    <div id="hero">
        <h1>
            <span class="caps">Build</span> at the speed of
            <span id="hero-carousel">
                <span class="caps rainbow" id="hero-carousel-current"
                    >{rotation[0]}</span
                >
                <span class="caps rainbow" id="hero-carousel-next"
                    >{rotation[1]}</span
                >
            </span>
        </h1>
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
    .caps {
        text-transform: uppercase;
        font-weight: bold;
    }
    .rainbow {
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
    main {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
    }
    #hero {
        height: 500px;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
    }

    #hero-carousel {
        display: inline-block;
        position: relative;
        height: 1.2em;
        vertical-align: bottom;
        overflow: hidden;
        width: auto;
        transition: min-width 0.3s ease;
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
    }

    #hero-carousel-next {
        transform: translateY(100%);
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
