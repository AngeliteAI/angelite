<script lang="ts">
    // Root component that manages the VDom
    import { onMount } from "svelte";

    // Props - only make selectedNodeId bindable
    let {
        vdom,
        selectedNodeId = $bindable(null),
        draggedElementId = null,
        currentX = 0,
        currentY = 0,
        showBlueprintMode = false,
    } = $props();

    // Handle any necessary previous props for backward compatibility
    let x = $derived(currentX);
    let y = $derived(currentY);
    let draggingNodeId = $derived(draggedElementId);

    // Handle global node selection events
    function handleNodeSelected(e: CustomEvent) {
        if (e.detail && e.detail.id) {
            selectedNodeId = e.detail.id;
            console.log("Selection updated in Dom:", selectedNodeId);
        }
    }

    // Add global event listeners for selection
    onMount(() => {
        document.addEventListener(
            "node-selected",
            handleNodeSelected as EventListener,
        );
        return () => {
            document.removeEventListener(
                "node-selected",
                handleNodeSelected as EventListener,
            );
        };
    });

    // Debug
    $effect(() => {
        console.log("Dom render - vdom:", vdom);
        console.log("Root node ID:", vdom?.rootNodeId);
        console.log("Nodes size:", vdom?.nodes?.size);
        console.log("Current selected node:", selectedNodeId);
    });

    function getRoot() {
        if (!vdom || !vdom.rootNodeId || !vdom.nodes) {
            return null;
        }
        const rootNode = vdom.nodes.get(vdom.rootNodeId);
        console.log("Root node:", rootNode);
        return rootNode;
    }

    $effect(() => {
        console.log("vdom updated", vdom);
    });
</script>

<div class="vdom-container">
    {#if getRoot()}
        <Node
            node={getRoot()}
            {vdom}
            bind:selectedNodeId
            bind:x
            bind:y
            bind:draggingNodeId
            isReorderable={true}
            {showBlueprintMode}
        />
    {:else}
        <div class="no-vdom">No virtual DOM to render yet</div>
    {/if}
</div>

{#if selectedNodeId}
    <div class="selection-indicator">
        Node selected: {selectedNodeId}
    </div>
{/if}

<style>
    .vdom-container {
        width: 100%;
        padding: 10px;
        background: #f8f8f8;
        border-radius: 4px;
        position: relative;
    }

    .no-vdom {
        padding: 20px;
        color: #00ccff;
        background: #eeefff;
        border: 1px solid #ccccff;
        text-align: center;
        border-radius: 4px;
    }

    .selection-indicator {
        position: fixed;
        bottom: 20px;
        left: 20px;
        background: rgba(59, 130, 246, 0.9);
        color: white;
        padding: 8px 12px;
        border-radius: 4px;
        font-size: 12px;
        z-index: 1000;
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
        pointer-events: none;
    }
</style>
