<script>
    import BaseCard from "./BaseCard.svelte";

    /**
     * BuildingCard component
     * Displays construction and base-building features
     *
     * Props:
     * - title: Card title
     * - subtitle: Building category
     * - description: Feature description
     * - image: Building artwork URL
     * - structures: Array of available structures { name, cost, built, max }
     * - resources: Object of available resources { name: quantity }
     * - buildQueue: Array of items currently being built { name, progress, timeLeft }
     * - totalBuildings: Total number of buildings constructed
     * - powerUsage: Current power usage { used, total }
     * - class: Additional CSS classes
     */
    let {
        title = "Building",
        subtitle = "Construct Your Base",
        description = "",
        image = "",
        structures = [],
        resources = {},
        buildQueue = [],
        totalBuildings = 0,
        powerUsage = { used: 0, total: 0 },
        class: additionalClasses = "",
        ...restProps
    } = $props();

    const buildingIcon = `<path d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />`;

    let powerPercentage = $derived(
        powerUsage.total > 0 ? (powerUsage.used / powerUsage.total) * 100 : 0,
    );
    let isPowerCritical = $derived(powerPercentage > 90);
</script>

<BaseCard
    {title}
    {subtitle}
    {description}
    {image}
    icon={buildingIcon}
    gradient={{
        from: "rgba(168, 85, 247, 0.05)",
        to: "rgba(236, 72, 153, 0.05)",
    }}
    class="building-card {additionalClasses}"
    {...restProps}
>
    <div class="space-y-4">
        <!-- Build Stats -->
        {#if totalBuildings > 0}
            <div
                class="flex items-center justify-between p-3 bg-gradient-to-r from-purple-500/10 to-pink-500/10 rounded-lg border border-purple-500/20"
            >
                <span class="text-sm text-gray-400">Total Structures</span>
                <span class="text-2xl font-bold text-purple-300"
                    >{totalBuildings}</span
                >
            </div>
        {/if}

        <!-- Power Usage -->
        {#if powerUsage.total > 0}
            <div class="space-y-2">
                <div class="flex justify-between text-sm">
                    <span class="text-gray-400">Power Usage</span>
                    <span
                        class="font-medium"
                        class:text-red-400={isPowerCritical}
                        class:text-purple-300={!isPowerCritical}
                    >
                        {powerUsage.used}MW / {powerUsage.total}MW
                    </span>
                </div>
                <div
                    class="w-full bg-black/30 rounded-full h-2 overflow-hidden"
                >
                    <div
                        class="h-full rounded-full transition-all duration-500 ease-out"
                        class:bg-gradient-to-r={!isPowerCritical}
                        class:from-purple-500={!isPowerCritical}
                        class:to-pink-500={!isPowerCritical}
                        class:bg-red-500={isPowerCritical}
                        class:animate-pulse={isPowerCritical}
                        style="width: {powerPercentage}%"
                    ></div>
                </div>
            </div>
        {/if}

        <!-- Build Queue -->
        {#if buildQueue.length > 0}
            <div class="space-y-2">
                <h4
                    class="text-sm font-medium text-gray-400 uppercase tracking-wider"
                >
                    Build Queue
                </h4>
                <div class="space-y-2">
                    {#each buildQueue as item}
                        <div class="p-3 bg-white/5 rounded-lg">
                            <div class="flex items-center justify-between mb-2">
                                <span class="text-sm font-medium text-white"
                                    >{item.name}</span
                                >
                                <span class="text-xs text-purple-400"
                                    >{item.timeLeft}</span
                                >
                            </div>
                            <div
                                class="w-full bg-black/30 rounded-full h-1.5 overflow-hidden"
                            >
                                <div
                                    class="h-full bg-gradient-to-r from-purple-500 to-pink-500 rounded-full transition-all duration-300"
                                    style="width: {item.progress}%"
                                ></div>
                            </div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <!-- Available Structures -->
        {#if structures.length > 0}
            <div class="space-y-2">
                <h4
                    class="text-sm font-medium text-gray-400 uppercase tracking-wider"
                >
                    Structures
                </h4>
                <div class="grid gap-2">
                    {#each structures as structure}
                        <div
                            class="flex items-center justify-between p-2 bg-white/5 rounded hover:bg-white/10 transition-colors"
                        >
                            <div class="flex items-center gap-3">
                                <div
                                    class="w-10 h-10 rounded bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center"
                                >
                                    <svg
                                        class="w-5 h-5 text-purple-400"
                                        fill="none"
                                        stroke="currentColor"
                                        viewBox="0 0 24 24"
                                    >
                                        <path
                                            stroke-linecap="round"
                                            stroke-linejoin="round"
                                            stroke-width="2"
                                            d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
                                        />
                                    </svg>
                                </div>
                                <div>
                                    <div class="text-sm font-medium text-white">
                                        {structure.name}
                                    </div>
                                    {#if structure.built !== undefined && structure.max !== undefined}
                                        <div class="text-xs text-gray-500">
                                            {structure.built}/{structure.max} built
                                        </div>
                                    {/if}
                                </div>
                            </div>
                            {#if structure.cost}
                                <button
                                    class="px-3 py-1 bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 text-xs font-medium rounded transition-all"
                                    disabled={structure.built >= structure.max}
                                >
                                    {structure.cost}
                                </button>
                            {/if}
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <!-- Resources -->
        {#if Object.keys(resources).length > 0}
            <div class="space-y-2">
                <h4
                    class="text-sm font-medium text-gray-400 uppercase tracking-wider"
                >
                    Resources
                </h4>
                <div class="grid grid-cols-3 gap-2">
                    {#each Object.entries(resources) as [resource, quantity]}
                        <div class="text-center p-2 bg-white/5 rounded">
                            <div class="text-lg font-bold text-purple-300">
                                {quantity}
                            </div>
                            <div class="text-xs text-gray-500">{resource}</div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </div>

    <svelte:fragment slot="footer">
        <div class="flex gap-2">
            <button
                class="flex-1 px-3 py-2 bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 text-white font-medium rounded-lg transition-all hover:shadow-lg"
            >
                Build Mode
            </button>
            <button
                class="px-3 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition-all border border-white/20"
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
                        d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                    />
                    <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                    />
                </svg>
            </button>
        </div>
    </svelte:fragment>
</BaseCard>

<style>
    .building-card {
        position: relative;
    }

    .building-card::after {
        content: "";
        position: absolute;
        bottom: -50px;
        left: 50%;
        transform: translateX(-50%);
        width: 150px;
        height: 150px;
        background: radial-gradient(
            circle,
            rgba(168, 85, 247, 0.15) 0%,
            transparent 70%
        );
        animation: pulse-slow 4s ease-in-out infinite;
        pointer-events: none;
    }

    @keyframes pulse-slow {
        0%,
        100% {
            opacity: 0.3;
            transform: translateX(-50%) scale(0.8);
        }
        50% {
            opacity: 0.6;
            transform: translateX(-50%) scale(1.2);
        }
    }
</style>
