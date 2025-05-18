<script lang="ts">
    import { virtualScale, mouseX, mouseY } from "$lib/store";
    let {
        children,
        selectedNodeId,
    } = $props();
    let currentScale = $state($virtualScale);
    var offsetX = 0;
    var offsetY = 0;

    import { createEventDispatcher, onMount } from "svelte";
    import Document from "./Document.svelte";
    import Draggable from "./Draggable.svelte";
    const dispatch = createEventDispatcher();

    // Handle node events and forward them up to parent
    function handleNodeEvent(event: string, detail: any): void {
        // Forward the event with its detail to parent
        dispatch(event, detail);
    }
    var showBlueprintMode = false;
    var w = $state(),
        h = $state();
    // Get the current VDOM state
    var position = $state({ x: 0, y: 0 });

    var modified = $derived({
        x: position.x / currentScale + offsetX,
        y: position.y / currentScale + offsetY,
    });
    var localVirtualScale = $derived($virtualScale);
</script>

<div
    id="viewport"
    bind:clientWidth={w}
    bind:clientHeight={h}
    onwheel={(e) => {
        // Get mouse position relative to the viewport
        const rect = e.currentTarget.getBoundingClientRect();
        const localMouseX = e.clientX - rect.left - w / 2;
        const localMouseY = e.clientY - rect.top;

        mouseX.set(localMouseX);
        mouseY.set(localMouseY);

        // Calculate scale change
        const oldScale = currentScale;
        currentScale *= e.deltaY > 0 ? 1 / 1.05 : 1.05;
        currentScale = Math.max(Math.min(currentScale, 5), 0.1);
        virtualScale.set(currentScale);
        console.log(currentScale);

        // Calculate the shift required for zoom-on-mouse
        offsetX += (($mouseX - offsetX) * (oldScale / currentScale - 1)) / oldScale * currentScale; 
        offsetY += (($mouseY - offsetY) * (oldScale / currentScale - 1)) / oldScale * currentScale;

        e.preventDefault();
    }}
>
    <Draggable bind:position absolute={true} screenspace={true}>
        <div
            id="camera"
            class="absolute"
            style="width: {w}px; height: {h}px; transform: translate({-position.x }px, {-position.y}px); left: 0; right: 0; top: 0; bottom: 0;"
        >
            <div
                style="transform: translate({modified.x}px, {modified.y}px) scale({localVirtualScale});"
            >
                {@render children()}
            </div>
        </div>
    </Draggable>
</div>

<style>
    #viewport {
        background-color: #f9fafb;
        background-image:
            linear-gradient(rgba(0, 0, 0, 0.05) 1px, transparent 1px),
            linear-gradient(90deg, rgba(0, 0, 0, 0.05) 1px, transparent 1px);
        background-size: 20px 20px;
        position: relative;
        width: 100%;
        height: 100%;
        overflow: auto;
    }
</style>
