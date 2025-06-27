<script>
    import BaseCard from "./BaseCard.svelte";

    /**
     * ExplorationCard component
     * Displays discovery and adventure game mechanics
     *
     * Props:
     * - title: Card title
     * - subtitle: Exploration category
     * - description: Feature description
     * - image: Exploration artwork URL
     * - discoveredLocations: Number of discovered locations
     * - totalLocations: Total locations available
     * - explorationFeatures: Array of exploration features
     * - currentBiome: Current biome/environment name
     * - resources: Object of discovered resources { name: quantity }
     * - class: Additional CSS classes
     */
    let {
        title = "Exploration",
        subtitle = "Discover New Worlds",
        description = "",
        image = "",
        discoveredLocations = 0,
        totalLocations = 0,
        explorationFeatures = [],
        currentBiome = "",
        resources = {},
        class: additionalClasses = "",
        ...restProps
    } = $props();

    const explorationIcon = `<path d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`;

    let explorationProgress = $derived(
        totalLocations > 0 ? (discoveredLocations / totalLocations) * 100 : 0,
    );
</script>

<BaseCard
    {title}
    {subtitle}
    {description}
    {image}
    icon={explorationIcon}
    gradient={{
        from: "rgba(34, 197, 94, 0.05)",
        to: "rgba(16, 185, 129, 0.05)",
    }}
    class="exploration-card {additionalClasses}"
    {...restProps}
>
    <div class="space-y-4">
        <!-- Current Biome -->
        {#if currentBiome}
            <div
                class="p-3 bg-gradient-to-r from-green-500/10 to-emerald-500/10 rounded-lg border border-green-500/20"
            >
                <div class="flex items-center justify-between">
                    <span class="text-sm text-gray-400">Current Biome</span>
                    <span
                        class="text-green-400 font-medium flex items-center gap-2"
                    >
                        <svg
                            class="w-4 h-4"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                        >
                            <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                            />
                            <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                            />
                        </svg>
                        {currentBiome}
                    </span>
                </div>
            </div>
        {/if}

        <!-- Exploration Progress -->
        {#if totalLocations > 0}
            <div class="space-y-2">
                <div class="flex justify-between text-sm">
                    <span class="text-gray-400">Locations Discovered</span>
                    <span class="text-green-400 font-medium"
                        >{discoveredLocations} / {totalLocations}</span
                    >
                </div>
                <div
                    class="w-full bg-black/30 rounded-full h-2 overflow-hidden"
                >
                    <div
                        class="h-full bg-gradient-to-r from-green-500 to-emerald-500 rounded-full transition-all duration-1000 ease-out relative overflow-hidden"
                        style="width: {explorationProgress}%"
                    >
                        <div
                            class="absolute inset-0 bg-white/20 animate-shimmer"
                        ></div>
                    </div>
                </div>
                <div class="text-xs text-gray-500 text-right">
                    {explorationProgress.toFixed(1)}% explored
                </div>
            </div>
        {/if}

        <!-- Resources -->
        {#if Object.keys(resources).length > 0}
            <div class="space-y-2">
                <h4
                    class="text-sm font-medium text-gray-400 uppercase tracking-wider"
                >
                    Resources Found
                </h4>
                <div class="grid grid-cols-2 gap-2">
                    {#each Object.entries(resources) as [resource, quantity]}
                        <div
                            class="flex items-center gap-2 p-2 bg-white/5 rounded"
                        >
                            <div
                                class="w-8 h-8 rounded bg-gradient-to-br from-green-500/20 to-emerald-500/20 flex items-center justify-center"
                            >
                                <span class="text-xs">💎</span>
                            </div>
                            <div class="flex-1">
                                <div class="text-xs text-gray-400">
                                    {resource}
                                </div>
                                <div class="text-sm font-medium text-green-400">
                                    {quantity}
                                </div>
                            </div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <!-- Exploration Features -->
        {#if explorationFeatures.length > 0}
            <div class="space-y-2">
                <h4
                    class="text-sm font-medium text-gray-400 uppercase tracking-wider"
                >
                    Features
                </h4>
                <div class="grid gap-2">
                    {#each explorationFeatures as feature}
                        <div
                            class="flex items-start gap-3 p-3 bg-white/5 rounded-lg hover:bg-white/10 transition-colors group"
                        >
                            <div
                                class="w-10 h-10 rounded-lg bg-gradient-to-br from-green-500/20 to-emerald-500/20 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform"
                            >
                                <svg
                                    class="w-5 h-5 text-green-400"
                                    fill="none"
                                    stroke="currentColor"
                                    viewBox="0 0 24 24"
                                >
                                    <path
                                        stroke-linecap="round"
                                        stroke-linejoin="round"
                                        stroke-width="2"
                                        d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"
                                    />
                                </svg>
                            </div>
                            <div class="flex-1">
                                <div class="text-sm text-white font-medium">
                                    {feature.name || feature}
                                </div>
                                {#if feature.description}
                                    <div class="text-xs text-gray-400 mt-1">
                                        {feature.description}
                                    </div>
                                {/if}
                            </div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </div>

    <svelte:fragment slot="footer">
        <div class="flex items-center justify-between">
            <button
                class="text-green-400 hover:text-green-300 transition-colors flex items-center gap-2 group"
            >
                <svg
                    class="w-5 h-5 transition-transform group-hover:rotate-12"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                    />
                </svg>
                <span class="text-sm font-medium">Explore Map</span>
            </button>
            <button
                class="px-3 py-1.5 bg-green-500/20 hover:bg-green-500/30 text-green-400 text-sm font-medium rounded-lg transition-all border border-green-500/30"
            >
                Set Waypoint
            </button>
        </div>
    </svelte:fragment>
</BaseCard>

<style>
    .exploration-card {
        position: relative;
        overflow: hidden;
    }

    .exploration-card::before {
        content: "";
        position: absolute;
        top: -100px;
        right: -100px;
        width: 200px;
        height: 200px;
        background: radial-gradient(
            circle,
            rgba(34, 197, 94, 0.1) 0%,
            transparent 70%
        );
        animation: rotate 20s linear infinite;
        pointer-events: none;
    }

    @keyframes rotate {
        from {
            transform: rotate(0deg);
        }
        to {
            transform: rotate(360deg);
        }
    }

    @keyframes shimmer {
        0% {
            transform: translateX(-100%);
        }
        100% {
            transform: translateX(100%);
        }
    }

    :global(.animate-shimmer) {
        animation: shimmer 2s infinite;
    }
</style>
