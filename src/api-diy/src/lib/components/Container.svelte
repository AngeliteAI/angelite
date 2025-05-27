<script>
    import VDom from "$lib/VDom.svelte";
    import { createEventDispatcher } from "svelte";
    import { virtualScale } from "$lib/store";
    let {
        children,
        activeVDom = $bindable(),
        showBlueprintMode = false,
        cameraX = 0,
        cameraY = 0,
        mouseX = 0,
        mouseY = 0,
        offsetX = 0,
        offsetY = 0,
        // Viewport dimensions
        width = 1179,
        height = 2556,
    } = $props();

    // Track the VDom's internal state
    let vdomNodes = $state({});
    let vdomUpdateCount = $state(0);
    let currentScale = $state($virtualScale);

    const dispatch = createEventDispatcher();
    function handleNodeEvent(event, detail) {
        dispatch(event, detail);
    }
</script>

<div
    class="virtual-container"
    style="--camera-x: {cameraX}px; --camera-y: {cameraY}px; --offset-x: {offsetX}px; --offset-y: {offsetY}px;"
>
    <main
        class="virtual-content"
        style="--virtual-width: {width}px; --virtual-height: {height}px;"
        data-document="true"
    >
        <!-- Root node with all children -->
        <VDom
            bind:this={activeVDom}
            bind:nodes={vdomNodes}
            bind:updateCount={vdomUpdateCount}
            {showBlueprintMode}
            {currentScale}
        />
        <!-- Snap grid guide (subtle visual cue) -->
        <div class="snap-grid"></div>

        <!-- Information text at the bottom -->
        <div class="text-sm text-gray-500 mt-8 opacity-50">
            • <strong>Drag the gray background</strong> to move the camera view<br
            />
            • <strong>Drag this white area</strong> to pan the page content<br
            />
            • <strong>Click individual elements</strong> to select them<br />
            •
            <strong
                >{showBlueprintMode
                    ? "Blueprint view"
                    : "Actual design view"}</strong
            > is currently active
        </div>

        <!-- Forward slot content if any -->
        {#if children}
            {@render children()}
        {/if}
    </main>
</div>

<style>
    .virtual-container {
        position: relative;
        display: block;
        transform: translate(var(--camera-x, 0px), var(--camera-y, 0px));
        cursor: move;
        touch-action: none;
        will-change: transform;
    }

    .virtual-content {
        position: relative;
        background: white;
        width: var(--virtual-width);
        height: var(--virtual-height);
        transition:
            width 0.2s ease-in-out,
            height 0.2s ease-in-out;
        cursor: grab;
        box-shadow: 0 0 20px rgba(0, 0, 0, 0.2);
        border-radius: 8px;
        overflow: hidden;
        touch-action: none;
        user-select: none;
        transform: translate(
            calc(var(--offset-x, 0px)),
            calc(var(--offset-y, 0px))
        );
    }

    .virtual-content:active {
        cursor: grabbing;
    }
</style>
