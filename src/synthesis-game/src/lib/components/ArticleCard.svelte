<script>
    import { marked } from "marked";
    import { onMount } from "svelte";
    import { fade, fly } from "svelte/transition";
    import { backOut } from "svelte/easing";

    /**
     * ArticleCard component
     * Displays an article in a glass panel with image, title, and content
     *
     * Props:
     * - article: The article data object containing title, content, image
     * - size: Object with cols and rows for grid sizing
     * - position: Object with row and col for grid positioning
     */
    let { article, size, position } = $props();

    // Define defaults if not provided
    $effect(() => {
        size = size || { cols: 1, rows: 1 };
        position = position || { row: 0, col: 0 };
    });

    // Determine article type based on size
    let isTall = $derived(size.rows > 1);
    let isHero = $derived(size.cols === 3 && size.rows >= 2);
    let isMedium = $derived(size.cols === 2 && size.rows === 2);

    // For animations and interactions
    let imageLoaded = false;
    let isHovered = false;
    let blurImageUrl = "";

    // Calculate estimated reading time
    const words = 0;
    const minutes = Math.max(1, Math.round(words / 200));
    const readingTime = `${minutes} min read`;

    function handleMouseEnter() {
        isHovered = true;
    }

    function handleMouseLeave() {
        isHovered = false;
    }

    onMount(() => {
        // Create a tiny blurred version of the image for loading effect
        const img = new Image();
        img.crossOrigin = "Anonymous";
        img.src = article.image;
        img.onload = () => {
            createBlurredImage(img);
            imageLoaded = true;
        };
    });

    function createBlurredImage(img) {
        const canvas = document.createElement("canvas");
        const ctx = canvas.getContext("2d");
        canvas.width = 20;
        canvas.height = 20;
        ctx.drawImage(img, 0, 0, 20, 20);
        blurImageUrl = canvas.toDataURL("image/jpeg", 0.1);
    }
</script>

<div
    class="article-card overflow-hidden flex flex-col p-0 transform transition-all duration-300 h-full"
    on:mouseenter={handleMouseEnter}
    on:mouseleave={handleMouseLeave}
    in:fade={{ duration: 600, delay: 100 }}
>
    <div class="relative overflow-hidden">
        {#if blurImageUrl}
            <div
                class="absolute inset-0 bg-center bg-cover transition-opacity duration-700"
                style={`background-image: url(${blurImageUrl}); filter: blur(10px); transform: scale(1.1); opacity: ${imageLoaded ? 0 : 1};`}
            ></div>
        {/if}

        <img
            src={article.image}
            alt={article.title}
            class={`w-full transition-all duration-500 ${isHovered ? "scale-110" : "scale-100"} object-cover`}
            class:h-96={isHero}
            class:h-64={isMedium}
            class:h-48={isTall && !isHero && !isMedium}
            class:h-40={!isTall && !isHero && !isMedium}
            style={`opacity: ${imageLoaded ? 1 : 0};`}
        />
        <div
            class="absolute top-2 right-2 bg-black/60 text-xs font-medium py-1 px-2 rounded-full backdrop-blur-md opacity-80 z-10"
        >
            {readingTime}
        </div>
    </div>
    <div class="p-6 flex-grow backdrop-blur-sm" class:p-8={isHero}>
        <h2
            class="font-bold mb-3 transition-all duration-300"
            class:text-4xl={isHero}
            class:text-2xl={isMedium || isTall}
            class:text-xl={!isHero && !isMedium && !isTall}
            class:text-indigo-300={isHovered}
            class:tracking-wide={isHero}
        >
            {article.title}
        </h2>
        <div
            class="text-gray-300 markdown-content prose prose-invert max-w-none"
            class:prose-lg={isHero}
            class:prose-base={isMedium}
            class:prose-sm={!isHero && !isMedium}
            class:line-clamp-4={!isTall && !isHero}
            class:line-clamp-6={isTall && !isHero}
        >
            {@html article.content ? marked(article.content) : ""}
        </div>
        {#if isHero}
            <div class="mt-6 flex items-center gap-4">
                <button class="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg transition-all duration-300 transform hover:scale-105 hover:shadow-lg">
                    Learn More
                </button>
                <span class="text-sm text-gray-400">{readingTime}</span>
            </div>
        {/if}
    </div>
</div>

<style>
    .article-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        box-shadow:
            0 8px 32px -4px rgba(0, 0, 0, 0.3),
            0 0 0 1px rgba(255, 255, 255, 0.1) inset,
            0 20px 40px -8px rgba(99, 102, 241, 0.1);
        border-radius: 16px;
        transition:
            transform 0.3s cubic-bezier(0.16, 1, 0.3, 1),
            box-shadow 0.3s cubic-bezier(0.16, 1, 0.3, 1),
            border-color 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        overflow: hidden;
        animation: fadeIn 0.8s ease forwards;
        height: 100%;
        position: relative;
    }
    
    .article-card::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 1px;
        background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
        opacity: 0;
        transition: opacity 0.3s ease;
    }
    
    .article-card:hover::before {
        opacity: 1;
    }

    .article-card:hover {
        transform: translateY(-4px) scale(1.02);
        border-color: rgba(255, 255, 255, 0.2);
        box-shadow:
            0 20px 40px -4px rgba(0, 0, 0, 0.4),
            0 0 0 1px rgba(255, 255, 255, 0.2) inset,
            0 0 80px -20px rgba(99, 102, 241, 0.4),
            0 0 0 2px rgba(99, 102, 241, 0.1);
    }

    .markdown-content :global(h1),
    .markdown-content :global(h2),
    .markdown-content :global(h3),
    .markdown-content :global(h4) {
        color: white;
        margin-top: 0.5em;
        margin-bottom: 0.5em;
        font-family: "Merriweather", serif;
        letter-spacing: 0.015em;
    }

    .markdown-content :global(h1) {
        font-size: 1.5em;
        line-height: 1.2;
    }

    .markdown-content :global(h2) {
        font-size: 1.3em;
        line-height: 1.25;
    }

    .markdown-content :global(h3) {
        font-size: 1.1em;
        line-height: 1.3;
    }

    .markdown-content :global(p) {
        margin-bottom: 0.5em;
        font-family: "Inter", sans-serif;
        line-height: 1.6;
        letter-spacing: -0.01em;
    }

    .markdown-content :global(ul),
    .markdown-content :global(ol) {
        padding-left: 1.5em;
        margin-bottom: 0.5em;
    }

    .markdown-content :global(li) {
        margin-bottom: 0.25em;
    }

    .markdown-content :global(blockquote) {
        border-left: 3px solid rgba(99, 102, 241, 0.6);
        padding: 0.5em 0 0.5em 1em;
        margin-left: 0;
        margin-right: 0;
        font-style: italic;
        color: rgba(255, 255, 255, 0.8);
        background-color: rgba(99, 102, 241, 0.05);
        border-radius: 0 4px 4px 0;
    }

    .markdown-content :global(code) {
        background-color: rgba(0, 0, 0, 0.3);
        padding: 0.2em 0.4em;
        border-radius: 3px;
        font-family: monospace;
        font-size: 0.9em;
        color: #e2e8f0;
    }

    .markdown-content :global(pre) {
        background-color: rgba(0, 0, 0, 0.3);
        padding: 0.75em 1em;
        border-radius: 4px;
        overflow-x: auto;
        margin-bottom: 0.75em;
        border: 1px solid rgba(255, 255, 255, 0.1);
    }

    .markdown-content :global(pre code) {
        background-color: transparent;
        padding: 0;
        color: #e2e8f0;
    }

    .markdown-content :global(table) {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 0.75em;
        font-size: 0.9em;
    }

    .markdown-content :global(th),
    .markdown-content :global(td) {
        border: 1px solid rgba(255, 255, 255, 0.2);
        padding: 0.4em 0.6em;
        text-align: left;
    }

    .markdown-content :global(th) {
        background-color: rgba(99, 102, 241, 0.1);
        font-weight: 600;
    }

    .markdown-content :global(tr:nth-child(even)) {
        background-color: rgba(255, 255, 255, 0.03);
    }

    .markdown-content :global(hr) {
        border: none;
        border-top: 1px solid rgba(99, 102, 241, 0.2);
        margin: 1em 0;
    }

    .markdown-content :global(img) {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
        margin: 0.75em 0;
        border: 1px solid rgba(255, 255, 255, 0.1);
    }

    .markdown-content :global(a) {
        color: rgb(129, 140, 248);
        text-decoration: none;
        transition: all 0.2s ease;
        border-bottom: 1px dotted rgba(129, 140, 248, 0.4);
        padding-bottom: 1px;
    }

    .markdown-content :global(a:hover) {
        color: rgb(165, 180, 252);
        border-bottom: 1px solid rgba(165, 180, 252, 0.7);
    }

    /* Line clamp for content */
    .line-clamp-3 {
        display: -webkit-box;
        -webkit-line-clamp: 3;
        -webkit-box-orient: vertical;
        overflow: hidden;
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
</style>
