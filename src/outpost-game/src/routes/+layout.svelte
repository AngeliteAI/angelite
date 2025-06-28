<script context="module">
    // For staggered animations
    let articleDelay = 0;
    export function getStaggerDelay() {
        articleDelay += 150;
        return articleDelay;
    }
</script>

<script>
    import "../app.css";
    import GradientBackground from "$lib/components/GradientBackground.svelte";
    import NewspaperGrid from "$lib/components/NewspaperGrid.svelte";

    // Theme support
    import { writable } from "svelte/store";
    export const theme = writable("dark");

    import { onMount } from "svelte";
    import { fly, fade } from "svelte/transition";
    import { cubicOut } from "svelte/easing";

    // For micro-interactions
    let mounted = false;

    // The single array of items (articles and tweets) we'll use
    const items = [
        {
            title: "Outpost Discovery",
            content:
                "# Outpost Discovery\n\nLorem ipsum dolor sit amet, **consectetur adipiscing elit**. Nullam in dui mauris. Vivamus hendrerit arcu sed erat molestie vehicula.\n\n* First discovery point\n* Second discovery point\n* Third discovery point\n\nSed auctor neque eu tellus rhoncus ut eleifend nibh porttitor.",
            image: "https://picsum.photos/id/1/600/400",
            size: { cols: 3, rows: 3 },
            priority: 1, // Hero article
            type: "article",
        },
        {
            title: "Space Exploration",
            content:
                "## Space Exploration\n\nPraesent commodo cursus magna, vel *scelerisque nisl consectetur* et. Cras mattis consectetur purus sit amet fermentum.\n\n> The vastness of space beckons us to explore beyond our boundaries.",
            image: "https://picsum.photos/id/2/600/400",
            size: { cols: 1, rows: 1 },
            priority: 3,
            type: "article",
        },
        {
            content: "🚀 Just deployed the new **resource management system**! Colony efficiency up 47% 📈\n\nThe automation is working better than expected. #OutpostZero #GameDev",
            author: {
                name: "Outpost Team",
                handle: "@outpostgame",
                avatar: "https://picsum.photos/id/10/40/40"
            },
            metrics: {
                likes: 234,
                retweets: 67,
                replies: 12
            },
            timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
            size: { cols: 1, rows: 1 },
            priority: 3,
            type: "tweet",
        },
        {
            title: "New Alien Species",
            content:
                "### New Alien Species\n\nFusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus.\n\n1. Species Alpha - Discovered in sector 7\n2. Species Beta - Discovered in sector 12\n3. Species Gamma - Discovered in sector 15\n\nCum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.",
            image: "https://picsum.photos/id/3/600/400",
            size: { cols: 3, rows: 1 },
            priority: 2,
            type: "article",
        },
        {
            title: "Technology Advances",
            content:
                "#### Technology Advances\n\nMaecenas sed diam eget risus varius blandit sit amet non magna.\n\n```\nnew TechModule() {\n  initialize();\n  deploy();\n}\n```\n\nDonec ullamcorper nulla non metus auctor fringilla. Nullam quis risus eget urna mollis ornare vel eu leo.",
            image: "https://picsum.photos/id/4/600/400",
            size: { cols: 1, rows: 2 },
            priority: 2,
            type: "article",
        },
        {
            content: "Working late on the **atmospheric processor** 🌙 \n\nThe oxygen levels are finally stabilizing. Tomorrow we test the new filtration system! 🔬",
            image: "https://picsum.photos/id/20/600/300",
            author: {
                name: "Sarah Chen",
                handle: "@sarahc_dev",
                avatar: "https://picsum.photos/id/15/40/40"
            },
            metrics: {
                likes: 89,
                retweets: 23,
                replies: 7
            },
            timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(), // 5 hours ago
            size: { cols: 2, rows: 1 },
            priority: 2,
            type: "tweet",
        },
        {
            title: "Colony Updates",
            content:
                "## Colony Updates\n\n**Etiam porta sem** malesuada magna mollis euismod. Aenean lacinia bibendum nulla sed consectetur.\n\n---\n\nLatest update: Colony expansion phase 3 completed successfully. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.",
            image: "https://picsum.photos/id/5/600/400",
            size: { cols: 2, rows: 1 },
            priority: 2,
            type: "article",
        },
        {
            title: "Resource Management",
            content:
                "### Resource Management\n\nInteger posuere erat a ante venenatis dapibus posuere velit aliquet.\n\n| Resource | Status | Location |\n|----------|--------|----------|\n| Minerals | 78% | Sector 4 |\n| Water | 92% | Sector 7 |\n| Oxygen | 65% | Sector 2 |\n\nDonec sed odio dui. Cras justo odio, dapibus ac facilisis in, egestas eget quam.",
            image: "https://picsum.photos/id/6/600/400",
            size: { cols: 1, rows: 1 },
            priority: 3,
            type: "article",
        },
        {
            content: "❄️ **Cryogenic storage** systems are online! \n\nWe can now preserve biological samples for extended research periods. The future of xenobiology looks bright! ✨ #Science",
            author: {
                name: "Dr. Marcus Webb",
                handle: "@dr_webb",
                avatar: "https://picsum.photos/id/25/40/40"
            },
            metrics: {
                likes: 156,
                retweets: 34,
                replies: 9
            },
            timestamp: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(), // 8 hours ago
            size: { cols: 1, rows: 1 },
            priority: 3,
            type: "tweet",
        },
        {
            title: "Mission Briefing",
            content:
                "## Mission Briefing\n\n**Objective**: Vestibulum id ligula porta felis euismod semper.\n\n* Primary goal: Establish communications\n* Secondary goal: Secure perimeter\n* Tertiary goal: Map surrounding area\n\n_Sed posuere consectetur est at lobortis._ Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum.",
            image: "https://picsum.photos/id/7/600/400",
            size: { cols: 2, rows: 2 },
            priority: 2,
            type: "article",
        },
        {
            title: "Weather Anomalies",
            content:
                "### Weather Anomalies\n\nCras mattis consectetur purus sit amet fermentum.\n\n![Weather Chart](https://picsum.photos/id/200/400/100)\n\nNullam id dolor id nibh ultricies vehicula ut id elit. Nullam quis risus eget urna mollis ornare vel eu leo.",
            image: "https://picsum.photos/id/8/600/400",
            size: { cols: 1, rows: 1 },
            priority: 3,
            type: "article",
        },
    ];
    let { children } = $props();

    // For cursor effects
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

        // Add scroll-based animation triggers
        const observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add("fade-in");
                        observer.unobserve(entry.target);
                    }
                });
            },
            { threshold: 0.1 },
        );

        // Observe all article cards
        document.querySelectorAll(".glass").forEach((el) => {
            observer.observe(el);
        });

        return () => {
            document.removeEventListener("mousemove", handleMouseMove);
        };
    });
</script>

<div class="premium-container">
    <GradientBackground />

    {#if mounted}
        <div class="cursor-glow"></div>
    {/if}

    <div in:fade={{ duration: 800, delay: 400 }}>
        <NewspaperGrid {items}>
            {@render children()}
        </NewspaperGrid>
    </div>
</div>

<style>
    .premium-container {
        position: relative;
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
    @import url("https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&family=Merriweather:ital,opsz,wght@0,18..144,300..900;1,18..144,300..900&family=Rubik:ital,wght@0,300..900;1,300..900&display=swap");
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
</style>
