<script>
    import BaseCard from "./BaseCard.svelte";
    import { onMount } from "svelte";

    /**
     * TweetCard component
     * Displays tweet-style content with social engagement metrics
     *
     * Props:
     * - author: Tweet author handle (e.g., "@OutpostGame")
     * - content: Tweet text content
     * - timestamp: Time of tweet (e.g., "2h ago")
     * - likes: Number of likes
     * - retweets: Number of retweets
     * - replies: Number of replies
     * - image: Optional tweet image URL
     * - verified: Boolean for verified badge
     * - avatar: Author avatar URL
     * - class: Additional CSS classes
     */
    let {
        author = "@OutpostGame",
        content = "",
        timestamp = "now",
        likes = 0,
        retweets = 0,
        replies = 0,
        image = "",
        verified = true,
        avatar = "",
        class: additionalClasses = "",
        ...restProps
    } = $props();

    let isLiked = false;
    let isRetweeted = false;
    let animateLike = false;
    let animateRetweet = false;

    // Generate avatar if not provided
    let avatarUrl = $derived(
        avatar || `https://ui-avatars.com/api/?name=${author.replace("@", "")}&background=6366f1&color=fff`,
    );

    function handleLike() {
        isLiked = !isLiked;
        animateLike = true;
        setTimeout(() => (animateLike = false), 600);
    }

    function handleRetweet() {
        isRetweeted = !isRetweeted;
        animateRetweet = true;
        setTimeout(() => (animateRetweet = false), 600);
    }

    function formatNumber(num) {
        if (num >= 1000000) {
            return (num / 1000000).toFixed(1) + "M";
        } else if (num >= 1000) {
            return (num / 1000).toFixed(1) + "K";
        }
        return num.toString();
    }
</script>

<BaseCard
    padding="compact"
    gradient={{
        from: "rgba(29, 161, 242, 0.03)",
        to: "rgba(29, 161, 242, 0.05)",
    }}
    class="tweet-card {additionalClasses}"
    {...restProps}
>
    <!-- Tweet Header -->
    <div class="flex items-start gap-3 mb-3">
        <img
            src={avatarUrl}
            alt={author}
            class="w-12 h-12 rounded-full border-2 border-white/10"
        />
        <div class="flex-1">
            <div class="flex items-center gap-2">
                <span class="font-bold text-white">{author}</span>
                {#if verified}
                    <svg
                        class="w-5 h-5 text-blue-400"
                        fill="currentColor"
                        viewBox="0 0 20 20"
                    >
                        <path
                            fill-rule="evenodd"
                            d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                            clip-rule="evenodd"
                        />
                    </svg>
                {/if}
            </div>
            <span class="text-sm text-gray-400">{timestamp}</span>
        </div>
    </div>

    <!-- Tweet Content -->
    <div class="mb-3">
        <p class="text-white leading-relaxed whitespace-pre-wrap">{content}</p>
    </div>

    <!-- Tweet Image -->
    {#if image}
        <div class="mb-3 -mx-4">
            <img
                src={image}
                alt="Tweet attachment"
                class="w-full rounded-lg border border-white/10"
            />
        </div>
    {/if}

    <!-- Engagement Metrics -->
    <div class="flex items-center justify-between pt-3 border-t border-white/10">
        <!-- Reply -->
        <button
            class="flex items-center gap-2 text-gray-400 hover:text-blue-400 transition-colors group"
        >
            <div
                class="p-2 rounded-full group-hover:bg-blue-400/10 transition-colors"
            >
                <svg
                    class="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                    />
                </svg>
            </div>
            {#if replies > 0}
                <span class="text-sm">{formatNumber(replies)}</span>
            {/if}
        </button>

        <!-- Retweet -->
        <button
            class="flex items-center gap-2 transition-colors group"
            class:text-green-400={isRetweeted}
            class:text-gray-400={!isRetweeted}
            on:click={handleRetweet}
        >
            <div
                class="p-2 rounded-full group-hover:bg-green-400/10 transition-all"
                class:animate-spin={animateRetweet}
            >
                <svg
                    class="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                    />
                </svg>
            </div>
            <span class="text-sm">
                {formatNumber(retweets + (isRetweeted ? 1 : 0))}
            </span>
        </button>

        <!-- Like -->
        <button
            class="flex items-center gap-2 transition-colors group"
            class:text-red-500={isLiked}
            class:text-gray-400={!isLiked}
            on:click={handleLike}
        >
            <div
                class="p-2 rounded-full group-hover:bg-red-500/10 transition-all"
                class:animate-bounce={animateLike}
            >
                <svg
                    class="w-5 h-5"
                    fill={isLiked ? "currentColor" : "none"}
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
                    />
                </svg>
            </div>
            <span class="text-sm">
                {formatNumber(likes + (isLiked ? 1 : 0))}
            </span>
        </button>

        <!-- Share -->
        <button
            class="flex items-center gap-2 text-gray-400 hover:text-blue-400 transition-colors group"
        >
            <div
                class="p-2 rounded-full group-hover:bg-blue-400/10 transition-colors"
            >
                <svg
                    class="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                    />
                </svg>
            </div>
        </button>
    </div>
</BaseCard>

<style>
    .tweet-card {
        position: relative;
        overflow: hidden;
    }

    .tweet-card::before {
        content: "";
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(
            circle,
            rgba(29, 161, 242, 0.05) 0%,
            transparent 70%
        );
        animation: float 20s ease-in-out infinite;
        pointer-events: none;
    }

    @keyframes float {
        0%,
        100% {
            transform: translate(0, 0) rotate(0deg);
        }
        33% {
            transform: translate(30px, -30px) rotate(120deg);
        }
        66% {
            transform: translate(-20px, 20px) rotate(240deg);
        }
    }

    @keyframes spin {
        from {
            transform: rotate(0deg);
        }
        to {
            transform: rotate(360deg);
        }
    }

    :global(.animate-spin) {
        animation: spin 0.5s ease-in-out;
    }

    :global(.animate-bounce) {
        animation: bounce 0.6s ease-in-out;
    }

    @keyframes bounce {
        0%,
        100% {
            transform: translateY(0);
        }
        25% {
            transform: translateY(-10px);
        }
        75% {
            transform: translateY(-5px);
        }
    }
</style>
