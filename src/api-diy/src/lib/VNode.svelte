<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import Draggable from "./components/Draggable.svelte";
    import Snappable from "./components/Snappable.svelte";

    // Props
    let {
        id,
        nodes,
        selectedNodeId = $bindable<string | null>(null), 
        showBlueprintMode = $bindable(false),
        updateCount = 0
    } = $props();

    // Event handling
    const dispatch = createEventDispatcher();

    // Helper to convert camelCase to kebab-case for CSS properties
    function camelToKebab(str: string) {
        return str.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
    }

    // Handle node selection
    function handleClick(event: MouseEvent) {
        // Get the element under the exact click position
        const elemUnderClick = document.elementFromPoint(
            event.clientX,
            event.clientY
        );
        
        // Find closest node element from click position
        const nodeUnderClick = elemUnderClick?.closest("[data-node-id]");
        
        // If we clicked a different child node, let it handle the event
        if (
            nodeUnderClick && 
            nodeUnderClick !== event.currentTarget &&
            event.currentTarget.contains(nodeUnderClick)
        ) {
            return;
        }
        
        // We're the actual target, so handle it
        event.stopPropagation();
        
        // Select this node
        selectedNodeId = id;
        dispatch("select", { id });
    }
    
    // Check if current node is selected
    function isSelected() {
        return id === selectedNodeId;
    }
    
    // Get node data
    $effect(() => {
        // This ensures we re-run this effect when updateCount changes
        updateCount;
    });
</script>


<Snappable>
<div
    class="vnode static h-max {nodes[id]?.tagName || 'div'}"
    class:root={!nodes[id]?.parentId}
    class:selected={isSelected()}
    class:blueprint={showBlueprintMode}
    data-node-id={id}
    data-node-type={nodes[id]?.tagName || 'div'}
    on:click={handleClick}
    role="button"
    tabindex="0"
    style={Object.entries(nodes[id]?.styles || {})
        .map(([k, v]) => `${camelToKebab(k)}: ${v}`)
        .join("; ")}
>
    <!-- Debug label when in blueprint mode -->
    {#if showBlueprintMode}
        <div class="node-debug">
            <span class="tag-name">&lt;{nodes[id]?.tagName || 'div'}&gt;</span>
            <span class="children-count">[{nodes[id]?.children?.length || 0} children]</span>
        </div>
    {/if}
    
    <!-- Node content -->
    {#if nodes[id]?.props?.textContent}
        <span class="text-content">{nodes[id].props.textContent}</span>
    {/if}

    <!-- Recursively render children -->
    {#if nodes[id]?.children?.length > 0}
        <div class="children static">
            {#each nodes[id].children as childId (childId)}
                <svelte:self
                    id={childId}
                    {nodes}
                    {selectedNodeId}
                    {showBlueprintMode}
                    {updateCount}
                    on:select
                />
            {/each}
        </div>
    {/if}
</div>
</Snappable>

<style>
    .vnode {
        position: relative;
        min-height: 30px;
        min-width: 30px;
        box-sizing: border-box;
        transition: 
            background-color 0.15s ease,
            outline 0.15s ease;
        z-index: 1;
        border: 1px solid rgba(100, 100, 100, 0.2);
        padding: 8px;
        margin: 2px;
    }
    
    .root {
        width: 100%;
        height: 100%;
    }
    
    .node-debug {
        position: absolute;
        top: -12px;
        left: 0;
        font-size: 10px;
        background: #334155;
        color: white;
        padding: 1px 4px;
        border-radius: 2px;
        z-index: 5;
    }
    
    .selected {
        outline: 2px solid #4299e1;
        z-index: 10;
        box-shadow: 0 0 0 2px rgba(66, 153, 225, 0.5);
    }
    
    .blueprint {
        border: 1px dashed #536b8b;
        padding: 6px;
        margin: 4px;
        background-color: rgba(165, 214, 255, 0.2);
        border-radius: 4px;
    }
    
    .text-content {
        word-break: break-word;
    }
    
    .children {
        margin-left: 10px;
        position: relative;
        z-index: 2;
    }
    
    .children .vnode {
        z-index: 2;
    }
    
    .tag-name {
        color: #a5b4fc;
        font-weight: bold;
    }
    
    .children-count {
        font-size: 9px;
        color: #a5f3fc;
        margin-left: 4px;
    }
</style>