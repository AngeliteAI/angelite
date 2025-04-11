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

    const phrases = [
        {
            prebold: "BUILD",
            middle: "your",
            postbold: "VISION",
            emoji: "🎯",
        },
        {
            prebold: "SHIP",
            middle: "your",
            postbold: "CODE",
            emoji: "⚡",
        },
        {
            prebold: "SCALE",
            middle: "your",
            postbold: "STACK",
            emoji: "🚀",
        },
        {
            prebold: "LAUNCH",
            middle: "your",
            postbold: "MVP",
            emoji: "🔮",
        },
        {
            prebold: "UNLOCK",
            middle: "your",
            postbold: "POTENTIAL",
            emoji: "🗝️",
        },
        {
            prebold: "POWER",
            middle: "your",
            postbold: "API",
            emoji: "⚙️",
        },
        {
            prebold: "SHAPE",
            middle: "the",
            postbold: "FUTURE",
            emoji: "🌟",
        },
        {
            prebold: "DEPLOY",
            middle: "your",
            postbold: "DREAM",
            emoji: "🛸",
        },
        {
            prebold: "REACH",
            middle: "your",
            postbold: "PEAK",
            emoji: "🏔️",
        },
        {
            prebold: "FIND",
            middle: "your",
            postbold: "FLOW",
            emoji: "💫",
        },
        {
            prebold: "START",
            middle: "your",
            postbold: "JOURNEY",
            emoji: "🧭",
        },
        {
            prebold: "CODE",
            middle: "the",
            postbold: "FUTURE",
            emoji: "💻",
        },
        {
            prebold: "REACH",
            middle: "the",
            postbold: "STARS",
            emoji: "✨",
        },
        {
            prebold: "PUSH",
            middle: "the",
            postbold: "LIMITS",
            emoji: "🔥",
        },
        {
            prebold: "LEAD",
            middle: "the",
            postbold: "CHANGE",
            emoji: "🌊",
        },
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
        {
            title: "Blog coming soon",
            image: "/blog.webp",
            desc: "",
            category: "Web3",
            readTime: "5 min read",
            gradient: "45deg, #FF6B6B, #4ECDC4",
        },
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
    let activeIndex = $state(1); // Start with middle card

    // Navigation functions
    function nextSlide() {
        if (activeIndex < blogPosts.length - 1) {
            activeIndex++;
        }
    }

    function prevSlide() {
        if (activeIndex > 0) {
            activeIndex--;
        }
    }

    // Card styling and interaction
    function getCardStyle(index) {
        const offset = index - activeIndex;
        const translateX = offset * 60;
        const translateZ = Math.abs(offset) * -100;
        const scale = Math.max(0.8, 1 - Math.abs(offset) * 0.2);
        const opacity = Math.max(0.5, 1 - Math.abs(offset) * 0.3);
        const rotation = offset * 5;

        return `
                transform: translateX(${translateX}%) translateZ(${translateZ}px)
                          scale(${scale}) rotate(${rotation}deg);
                opacity: ${opacity};
            `;
    }

    function handleCardInteraction(e, card) {
        const index = parseInt(card.dataset.index);
        if (index !== activeIndex) return;

        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const centerX = rect.width / 2;
        const centerY = rect.height / 2;

        const rotateX = ((y - centerY) / centerY) * -10;
        const rotateY = ((x - centerX) / centerX) * 10;

        card.style.transform = `
                ${getCardStyle(index)}
                rotateX(${rotateX}deg) rotateY(${rotateY}deg)
            `;
    }

    function resetCard(card) {
        const index = parseInt(card.dataset.index);
        card.style.transform = getCardStyle(index);
    }

    // Add keyboard navigation
    onMount(() => {
        const handleKeydown = (e) => {
            if (e.key === "ArrowLeft") prevSlide();
            if (e.key === "ArrowRight") nextSlide();
        };

        window.addEventListener("keydown", handleKeydown);
        return () => {
            window.removeEventListener("keydown", handleKeydown);
        };
    });

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
        middle.textContent = text.middle;
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

    let displayTextParts = $state({
        prebold: "",
        middle: "",
        postbold: "",
        emoji: "",
    });

    async function typeText() {
        while (true) {
            const phrase = phrases[currentIndex];
            const parts = {
                prebold: phrase.prebold,
                middle: phrase.middle,
                postbold: phrase.postbold,
                emoji: phrase.emoji,
            };

            // Type each part sequentially
            for (let i = 0; i <= parts.prebold.length; i++) {
                displayTextParts.prebold = parts.prebold.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 100));
            }

            for (let i = 0; i <= parts.middle.length; i++) {
                displayTextParts.middle = parts.middle.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 100));
            }

            for (let i = 0; i <= parts.postbold.length; i++) {
                displayTextParts.postbold = parts.postbold.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 100));
            }

            displayTextParts.emoji = parts.emoji; // Show emoji immediately after postbold

            await new Promise((resolve) => setTimeout(resolve, 2000));

            // Erase in reverse
            displayTextParts.emoji = ""; // Clear emoji first

            for (let i = parts.postbold.length; i >= 0; i--) {
                displayTextParts.postbold = parts.postbold.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 50));
            }

            for (let i = parts.middle.length; i >= 0; i--) {
                displayTextParts.middle = parts.middle.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 50));
            }

            for (let i = parts.prebold.length; i >= 0; i--) {
                displayTextParts.prebold = parts.prebold.substring(0, i);
                await new Promise((resolve) => setTimeout(resolve, 50));
            }

            currentIndex = (currentIndex + 1) % phrases.length;
        }
    }

    onMount(() => {
        typeText();
    });
    let timeoutId;

    onMount(() => {
        update("current", rotation[0]);

        if (heroCanvas) {
            //gridSystem = new Grid(heroCanvas);
            //gridSystem.animate();
        }

        // Start the carousel

        onDestroy(() => {
            if (timeoutId) clearTimeout(timeoutId);
            if (gridSystem) {
                window.removeEventListener("resize", gridSystem.resize);
            }
        });
    });

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
<header>
    <span>
        <div id="logo" />
        <div id="menu"></div>
    </span>
</header>

<!-- Hero Section with Bold Statement -->
<div
    class="relative min-h-[55vh] w-full flex flex-col items-center justify-start pt-32 px-6 space-y-16"
>
    <!-- Grid Background -->
    <div class="absolute inset-0 z-0">
        <canvas bind:this={heroCanvas} class="w-full h-150vh opacity-45" />
    </div>

    <!-- Hero Content -->
    <div class="w-full text-center space-y-4">
        <h1
            class="w-full text-center flex flex-col align-middle justify-center relative z-10 text-[clamp(2.5rem,5vw,4.5rem)] font-bold tracking-tight leading-normal min-h-[1.2em] flex items-center"
        >
            <span class="inline-flex items-center">
                <span class="font-bold">{displayTextParts.prebold}</span>
                {#if displayTextParts.middle}
                    <span class="ml-1">&nbsp;</span>
                {/if}
                <span class="font-normal">{displayTextParts.middle}</span>
                {#if displayTextParts.postbold}
                    <span class="ml-1">&nbsp;</span>
                {/if}
                <span class="font-bold rainbow"
                    >{displayTextParts.postbold}</span
                >
                {#if displayTextParts.emoji}
                    <span class="ml-1">&nbsp;</span>
                {/if}
                <span>{displayTextParts.emoji}</span>
                <span class="animate-blink ml-1 rainbow">|</span>
            </span>
        </h1>

        <h3 class="relative z-10 text-[clamp(1rem,1.8vw,1.4rem)] text-white/90">
            Build and ship visually, with or without code.<br /> AI-powered.
        </h3>
    </div>

    <!-- CTA Section -->
    {#if live}
        <div class="flex gap-4 z-10">
            <button class="btn btn-rainbow">Start Building</button>
            <button class="btn btn-dark">View Demo</button>
        </div>
    {:else}
        <!-- Newsletter Signup -->
        <div class="relative w-full max-w-md mx-auto">
            <form
                action="?/newsletter"
                id="newsletter"
                method="POST"
                use:enhance
                class="floating-input relative"
            >
                <div class="relative">
                    <input
                        type="email"
                        name="email"
                        id="newsletter-email"
                        placeholder=" "
                        required
                        class="w-full h-14 px-4 pt-6
                               bg-transparent
                               border-2 border-purple-600/30 rounded-xl
                               text-white
                               focus:border-purple-600 focus:outline-none
                               focus:ring-2 focus:ring-purple-600/20
                               transition-all duration-300 ease-out"
                    />
                    <label
                        for="newsletter-email"
                        class="absolute bg-black left-4 top-4
                               text-gray-400
                               transform origin-[0%_50%]
                               transition-all duration-300 ease-out
                               pointer-events-none"
                    >
                        Enter your email for updates
                    </label>
                    <button
                        class="absolute right-2 top-1/2 -translate-y-1/2
                               bg-purple-600 hover:bg-purple-700
                               w-9 h-9 rounded-lg
                               flex items-center justify-center
                               transition-colors duration-200"
                        data-sitekey="6Le_R8UqAAAAAL-GxbHI08tExy7NZXHtjJZGUK-O"
                        data-callback="onSubmit"
                        data-action="submit"
                    >
                        <svg viewBox="0 0 24 24" class="w-5 h-5 fill-white">
                            <path
                                d="M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8-8-8z"
                            />
                        </svg>
                    </button>
                </div>
            </form>
            {#if form?.data.message}
                <p>{form.data.message}</p>
            {/if}
        </div>
    {/if}
</div>

<!-- Feature Grid -->
<div
    class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 p-8 max-w-7xl mx-auto mt-16"
>
    {#each features as feature}
        <div
            class="bg-[rgba(18,18,26,0.95)] border border-white/10 rounded-xl p-8 transition-all duration-300 hover:-translate-y-1"
        >
            <div class="mb-4 text-2xl">{feature.icon}</div>
            <h4 class="text-xl font-bold mb-2">{feature.title}</h4>
            <p class="text-white/80">{feature.description}</p>

            {#if feature.metric}
                <div class="mt-4 flex items-baseline gap-2">
                    <span
                        class="font-bold bg-gradient-to-r from-[#4a90e2] to-[#9b51e0] bg-clip-text text-transparent"
                    >
                        {feature.metric}
                    </span>
                    <span class="text-white/80">{feature.metricLabel}</span>
                </div>
            {/if}

            {#if feature.code}
                <div
                    class="mt-4 p-4 bg-black/30 rounded-md font-mono text-zinc-200 border border-white/10"
                >
                    {feature.code}
                </div>
            {/if}
        </div>
    {/each}
</div>

<!-- Blog Post Carousel -->
<div class="relative w-full h-[600px] my-24 px-4 perspective-[2000px]">
    <div class="relative w-full max-w-6xl mx-auto h-full">
        {#each blogPosts as post, i}
            <div
                class="absolute w-full h-[500px] rounded-3xl overflow-hidden cursor-pointer
                       transition-all duration-700 ease-out border border-white/10
                       backdrop-blur-lg {i === activeIndex ? 'z-30' : 'z-10'}"
                style={getCardStyle(i)}
                on:mousemove={(e) => handleCardInteraction(e, e.currentTarget)}
                on:mouseleave={(e) => resetCard(e.currentTarget)}
                data-index={i}
            >
                <!-- Card Background Image with Gradient Overlay -->
                <div class="absolute inset-0">
                    <div
                        class="absolute inset-0 bg-gradient-to-b from-black/20 via-black/60 to-black/90 z-10"
                    />
                    <img
                        src={post.image}
                        alt={post.title}
                        class="w-full h-full object-cover"
                    />
                </div>

                <!-- Card Content -->
                <div class="relative z-20 h-full p-8 flex flex-col justify-end">
                    <div class="space-y-6">
                        <div class="flex items-center gap-4">
                            <span
                                class="px-4 py-1.5 bg-purple-500/20 text-purple-300 rounded-full text-sm font-medium"
                            >
                                {post.category}
                            </span>
                            <span class="text-zinc-400 text-sm">
                                {post.readTime}
                            </span>
                        </div>
                        <h3
                            class="text-4xl md:text-5xl font-bold text-white leading-tight"
                        >
                            {post.title}
                        </h3>
                        <p class="text-lg text-zinc-300 line-clamp-3">
                            {post.desc}
                        </p>
                    </div>
                </div>
            </div>
        {/each}
    </div>

    <!-- Navigation Buttons -->
    <button
        class="absolute left-8 top-1/2 -translate-y-1/2 z-1000 w-12 h-12 rounded-full
               bg-white/5 border border-white/10 flex items-center justify-center
               text-white transition-all hover:bg-white/10"
        on:click={() => prevSlide()}
    >
        ←
    </button>
    <button
        class="absolute right-8 top-1/2 -translate-y-1/2 z-1000 w-12 h-12 rounded-full
               bg-white/5 border border-white/10 flex items-center justify-center
               text-white transition-all hover:bg-white/10"
        on:click={() => nextSlide()}
    >
        →
    </button>
</div>

<footer>
    <p>Copyright Angeltech, Inc. (Blockglow) 2025</p>
</footer>

<style>
    .floating-input input {
        padding-bottom: calc(var(--spacing) * 6.5);
    }
    .floating-input input:focus ~ label,
    .floating-input input:not(:placeholder-shown) ~ label {
        padding-left: 0.5em;
        padding-right: 0.5em;
        transform: translateX(-0.25em) translateY(-1.6rem) scale(0.85);
        color: rgb(147, 51, 234);
    }

    .floating-input input::placeholder {
        color: transparent;
    }

    .floating-input input:focus::placeholder {
        color: rgb(156, 163, 175);
        transition-delay: 100ms;
    }

    .floating-input label {
        /* Ensure smooth animation from default position */
        transform-origin: 0 0;
        will-change: transform;
    }
</style>
