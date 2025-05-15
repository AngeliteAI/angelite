<script lang="ts">
    import Node from "../Node.svelte";

    // Props - using $props() rune syntax
    var {
        activeVDom = $bindable(),
        selectedNodeId = $bindable(),
        showBlueprintMode = false,
        cameraX = 0,
        cameraY = 0,
        mouseX = 0,
        mouseY = 0,
        virtualScale = 0.2,
        offsetX = 0,
        offsetY = 0,
        // Viewport dimensions
        width = 1179,
        height = 2556,
    } = $props();

    // State for dragging
    let isDragging = $state(false);
    let startX = $state(0);
    let startY = $state(0);

    // Pass events up to parent
    import Draggable from "./Draggable.svelte";
    import Container from "./Container.svelte";
    import { onMount } from "svelte";
    $effect(() => {
        if (!isDragging) {
            startX = mouseX;
            startY = mouseY;
        }
    });
</script>

<Draggable {mouseX} {mouseY} {startX} {startY}>
    <div
        class=""
        on:click={() => {
            isDragging = true;
            console.log("deez");
        }}
    >
        <Container
            bind:activeVDom
            bind:selectedNodeId
            {cameraX}
            {cameraY}
            {mouseX}
            {mouseY}
            {offsetX}
            {offsetY}
            {width}
            {height}
            {virtualScale}
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
