<script lang="ts">
    // Props - using $props() rune syntax
    import { virtualScale } from "$lib/store";
    var {
        activeVDom = $bindable(),
        showBlueprintMode = false,
        cameraX = 0,
        cameraY = 0,
        mouseX = 0,
        mouseY = 0,
        offsetX = 0,
        offsetY = 0,
        // Viewport dimensions
        width = 0,
        height = 0,
    } = $props();

    // Use the store value directly
    let currentVirtualScale = $state($virtualScale);

    // State for dragging
    let isDragging = $state(false);
    let startX = $state(0);
    let startY = $state(0);

    // Pass events up to parent
    import Draggable from "./Draggable.svelte";
    import Container from "./Container.svelte";
    import { onMount } from "svelte";
    import { stopPropagation } from "svelte/legacy";
    $effect(() => {
        if (!isDragging) {
            startX = mouseX;
            startY = mouseY;
        }
    });
    var draggableComponent = $state();
</script>

<Draggable bind:this={draggableComponent} absolute={true}>
    <div
        onmousedown={(e) => {
            draggableComponent.startDrag(e);
        }}
    >
        <Container
            bind:activeVDom
            {cameraX}
            {cameraY}
            {mouseX}
            {mouseY}
            {offsetX}
            {offsetY}
            {width}
            {height}
        ></Container>
    </div>
</Draggable>

<style>
    /* Simple styles */

    /* Make the document respond to dragged nodes */
    :global(.virtual-content.drag-active) {
        outline: 2px dashed rgba(59, 130, 246, 0.3);
    }
</style>
