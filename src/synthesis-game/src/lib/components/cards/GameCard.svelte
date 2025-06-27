<script>
    import { fade, fly, slide } from "svelte/transition";
    import { onMount } from "svelte";
    import GlassPanel from "../GlassPanel.svelte";
    import { marked } from "marked";

    /**
     * GameCard component - Flexible card supporting multiple variants and types
     *
     * Props:
     * - variant: Card variant type (hero, story, multiplayer, exploration, building, vr, update, community, media, purchase, standard, wide, imageHeavy, textFocus, highlight, compact, expandable, link, gallery, stats)
     * - title: Card title
     * - subtitle: Optional subtitle or category
     * - description: Main content text (supports markdown)
     * - image: Primary image URL
     * - images: Array of images for gallery variant
     * - icon: Icon name or SVG for the card
     * - stats: Object of statistics for stats variant
     * - features: Array of feature items
     * - cta: Call-to-action object { text, link, variant }
     * - expandable: Boolean for expandable behavior
     * - expanded: Boolean for expanded state (controlled)
     * - link: External link URL
     * - badge: Badge text (e.g., "NEW", "UPDATE")
     * - metadata: Additional metadata (reading time, date, etc.)
     * - size: Grid size { cols, rows }
     * - position: Grid position { col, row }
     * - class: Additional CSS classes
     */
    let {
        variant = "standard",
        title = "",
        subtitle = "",
        description = "",
        image = "",
        images = [],
        icon = "",
        stats = {},
        features = [],
        cta = null,
        expandable = false,
        expanded = false,
        link = "",
        badge = "",
        metadata = {},
        size = { cols: 1, rows: 1 },
        position = { col: 0, row: 0 },
        class: additionalClasses = "",
        onExpand = () => {},
        ...restProps
    } = $props();

    let imageLoaded = false;
    let isHovered = false;
    let currentImageIndex = 0;
    let internalExpanded = expanded;
    let cardElement;

    $effect(() => {
        internalExpanded = expanded;
    });

    const variantStyles = {
        hero: "min-h-[400px] lg:min-h-[500px]",
        story: "bg-gradient-to-br from-amber-500/5 to-orange-500/5",
        multiplayer: "bg-gradient-to-br from-blue-500/5 to-cyan-500/5",
        exploration: "bg-gradient-to-br from-green-500/5 to-emerald-500/5",
        building: "bg-gradient-to-br from-purple-500/5 to-pink-500/5",
        vr: "bg-gradient-to-br from-indigo-500/5 to-purple-500/5",
        update: "border-l-4 border-l-yellow-500",
        community: "bg-gradient-to-br from-pink-500/5 to-rose-500/5",
        media: "p-0",
        purchase: "bg-gradient-to-br from-green-600/10 to-emerald-600/10",
        standard: "",
        wide: "",
        imageHeavy: "p-0",
        textFocus: "",
        highlight: "ring-2 ring-indigo-500/50",
        compact: "p-4",
        expandable: "",
        link: "cursor-pointer hover:ring-2 hover:ring-indigo-500/50",
        gallery: "",
        stats: "bg-gradient-to-br from-slate-500/5 to-gray-500/5"
    };

    const iconMap = {
        story: `<path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />`,
        multiplayer: `<path d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />`,
        exploration: `<path d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`,
        building: `<path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />`,
        vr: `<path d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />`,
        update: `<path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />`,
        community: `<path d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />`,
        media: `<path d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />`,
        purchase: `<path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />`,
        link: `<path d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />`,
        stats: `<path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />`
    };

    onMount(() => {
        if (image) {
            const img = new Image();
            img.src = image;
            img.onload = () => imageLoaded = true;
        }
    });

    function handleToggleExpand() {
        internalExpanded = !internalExpanded;
        onExpand(internalExpanded);
    }

    function nextImage() {
        currentImageIndex = (currentImageIndex + 1) % images.length;
    }

    function prevImage() {
        currentImageIndex = (currentImageIndex - 1 + images.length) % images.length;
    }

    function handleClick() {
        if (link && !expandable) {
            window.open(link, '_blank');
        }
    }

    $: gridStyle = `grid-row: ${position.row + 1} / span ${size.rows}; grid-column: ${position.col + 1} / span ${size.cols};`;
    $: isCompact = variant === 'compact' || size.rows === 1 && size.cols === 1;
    $: isHero = variant === 'hero';
    $: isMedia = variant === 'media' || variant === 'imageHeavy';
    $: hasGallery = variant === 'gallery' && images.length > 0;
</script>

<GlassPanel
    class="game-card {variantStyles[variant]} {additionalClasses} {isCompact ? 'compact' : ''}"
    style={gridStyle}
    interactive={true}
    bind:this={cardElement}
    on:mouseenter={() => isHovered = true}
    on:mouseleave={() => isHovered = false}
    on:click={handleClick}
    in:fade={{ duration: 600, delay: position.row * 100 + position.col * 50 }}
    {...restProps}
>
    <!-- Badge -->
    {#if badge}
        <div class="absolute top-2 right-2 z-20">
            <span class="px-3 py-1 text-xs font-bold bg-gradient-to-r from-yellow-500 to-orange-500 text-white rounded-full">
                {badge}
            </span>
        </div>
    {/if}

    <!-- Media variants -->
    {#if isMedia && image}
        <div class="relative h-full">
            <img
                src={image}
                alt={title}
                class="w-full h-full object-cover transition-transform duration-500"
                class:scale-105={isHovered}
            />
            <div class="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent"></div>
            <div class="absolute bottom-0 left-0 right-0 p-6">
                <h3 class="text-2xl font-bold text-white mb-2">{title}</h3>
                {#if description}
                    <p class="text-gray-200">{description}</p>
                {/if}
            </div>
        </div>
    {:else if hasGallery}
        <!-- Gallery variant -->
        <div class="relative h-full p-4">
            <div class="relative h-48 mb-4 overflow-hidden rounded">
                <img
                    src={images[currentImageIndex]}
                    alt="{title} - Image {currentImageIndex + 1}"
                    class="w-full h-full object-cover transition-all duration-300"
                />
                <div class="absolute inset-0 flex items-center justify-between p-2">
                    <button
                        on:click|stopPropagation={prevImage}
                        class="p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
                    >
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                        </svg>
                    </button>
                    <button
                        on:click|stopPropagation={nextImage}
                        class="p-2 rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
                    >
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                        </svg>
                    </button>
                </div>
                <div class="absolute bottom-2 left-1/2 transform -translate-x-1/2 flex gap-1">
                    {#each images as _, i}
                        <div
                            class="w-2 h-2 rounded-full transition-colors"
                            class:bg-white={i === currentImageIndex}
                            class:bg-white/50={i !== currentImageIndex}
                        ></div>
                    {/each}
                </div>
            </div>
            <h3 class="text-xl font-bold text-white mb-2">{title}</h3>
            {#if description}
                <p class="text-gray-300">{description}</p>
            {/if}
        </div>
    {:else}
        <!-- Standard content layout -->
        <div class="p-6 {isCompact ? 'p-4' : ''} {isHero ? 'p-8 md:p-12 lg:p-16' : ''} h-full flex flex-col">
            <!-- Header section -->
            <div class="flex items-start gap-4 mb-4">
                {#if icon || iconMap[variant]}
                    <div class="flex-shrink-0">
                        <div class="w-12 h-12 rounded-lg bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center">
                            <svg class="w-6 h-6 text-indigo-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                {@html icon || iconMap[variant] || iconMap.standard}
                            </svg>
                        </div>
                    </div>
                {/if}
                <div class="flex-grow">
                    {#if subtitle}
                        <span class="text-sm text-gray-400 uppercase tracking-wider">{subtitle}</span>
                    {/if}
                    <h3 class="text-xl {isHero ? 'text-3xl md:text-4xl lg:text-5xl' : ''} font-bold text-white">
                        {title}
                    </h3>
                    {#if metadata.date || metadata.readingTime}
                        <div class="flex gap-3 mt-1 text-sm text-gray-400">
                            {#if metadata.date}
                                <span>{metadata.date}</span>
                            {/if}
                            {#if metadata.readingTime}
                                <span>{metadata.readingTime}</span>
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>

            <!-- Image section for standard cards -->
            {#if image && !isMedia}
                <div class="relative h-48 mb-4 overflow-hidden rounded">
                    <img
                        src={image}
                        alt={title}
                        class="w-full h-full object-cover transition-transform duration-500"
                        class:scale-105={isHovered}
                        style="opacity: {imageLoaded ? 1 : 0}"
                    />
                </div>
            {/if}

            <!-- Content section -->
            <div class="flex-grow">
                {#if description}
                    <div
                        class="text-gray-300 prose prose-invert prose-sm max-w-none"
                        class:line-clamp-3={!internalExpanded && expandable}
                    >
                        {@html marked(description)}
                    </div>
                {/if}

                <!-- Features list -->
                {#if features.length > 0}
                    <ul class="mt-4 space-y-2">
                        {#each features as feature}
                            <li class="flex items-start gap-2">
                                <svg class="w-5 h-5 text-indigo-400 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                                </svg>
                                <span class="text-gray-300">{feature}</span>
                            </li>
                        {/each}
                    </ul>
                {/if}

                <!-- Stats grid -->
                {#if Object.keys(stats).length > 0}
                    <div class="grid grid-cols-2 gap-4 mt-4">
                        {#each Object.entries(stats) as [key, value]}
                            <div class="text-center p-3 bg-white/5 rounded">
                                <div class="text-2xl font-bold text-indigo-300">{value}</div>
                                <div class="text-sm text-gray-400 capitalize">{key}</div>
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>

            <!-- Footer section -->
            <div class="mt-4 flex items-center justify-between">
                {#if expandable}
                    <button
                        on:click|stopPropagation={handleToggleExpand}
                        class="text-indigo-400 hover:text-indigo-300 transition-colors flex items-center gap-1"
                    >
                        <span>{internalExpanded ? 'Show less' : 'Show more'}</span>
                        <svg
                            class="w-4 h-4 transition-transform"
                            class:rotate-180={internalExpanded}
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                        >
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                        </svg>
                    </button>
                {/if}

                {#if cta}
                    <a
                        href={cta.link}
                        class="inline-flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-indigo-500 to-purple-500 hover:from-indigo-600 hover:to-purple-600 text-white font-medium rounded-lg transition-all duration-300 transform hover:scale-105"
                        class:ml-auto={expandable}
                    >
                        <span>{cta.text}</span>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                        </svg>
                    </a>
                {/if}

                {#if link && !cta}
                    <span class="text-indigo-400 flex items-center gap-1 ml-auto">
                        <span>View more</span>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                        </svg>
                    </span>
                {/if}
            </div>
        </div>
    {/if}
</GlassPanel>

<style>
    .game-card {
        height: 100%;
        transition: all 0.3s ease;
    }

    .game-card.compact {
        min-height: auto;
    }

    .line-clamp-3 {
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }
</style>
