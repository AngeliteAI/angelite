<script lang="ts">
    import { virtualScale, mouseX, mouseY } from "$lib/store";
    let {
        children,
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
    var w = $state(0),
        h = $state(0);
    // Get the current VDOM state
    var position = $state({ x: 0, y: 0 });
    var lastPos = $state(0)

    var modified = $derived({
        x: position.x / $virtualScale + offsetX,
        y: position.y / $virtualScale + offsetY,
    });
    var origin = $derived({
        x: position.x / $virtualScale + offsetX,
        y: position.y / $virtualScale + offsetY,

    });
    var localVirtualScale = $derived($virtualScale);
    var min = 0.05;
    var max = 10.0;
    var backgroundScale = $derived($virtualScale * 20);
</script>

<div
    id="viewport"
    style="--scale-x: {backgroundScale}%; --scale-y: {backgroundScale * w / h}%; --origin-x: {origin.x + w / 2}px; --origin-y: {origin.y}px;"
    bind:clientWidth={w}
    bind:clientHeight={h}
    role="region"
    onmousemove={(e) => {
        const rect = e.currentTarget.getBoundingClientRect();
const storeMouseX = e.clientX - rect.left - w / 2;
        const storeMouseY = e.clientY - rect.top;
        mouseX.set(storeMouseX);
        mouseY.set(storeMouseY);
    }}
    onwheel={(e) => {
        // Get mouse position relative to the viewport
        const rect = e.currentTarget.getBoundingClientRect();
        
        const zoomCalcMouseX = e.clientX - rect.left - w / 2;
        const zoomCalcMouseY = e.clientY - rect.top; // This is identical to storeMouseY

        const oldScale = currentScale;
        currentScale *= e.deltaY > 0 ? 1 / 1.05 : 1.05;
        currentScale = Math.max(Math.min(currentScale, 5), 0.1);
        virtualScale.set(currentScale);

        const S_prime = oldScale; // Scale before zoom
        const S_new = currentScale;   // Scale after zoom

        const px_drag = position.x; // Viewport's current drag offset X
        const py_drag = position.y; // Viewport's current drag offset Y

        const ox_old = offsetX;     // Content's pan offset X before this zoom
        const oy_old = offsetY;     // Content's pan offset Y before this zoom

        const c_mouse_x = (zoomCalcMouseX - px_drag/S_prime - ox_old) / S_prime;
        const c_mouse_y = (zoomCalcMouseY - py_drag/S_prime - oy_old) / S_prime;

        offsetX = zoomCalcMouseX - px_drag/S_new - c_mouse_x * S_new;
        offsetY = zoomCalcMouseY - py_drag/S_new - c_mouse_y * S_new;

        e.preventDefault();
    }}
>
    <Draggable bind:position screenspace={true}>
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
        background-size: var(--scale-x) var(--scale-y);
        background-position: var(--origin-x) var(--origin-y);
        position: relative;
        width: 100%;
        height: 100%;
        overflow: hidden;
    }
</style>
