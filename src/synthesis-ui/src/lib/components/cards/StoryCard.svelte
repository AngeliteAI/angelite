<script>
    import BaseCard from "./BaseCard.svelte";

    /**
     * StoryCard component
     * Displays game narrative and campaign information
     *
     * Props:
     * - title: Story title
     * - subtitle: Chapter or episode name
     * - description: Story synopsis
     * - image: Story artwork URL
     * - duration: Campaign duration (e.g., "30+ hours")
     * - chapters: Array of chapter names
     * - progress: Current progress percentage (0-100)
     * - class: Additional CSS classes
     */
    let {
        title = "Epic Campaign",
        subtitle = "Chapter One",
        description = "",
        image = "",
        duration = "",
        chapters = [],
        progress = 0,
        class: additionalClasses = "",
        ...restProps
    } = $props();

    const storyIcon = `<path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />`;
</script>

<BaseCard
    {title}
    {subtitle}
    {description}
    {image}
    icon={storyIcon}
    gradient={{
        from: "rgba(251, 146, 60, 0.05)",
        to: "rgba(251, 191, 36, 0.05)"
    }}
    class="story-card {additionalClasses}"
    {...restProps}
>
    <!-- Story Details -->
    <div class="space-y-4">
        {#if duration}
            <div class="flex items-center gap-2 text-amber-300">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="text-sm font-medium">{duration} of story content</span>
            </div>
        {/if}

        {#if progress > 0}
            <div class="space-y-2">
                <div class="flex justify-between text-sm">
                    <span class="text-gray-400">Campaign Progress</span>
                    <span class="text-amber-300 font-medium">{progress}%</span>
                </div>
                <div class="w-full bg-black/30 rounded-full h-2 overflow-hidden">
                    <div
                        class="h-full bg-gradient-to-r from-amber-500 to-yellow-500 rounded-full transition-all duration-1000 ease-out"
                        style="width: {progress}%"
                    ></div>
                </div>
            </div>
        {/if}

        {#if chapters.length > 0}
            <div class="space-y-2">
                <h4 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Chapters</h4>
                <div class="space-y-1">
                    {#each chapters as chapter, i}
                        <div class="flex items-center gap-3 p-2 rounded bg-white/5 hover:bg-white/10 transition-colors">
                            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-500/20 to-yellow-500/20 flex items-center justify-center text-xs font-bold text-amber-300">
                                {i + 1}
                            </div>
                            <span class="text-sm text-gray-300">{chapter}</span>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </div>

    <svelte:fragment slot="footer">
        <div class="flex items-center justify-between">
            <button class="text-amber-400 hover:text-amber-300 transition-colors flex items-center gap-2 group">
                <span class="text-sm font-medium">Continue Story</span>
                <svg class="w-4 h-4 transition-transform group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
            </button>
        </div>
    </svelte:fragment>
</BaseCard>

<style>
    .story-card {
        position: relative;
        overflow: hidden;
    }

    .story-card::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(251, 191, 36, 0.1) 0%, transparent 70%);
        animation: pulse 4s ease-in-out infinite;
        pointer-events: none;
    }

    @keyframes pulse {
        0%, 100% {
            opacity: 0.5;
            transform: scale(0.8);
        }
        50% {
            opacity: 1;
            transform: scale(1);
        }
    }
</style>
