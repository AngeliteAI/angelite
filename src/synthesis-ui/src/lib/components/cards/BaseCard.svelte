<script>
    import { fade, fly } from "svelte/transition";
    import { onMount } from "svelte";
    import GlassPanel from "../GlassPanel.svelte";
    import { marked } from "marked";

    /**
     * BaseCard component - Foundation for all card types
     *
     * Props:
     * - title: Card title
     * - subtitle: Optional subtitle
     * - description: Card content (supports markdown)
     * - image: Primary image URL
     * - imageAlt: Alt text for image
     * - icon: Icon SVG path or element
     * - badge: Badge text (e.g., "NEW", "UPDATE")
     * - size: Grid size { cols: 1, rows: 1 }
     * - interactive: Enable hover effects (default: true)
     * - padding: Padding size ('none' | 'compact' | 'normal' | 'large')
     * - gradient: Background gradient colors
     * - class: Additional CSS classes
     */
    let {
        title = "",
        subtitle = "",
        description = "",
        image = "",
        imageAlt = "",
        icon = "",
        badge = "",
        size = { cols: 1, rows: 1 },
        interactive = true,
        padding = "normal",
        gradient = null,
        class: additionalClasses = "",
        children,
        ...restProps
    } = $props();

    let imageLoaded = false;
    let isHovered = false;
    let cardElement;

    const paddingClasses = {
        none: "p-0",
        compact: "p-4",
        normal: "p-6",
        large: "p-8 md:p-12",
    };

    onMount(() => {
        if (image) {
            const img = new Image();
            img.src = image;
            img.onload = () => (imageLoaded = true);
        }
    });

    let gradientStyle = $derived(
        gradient
            ? `background: linear-gradient(135deg, ${gradient.from} 0%, ${gradient.to} 100%);`
            : "",
    );
</script>

<div in:fade={{ duration: 600, delay: 100 }}>
    <GlassPanel
        class="base-card {additionalClasses} h-full"
        style={gradientStyle}
        {interactive}
        bind:this={cardElement}
        on:mouseenter={() => (isHovered = true)}
        on:mouseleave={() => (isHovered = false)}
        {...restProps}
    >
        <div
            class="card-content {paddingClasses[padding]} h-full flex flex-col"
        >
            <!-- Badge -->
            {#if badge}
                <div class="absolute top-3 right-3 z-20">
                    <span
                        class="badge px-3 py-1 text-xs font-bold bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-full shadow-lg"
                    >
                        {badge}
                    </span>
                </div>
            {/if}

            <!-- Header Slot -->
            {#if $$slots.header}
                <slot name="header" {isHovered} />
            {:else if icon || subtitle || title}
                <div class="card-header flex items-start gap-4 mb-4">
                    {#if icon}
                        <div class="icon-wrapper flex-shrink-0">
                            <div
                                class="w-12 h-12 rounded-lg bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center backdrop-blur-sm"
                            >
                                {#if typeof icon === "string"}
                                    <svg
                                        class="w-6 h-6 text-indigo-300"
                                        fill="none"
                                        stroke="currentColor"
                                        viewBox="0 0 24 24"
                                    >
                                        {@html icon}
                                    </svg>
                                {:else}
                                    {icon}
                                {/if}
                            </div>
                        </div>
                    {/if}

                    <div class="flex-grow">
                        {#if subtitle}
                            <span
                                class="subtitle text-sm text-gray-400 uppercase tracking-wider font-medium"
                            >
                                {subtitle}
                            </span>
                        {/if}
                        {#if title}
                            <h3
                                class="title text-xl md:text-2xl font-bold text-white leading-tight"
                            >
                                {title}
                            </h3>
                        {/if}
                    </div>
                </div>
            {/if}

            <!-- Image Slot -->
            {#if $$slots.image}
                <slot name="image" {isHovered} {imageLoaded} />
            {:else if image}
                <div
                    class="card-image relative overflow-hidden rounded-lg mb-4"
                >
                    <img
                        src={image}
                        alt={imageAlt || title}
                        class="w-full h-48 object-cover transition-all duration-500"
                        class:scale-105={isHovered}
                        style="opacity: {imageLoaded ? 1 : 0}"
                    />
                    <div
                        class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent pointer-events-none"
                    ></div>
                </div>
            {/if}

            <!-- Content Slot -->
            <div class="card-body flex-grow">
                {#if $$slots.default}
                    <slot {isHovered} />
                {:else if description}
                    <div
                        class="prose prose-invert prose-sm max-w-none text-gray-300"
                    >
                        {@html marked(description)}
                    </div>
                {/if}
            </div>

            <!-- Footer Slot -->
            {#if $$slots.footer}
                <div class="card-footer mt-4">
                    <slot name="footer" {isHovered} />
                </div>
            {/if}
        </div>

        <!-- Overlay Effects -->
        {#if $$slots.overlay}
            <slot name="overlay" {isHovered} />
        {/if}
    </GlassPanel>
</div>

<style>
    .base-card {
        position: relative;
        height: 100%;
        transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .base-card :global(.prose) {
        color: rgb(209 213 219);
    }

    .base-card :global(.prose h1),
    .base-card :global(.prose h2),
    .base-card :global(.prose h3),
    .base-card :global(.prose h4) {
        color: white;
        margin-top: 0.5em;
        margin-bottom: 0.5em;
    }

    .base-card :global(.prose p) {
        margin-bottom: 0.75em;
        line-height: 1.7;
    }

    .base-card :global(.prose a) {
        color: rgb(129, 140, 248);
        text-decoration: none;
        border-bottom: 1px dotted rgba(129, 140, 248, 0.4);
        transition: all 0.2s ease;
    }

    .base-card :global(.prose a:hover) {
        color: rgb(165, 180, 252);
        border-bottom-color: rgba(165, 180, 252, 0.7);
    }

    .base-card :global(.prose code) {
        background-color: rgba(0, 0, 0, 0.3);
        padding: 0.2em 0.4em;
        border-radius: 3px;
        font-size: 0.9em;
        color: #e2e8f0;
    }

    .base-card :global(.prose ul),
    .base-card :global(.prose ol) {
        padding-left: 1.5em;
        margin-bottom: 0.75em;
    }

    .base-card :global(.prose li) {
        margin-bottom: 0.25em;
    }

    .base-card :global(.prose blockquote) {
        border-left: 3px solid rgba(99, 102, 241, 0.6);
        padding-left: 1em;
        margin-left: 0;
        font-style: italic;
        color: rgba(255, 255, 255, 0.8);
    }

    @keyframes shimmer {
        0% {
            background-position: -200% center;
        }
        100% {
            background-position: 200% center;
        }
    }

    .badge {
        animation: shimmer 3s linear infinite;
        background-size: 200% 100%;
    }
</style>
