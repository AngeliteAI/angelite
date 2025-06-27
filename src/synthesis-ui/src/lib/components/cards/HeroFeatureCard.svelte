<script>
    import { onMount } from "svelte";
    import BaseCard from "./BaseCard.svelte";

    /**
     * HeroFeatureCard component
     * Large banner card for showcasing the main game concept
     *
     * Props:
     * - title: Main title text
     * - subtitle: Secondary title or tagline
     * - description: Detailed description text
     * - image: Background image URL
     * - features: Array of feature highlights
     * - cta: Call-to-action object { text, link }
     * - class: Additional CSS classes
     */
    let {
        title = "Infinite Universe",
        subtitle = "Explore Beyond Boundaries",
        description = "Embark on an epic journey through procedurally generated galaxies",
        image = "",
        features = [],
        cta = null,
        class: additionalClasses = "",
        ...restProps
    } = $props();

    let parallaxOffset = { x: 0, y: 0 };
    let cardElement;

    function handleMouseMove(event) {
        if (!cardElement) return;

        const rect = cardElement.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;

        const percentX = (event.clientX - centerX) / (rect.width / 2);
        const percentY = (event.clientY - centerY) / (rect.height / 2);

        parallaxOffset = {
            x: percentX * 20,
            y: percentY * 20,
        };
    }

    function handleMouseLeave() {
        parallaxOffset = { x: 0, y: 0 };
    }
</script>

<BaseCard
    class="hero-feature-card {additionalClasses}"
    padding="large"
    gradient={{
        from: "rgba(99, 102, 241, 0.05)",
        to: "rgba(168, 85, 247, 0.05)",
    }}
    bind:this={cardElement}
    on:mousemove={handleMouseMove}
    on:mouseleave={handleMouseLeave}
    {...restProps}
>
    <!-- Custom Header -->
    <svelte:fragment slot="header">
        <div class="space-y-6">
            {#if subtitle}
                <span
                    class="inline-block text-sm md:text-base font-medium text-indigo-300 uppercase tracking-wider animate-fade-in"
                >
                    {subtitle}
                </span>
            {/if}

            <h1
                class="text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-bold text-white leading-tight animate-slide-up"
            >
                <span
                    class="bg-gradient-to-r from-white via-indigo-200 to-purple-200 bg-clip-text text-transparent"
                >
                    {title}
                </span>
            </h1>

            {#if description}
                <p
                    class="text-lg md:text-xl text-gray-200 max-w-2xl animate-fade-in-delay"
                >
                    {description}
                </p>
            {/if}
        </div>
    </svelte:fragment>

    <!-- Custom Image with Parallax -->
    <svelte:fragment slot="image">
        {#if image}
            <div class="absolute inset-0 overflow-hidden -z-10">
                <div
                    class="absolute inset-0 transition-all duration-700 ease-out"
                    style="transform: translate({parallaxOffset.x *
                        0.5}px, {parallaxOffset.y * 0.5}px) scale(1.1);"
                >
                    <img
                        src={image}
                        alt={title}
                        class="w-full h-full object-cover"
                    />
                </div>
                <!-- Gradient Overlays -->
                <div
                    class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/40 to-transparent"
                ></div>
                <div
                    class="absolute inset-0 bg-gradient-to-r from-black/60 via-transparent to-black/60"
                ></div>
            </div>
        {/if}
    </svelte:fragment>

    <!-- Features and CTA -->
    <div class="mt-8 space-y-6">
        {#if features.length > 0}
            <div class="flex flex-wrap gap-4">
                {#each features as feature, i}
                    <div
                        class="flex items-center gap-2 bg-white/10 backdrop-blur-sm px-4 py-2 rounded-full border border-white/20 animate-slide-in"
                        style="animation-delay: {600 + i * 100}ms"
                    >
                        <svg
                            class="w-4 h-4 text-indigo-300"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                        >
                            <path
                                fill-rule="evenodd"
                                d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                clip-rule="evenodd"
                            />
                        </svg>
                        <span class="text-sm text-gray-200">{feature}</span>
                    </div>
                {/each}
            </div>
        {/if}

        {#if cta}
            <div class="animate-fade-in-delay-long">
                <a
                    href={cta.link}
                    class="inline-flex items-center gap-3 px-8 py-4 bg-gradient-to-r from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white font-semibold rounded-lg transform transition-all duration-300 hover:scale-105 hover:shadow-xl shadow-lg group"
                >
                    <span>{cta.text}</span>
                    <svg
                        class="w-5 h-5 transition-transform group-hover:translate-x-1"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                    >
                        <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 7l5 5m0 0l-5 5m5-5H6"
                        />
                    </svg>
                </a>
            </div>
        {/if}
    </div>

    <!-- Overlay Effects -->
    <svelte:fragment slot="overlay">
        <div class="absolute inset-0 pointer-events-none overflow-hidden">
            <!-- Floating Particles -->
            <div
                class="absolute top-1/4 left-1/4 w-2 h-2 bg-indigo-400 rounded-full opacity-50 animate-float-slow"
            ></div>
            <div
                class="absolute top-3/4 right-1/3 w-3 h-3 bg-purple-400 rounded-full opacity-40 animate-float-medium"
            ></div>
            <div
                class="absolute bottom-1/4 left-2/3 w-2 h-2 bg-blue-400 rounded-full opacity-30 animate-float-fast"
            ></div>

            <!-- Gradient Orbs -->
            <div
                class="absolute -top-20 -right-20 w-40 h-40 bg-gradient-to-br from-indigo-500/20 to-purple-500/20 rounded-full blur-3xl transition-transform duration-1000"
                style="transform: translate({parallaxOffset.x}px, {parallaxOffset.y}px)"
            ></div>
            <div
                class="absolute -bottom-20 -left-20 w-60 h-60 bg-gradient-to-tr from-purple-500/20 to-pink-500/20 rounded-full blur-3xl transition-transform duration-1000"
                style="transform: translate({-parallaxOffset.x *
                    0.5}px, {-parallaxOffset.y * 0.5}px)"
            ></div>
        </div>
    </svelte:fragment>
</BaseCard>

<style>
    .hero-feature-card {
        min-height: 400px;
    }

    @media (min-width: 1024px) {
        .hero-feature-card {
            min-height: 500px;
        }
    }

    @keyframes float-slow {
        0%,
        100% {
            transform: translateY(0) translateX(0);
        }
        33% {
            transform: translateY(-20px) translateX(10px);
        }
        66% {
            transform: translateY(10px) translateX(-5px);
        }
    }

    @keyframes float-medium {
        0%,
        100% {
            transform: translateY(0) translateX(0);
        }
        50% {
            transform: translateY(-30px) translateX(-15px);
        }
    }

    @keyframes float-fast {
        0%,
        100% {
            transform: translateY(0) translateX(0);
        }
        25% {
            transform: translateY(-15px) translateX(5px);
        }
        75% {
            transform: translateY(15px) translateX(-10px);
        }
    }

    @keyframes fade-in {
        from {
            opacity: 0;
        }
        to {
            opacity: 1;
        }
    }

    @keyframes slide-up {
        from {
            opacity: 0;
            transform: translateY(20px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }

    @keyframes slide-in {
        from {
            opacity: 0;
            transform: translateX(-20px);
        }
        to {
            opacity: 1;
            transform: translateX(0);
        }
    }

    :global(.animate-float-slow) {
        animation: float-slow 8s ease-in-out infinite;
    }

    :global(.animate-float-medium) {
        animation: float-medium 6s ease-in-out infinite;
    }

    :global(.animate-float-fast) {
        animation: float-fast 4s ease-in-out infinite;
    }

    :global(.animate-fade-in) {
        animation: fade-in 0.6s ease-out forwards;
    }

    :global(.animate-slide-up) {
        animation: slide-up 0.8s ease-out forwards;
    }

    :global(.animate-slide-in) {
        animation: slide-in 0.4s ease-out forwards;
        animation-fill-mode: both;
    }

    :global(.animate-fade-in-delay) {
        animation: fade-in 0.6s ease-out 0.4s forwards;
        opacity: 0;
    }

    :global(.animate-fade-in-delay-long) {
        animation: fade-in 0.6s ease-out 0.7s forwards;
        opacity: 0;
    }
</style>
