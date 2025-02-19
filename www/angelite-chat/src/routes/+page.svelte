<script>
    import DotGrid from "$lib/DotGrid.svelte";
    import Input from "$lib/Input.svelte";
    let message = "";

    /** @type {Array<{text: string, sent: boolean}>} */
    let events = [
        { message: { text: "yo", sent: false } },
        { message: { text: "deez", sent: true } },
        { matrix: {} },
    ];

    function handleSubmit() {
        if (message.trim()) {
            var message = {
                message: { text: message, sent: true },
            };
            events = [...events, message];
            message = "";
        }
    }

    function handleKeydown(/** @type {KeyboardEvent} */ e) {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            handleSubmit();
        }
    }

    function generateExponentialTriangle() {
        /** @type {Array<[number, number, string]>} */
        const points = [];
        let currentRow = 0;
        let dotsInRow = 2;

        while (dotsInRow <= 64) {
            const startX = -Math.floor(dotsInRow / 2);
            for (let i = 0; i < dotsInRow; i++) {
                points.push([startX + i, currentRow, "#ffffff"]);
            }
            currentRow++;
            dotsInRow *= 2;
        }
        return points;
    }

    const trianglePoints = generateExponentialTriangle();
</script>

<div class="flex flex-col h-screen">
    <!-- Fixed Header -->
    <header class="h-16 flex items-center bg-space z-10 px-4">
        <h1 class="text-2xl">Angelite</h1>
    </header>

    <!-- Scrollable Message Area -->
    <div class="flex-1 overflow-y-auto px-4">
        <div class="flex flex-col max-w-150 gap-4 mx-auto">
            {#each events as ev}
                {#if ev.message}
                    <div
                        class="w-full flex {ev.message.sent
                            ? 'justify-end'
                            : 'justify-start'}"
                    >
                        <div
                            class="{ev.message.sent
                                ? '!border border-day border-1 border-solid'
                                : 'bg-angelite'}
                          rounded-2xl !py-2 !px-4
                          shadow-lg backdrop-blur-sm
                          transform transition-all duration-300 ease-out
                          min-w-[80%] max-w-[80%]
                          {ev.message.sent ? 'rounded-br-sm' : 'rounded-bl-sm'}"
                        >
                            {ev.message.text}
                        </div>
                    </div>
                {:else if ev.matrix}{/if}
            {/each}
        </div>
    </div>

    <!-- Fixed Input Area -->
    <div class="sticky bottom-0 px-4 py-4 bg-space">
        <div class="max-w-150 mx-auto">
            <Input
                bind:value={message}
                label="Start the conversation"
                placeholder=""
                on:keydown={handleKeydown}
            />
        </div>
    </div>
</div>

<style>
    .message-bubble {
        animation: float-up 0.3s ease-out;
    }

    @keyframes float-up {
        from {
            opacity: 0;
            transform: translateY(20px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
</style>
