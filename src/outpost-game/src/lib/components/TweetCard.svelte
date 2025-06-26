<script>
    import { marked } from "marked";
    import { onMount } from "svelte";
    import { fade, fly } from "svelte/transition";
    import { backOut } from "svelte/easing";

    /**
     * TweetCard component
     * Displays a social media update in a glass panel with profile, content, and engagement
     *
     * Props:
     * - tweet: The tweet data object containing content, author, metrics, etc.
     * - size: Object with cols and rows for grid sizing
     * - position: Object with row and col for grid positioning
     */
    let { tweet, size, position } = $props();

    // Define defaults if not provided
    $effect(() => {
        size = size || { cols: 1, rows: 1 };
        position = position || { row: 0, col: 0 };
    });

    // For animations and interactions
    let isHovered = false;
    let showEngagement = false;

    // Format numbers (1234 -> 1.2K)
    function formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + 'M';
        }
        if (num >= 1000) {
            return (num / 1000).toFixed(1) + 'K';
        }
        return num.toString();
    }

    // Format timestamp
    function formatTime(timestamp) {
        const now = new Date();
        const tweetTime = new Date(timestamp);
        const diffMs = now - tweetTime;
        const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
        const diffDays = Math.floor(diffHours / 24);

        if (diffDays > 0) {
            return `${diffDays}d`;
        }
        if (diffHours > 0) {
            return `${diffHours}h`;
        }
        return `${Math.floor(diffMs / (1000 * 60))}m`;
    }

    function handleMouseEnter() {
        isHovered = true;
        setTimeout(() => {
            showEngagement = true;
        }, 200);
    }

    function handleMouseLeave() {
        isHovered = false;
        showEngagement = false;
    }

    // Default values if not provided
    const author = tweet.author || { name: "Outpost Team", handle: "@outpostgame", avatar: "https://picsum.photos/id/10/40/40" };
    const metrics = tweet.metrics || { likes: 127, retweets: 43, replies: 8 };
    const timestamp = tweet.timestamp || new Date().toISOString();
</script>

<div
    class="tweet-card overflow-hidden flex flex-col p-0 transform transition-all duration-300"
    style={`grid-row: ${position.row + 2} / span ${size.rows}; grid-column: ${position.col + 1} / span ${size.cols};`}
    on:mouseenter={handleMouseEnter}
    on:mouseleave={handleMouseLeave}
    in:fade={{ duration: 600, delay: position.row * 100 + position.col * 50 }}
>
    <div class="p-4 flex-grow">
        <!-- Tweet Header -->
        <div class="flex items-start justify-between mb-3">
            <div class="flex items-center space-x-3 flex-grow min-w-0">
                <img
                    src={author.avatar}
                    alt={author.name}
                    class="w-10 h-10 rounded-full ring-2 ring-cyan-400/30 transition-all duration-300"
                    class:ring-cyan-400={isHovered}
             />
                <div class="flex-grow min-w-0">
                    <div class="flex items-center space-x-2">
                        <h3 class="font-bold text-white text-sm truncate max-w-24">
                            {author.name}
                        </h3>
                        <span class="text-cyan-400 text-xs">✓</span>
                    </div>
                    <p class="text-gray-400 text-xs truncate">
                        {author.handle}
                    </p>
                </div>
            </div>
            <div class="flex items-center space-x-2 flex-shrink-0">
                <span class="text-gray-500 text-xs">
                    {formatTime(timestamp)}
                </span>
                <button class="text-gray-400 hover:text-gray-300 transition-colors">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"></path>
                    </svg>
                </button>
            </div>
        </div>

        <!-- Tweet Content -->
        <div class="mb-4">
            <div class="text-gray-200 tweet-content prose prose-invert prose-sm max-w-none text-sm leading-relaxed">
                {@html marked(tweet.content)}
            </div>
        </div>

        <!-- Tweet Image (if exists) -->
        {#if tweet.image}
            <div class="mb-4 -mx-1">
                <img
                    src={tweet.image}
                    alt="Tweet image"
                    class="w-full rounded-lg border border-white/10 transition-all duration-300"
                    class:scale-[1.02]={isHovered}
                />
            </div>
        {/if}

        <!-- Engagement Bar -->
        <div
            class="flex items-center justify-between pt-3 border-t border-white/10 transition-all duration-300"
            class:border-cyan-400={showEngagement}

        >
            <button class="flex items-center space-x-2 text-gray-400 hover:text-cyan-400 transition-colors group">
                <div class="p-2 rounded-full transition-colors group-hover:bg-cyan-400/10">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
                    </svg>
                </div>
                <span class="text-xs" class:opacity-100={showEngagement} class:opacity-0={!showEngagement}>
                    {formatNumber(metrics.replies)}
                </span>
            </button>

            <button class="flex items-center space-x-2 text-gray-400 hover:text-green-400 transition-colors group">
                <div class="p-2 rounded-full transition-colors group-hover:bg-green-400/10">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                    </svg>
                </div>
                <span class="text-xs" class:opacity-100={showEngagement} class:opacity-0={!showEngagement}>
                    {formatNumber(metrics.retweets)}
                </span>
            </button>

            <button class="flex items-center space-x-2 text-gray-400 hover:text-red-400 transition-colors group">
                <div class="p-2 rounded-full transition-colors group-hover:bg-red-400/10">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
                    </svg>
                </div>
                <span class="text-xs" class:opacity-100={showEngagement} class:opacity-0={!showEngagement}>
                    {formatNumber(metrics.likes)}
                </span>
            </button>

            <button class="flex items-center space-x-2 text-gray-400 hover:text-cyan-400 transition-colors group">
                <div class="p-2 rounded-full transition-colors group-hover:bg-cyan-400/10">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
                    </svg>
                </div>
            </button>
        </div>
    </div>
</div>

<style>
    .tweet-card {
        background: rgba(255, 255, 255, 0.04);
        backdrop-filter: blur(12px);
        border: 1px solid rgba(34, 211, 238, 0.2);
        box-shadow:
            0 4px 24px -1px rgba(0, 0, 0, 0.2),
            0 0 0 1px rgba(34, 211, 238, 0.1) inset;
        border-radius: 12px;
        transition:
            transform 0.3s cubic-bezier(0.16, 1, 0.3, 1),
            box-shadow 0.3s cubic-bezier(0.16, 1, 0.3, 1),
            border-color 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        overflow: hidden;
        animation: fadeIn 0.8s ease forwards;
        height: 100%;
        position: relative;
    }

    .tweet-card::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 2px;
        background: linear-gradient(90deg,
            rgba(34, 211, 238, 0.6) 0%,
            rgba(99, 102, 241, 0.6) 50%,
            rgba(34, 211, 238, 0.6) 100%);
        opacity: 0.7;
    }

    .tweet-card:hover {
        transform: translateY(-2px) scale(1.01);
        border-color: rgba(34, 211, 238, 0.4);
        box-shadow:
            0 8px 32px -2px rgba(0, 0, 0, 0.25),
            0 0 0 1px rgba(34, 211, 238, 0.2) inset,
            0 0 20px -5px rgba(34, 211, 238, 0.3);
    }

    .tweet-card:hover::before {
        opacity: 1;
        box-shadow: 0 0 10px rgba(34, 211, 238, 0.5);
    }

    .tweet-content :global(p) {
        margin-bottom: 0.5em;
        font-family: "Inter", sans-serif;
        line-height: 1.5;
        letter-spacing: -0.01em;
    }

    .tweet-content :global(a) {
        color: rgb(34, 211, 238);
        text-decoration: none;
        transition: all 0.2s ease;
        font-weight: 500;
    }

    .tweet-content :global(a:hover) {
        color: rgb(103, 232, 249);
        text-shadow: 0 0 8px rgba(34, 211, 238, 0.4);
    }

    .tweet-content :global(strong) {
        color: white;
        font-weight: 600;
    }

    .tweet-content :global(em) {
        color: rgba(255, 255, 255, 0.9);
        font-style: italic;
    }

    /* Hashtag and mention styling */
    .tweet-content :global(*) {
        color: inherit;
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

    /* Engagement button animations */
    button svg {
        transition: transform 0.2s ease;
    }

    button:hover svg {
        transform: scale(1.1);
    }

    /* Staggered engagement reveal */
    .flex.items-center.space-x-2 span {
        transition: opacity 0.3s ease;
    }

    .flex.items-center.space-x-2:nth-child(1) span {
        transition-delay: 0.1s;
    }

    .flex.items-center.space-x-2:nth-child(2) span {
        transition-delay: 0.2s;
    }

    .flex.items-center.space-x-2:nth-child(3) span {
        transition-delay: 0.3s;
    }
</style>
