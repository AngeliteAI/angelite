<script>
    import BaseCard from "./BaseCard.svelte";

    /**
     * MultiplayerCard component
     * Displays social features and player interaction options
     *
     * Props:
     * - title: Card title
     * - subtitle: Social feature category
     * - description: Feature description
     * - image: Feature image URL
     * - playerCount: Current player count
     * - maxPlayers: Maximum players supported
     * - modes: Array of multiplayer modes
     * - features: Array of social features
     * - friendsOnline: Number of friends currently online
     * - class: Additional CSS classes
     */
    let {
        title = "Multiplayer",
        subtitle = "Play Together",
        description = "",
        image = "",
        playerCount = 0,
        maxPlayers = 0,
        modes = [],
        features = [],
        friendsOnline = 0,
        class: additionalClasses = "",
        ...restProps
    } = $props();

    const multiplayerIcon = `<path d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />`;
</script>

<BaseCard
    {title}
    {subtitle}
    {description}
    {image}
    icon={multiplayerIcon}
    gradient={{
        from: "rgba(59, 130, 246, 0.05)",
        to: "rgba(6, 182, 212, 0.05)"
    }}
    class="multiplayer-card {additionalClasses}"
    {...restProps}
>
    <div class="space-y-4">
        <!-- Player Count Display -->
        {#if playerCount > 0 || maxPlayers > 0}
            <div class="flex items-center justify-between p-3 bg-gradient-to-r from-blue-500/10 to-cyan-500/10 rounded-lg border border-blue-500/20">
                <div class="flex items-center gap-2">
                    <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                    <span class="text-sm text-gray-300">Players Online</span>
                </div>
                <span class="text-lg font-bold text-blue-300">
                    {playerCount.toLocaleString()}{maxPlayers ? `/${maxPlayers.toLocaleString()}` : ''}
                </span>
            </div>
        {/if}

        <!-- Friends Online -->
        {#if friendsOnline > 0}
            <div class="flex items-center gap-3 p-2 rounded bg-cyan-500/10">
                <svg class="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
                <span class="text-sm">
                    <span class="text-cyan-400 font-medium">{friendsOnline}</span>
                    <span class="text-gray-400"> friends online</span>
                </span>
            </div>
        {/if}

        <!-- Game Modes -->
        {#if modes.length > 0}
            <div class="space-y-2">
                <h4 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Game Modes</h4>
                <div class="grid grid-cols-2 gap-2">
                    {#each modes as mode}
                        <button class="p-3 bg-white/5 hover:bg-white/10 rounded-lg border border-white/10 hover:border-blue-500/50 transition-all group">
                            <div class="flex items-center gap-2">
                                <div class="w-8 h-8 rounded bg-gradient-to-br from-blue-500/20 to-cyan-500/20 flex items-center justify-center group-hover:scale-110 transition-transform">
                                    <svg class="w-4 h-4 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                                        <path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z" />
                                    </svg>
                                </div>
                                <span class="text-sm text-gray-300 font-medium">{mode}</span>
                            </div>
                        </button>
                    {/each}
                </div>
            </div>
        {/if}

        <!-- Social Features -->
        {#if features.length > 0}
            <div class="space-y-2">
                <h4 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Features</h4>
                <div class="space-y-1">
                    {#each features as feature}
                        <div class="flex items-center gap-2 text-sm text-gray-300">
                            <svg class="w-4 h-4 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                            </svg>
                            <span>{feature}</span>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </div>

    <svelte:fragment slot="footer">
        <div class="flex gap-3">
            <button class="flex-1 px-4 py-2 bg-gradient-to-r from-blue-500 to-cyan-500 hover:from-blue-600 hover:to-cyan-600 text-white font-medium rounded-lg transition-all hover:shadow-lg">
                Find Match
            </button>
            <button class="px-4 py-2 bg-white/10 hover:bg-white/20 text-white font-medium rounded-lg transition-all border border-white/20">
                Invite Friends
            </button>
        </div>
    </svelte:fragment>
</BaseCard>

<style>
    .multiplayer-card {
        position: relative;
    }

    .multiplayer-card::after {
        content: '';
        position: absolute;
        top: 0;
        right: 0;
        width: 100px;
        height: 100px;
        background: radial-gradient(circle, rgba(59, 130, 246, 0.2) 0%, transparent 70%);
        border-radius: 50%;
        animation: float 6s ease-in-out infinite;
        pointer-events: none;
    }

    @keyframes float {
        0%, 100% {
            transform: translate(0, 0);
        }
        33% {
            transform: translate(-10px, -10px);
        }
        66% {
            transform: translate(5px, -5px);
        }
    }
</style>
