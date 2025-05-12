<script lang="ts">
    // Root component that manages the VDom
    import Node from './Node.svelte';
    import { VDom } from './VDom.svelte';
    
    // Props - only make selectedNodeId bindable
    let { 
        vdom, 
        selectedNodeId = $bindable(null),
        draggedElementId = null,
        currentX = 0,
        currentY = 0
    } = $props();
    
    // Handle any necessary previous props for backward compatibility
    let x = $derived(currentX);
    let y = $derived(currentY);
    let draggingNodeId = $derived(draggedElementId);
    
    // Debug
    $effect(() => {
        console.log("Dom render - vdom:", vdom);
        console.log("Root node ID:", vdom?.rootNodeId);
        console.log("Nodes size:", vdom?.nodes?.size);
    });
    
    function getRoot() {
        if (!vdom || !vdom.rootNodeId || !vdom.nodes) {
            return null;
        }
        const rootNode = vdom.nodes.get(vdom.rootNodeId);
        console.log("Root node:", rootNode);
        return rootNode;
    }
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
        />
    {:else}
        <div class="no-vdom">No virtual DOM to render yet</div>
    {/if}
</div>

<style>
    .vdom-container {
        width: 100%;
        padding: 10px;
        background: #f8f8f8;
        border-radius: 4px;
    }
    
    .no-vdom {
        padding: 20px;
        color: #00ccff;
        background: #eeefff;
        border: 1px solid #ccccff;
        text-align: center;
        border-radius: 4px;
    }
</style>