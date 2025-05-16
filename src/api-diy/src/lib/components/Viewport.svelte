<script lang="ts">
    let {
        children,
        virtualScale = 0.2,
        selectedNodeId,
        mouseX,
        mouseY,
    } = $props();
    import Node from "../Node.svelte";

    import { createEventDispatcher } from "svelte";
    import Document from "./Document.svelte";
    const dispatch = createEventDispatcher();

    // Handle node events and forward them up to parent
    function handleNodeEvent(event: string, detail: any): void {
        // Forward the event with its detail to parent
        dispatch(event, detail);
    }
    var showBlueprintMode = false;

    // Get the current VDOM state
</script>

<div id="viewport">
    <div style="transform: scale({virtualScale});">
        {@render children()}
    </div>
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
