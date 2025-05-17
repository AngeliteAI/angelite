<script lang="ts">
    let {
        children,
        virtualScale = $bindable(1),
        selectedNodeId,
        mouseX,
        mouseY,
    } = $props();
    var offsetX = 0;
    var offsetY = 0;
    import Node from "../Node.svelte";

    import { createEventDispatcher } from "svelte";
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
        x: position.x * virtualScale + offsetX,
        y: position.y * virtualScale + offsetY,
    });
</script>

<div
    id="viewport"
    bind:clientWidth={w}
    bind:clientHeight={h}
    onwheel={(e) => {
        // Get mouse position relative to the viewport
        const rect = e.currentTarget.getBoundingClientRect();
        const mouseX = e.clientX - rect.left - w / 2;
        const mouseY = e.clientY - rect.top;

        // Calculate scale change
        const oldScale = virtualScale;
        virtualScale *= e.deltaY > 0 ? 1 / 1.05 : 1.05;
        virtualScale = Math.max(Math.min(virtualScale, 5), 0.1);

        // Calculate the shift required for zoom-on-mouse
        offsetX +=
            (((mouseX - offsetX) * (oldScale / virtualScale - 1)) / oldScale) *
            virtualScale;
        offsetY +=
            (((mouseY - offsetY) * (oldScale / virtualScale - 1)) / oldScale) *
            virtualScale;

        e.preventDefault();
    }}
>
    <Draggable bind:position>
        <div
            id="camera"
            class="absolute"
            style="width: {w}px; height: {h}px; transform: translate({-position.x}px, {-position.y}px); left: 0; right: 0; top: 0; bottom: 0;"
        >
            <div
                style="transform: translate({modified.x}px, {modified.y}px) scale({virtualScale});"
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
