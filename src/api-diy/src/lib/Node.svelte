<script lang="ts">
    import { VNode, VDom, updateDraggedElement, updateDraggedPosition } from './VDom.svelte';
    
    // Props
    let { 
        node, 
        vdom,
        selectedNodeId = $bindable(null),
        x = $bindable(0),
        y = $bindable(0),
        draggingNodeId = $bindable(null),
        isReorderable = false  // Add new prop
    } = $props();
    
    // Logic to render the node and its children
    $effect(() => {
        console.log(`Node ${node?.id} render`, node);
    });
    
    function isSelected() {
        return selectedNodeId === node?.id;
    }
    
    function isDragging() {
        return draggingNodeId === node?.id;
    }
    
    function handleClick(e: MouseEvent) {
        e.stopPropagation();
        selectedNodeId = node.id;
    }
    
    // This is the critical function that needs to initialize dragging
    function handleMouseDown(e: MouseEvent) {
        if (!isReorderable) return;
        
        console.log(`Node mousedown: ${node.id} - Starting drag!`);
        e.stopPropagation();
        e.preventDefault();
        
        // This tells our drag system which element is being dragged
        draggingNodeId = node.id;
        updateDraggedElement(node.id);
        
        // Set up initial coordinates for dragging
        const elem = e.currentTarget as HTMLElement;
        const rect = elem.getBoundingClientRect();
        
        // Calculate click offset within the element
        const offsetX = e.clientX - rect.left;
        const offsetY = e.clientY - rect.top;
        
        // Dispatch a custom event to let the parent +layout component know 
        // an element drag has started
        const dragStartEvent = new CustomEvent('element-drag-start', {
            bubbles: true,
            detail: { 
                id: node.id, 
                initialX: rect.left,
                initialY: rect.top,
                offsetX,
                offsetY,
                element: elem
            }
        });
        document.dispatchEvent(dragStartEvent);
    }
</script>

<!-- Add the reorderable class if isReorderable is true -->
<div 
    class="node {isSelected() ? 'selected' : ''} {isDragging() ? 'dragging' : ''} {isReorderable ? 'reorderable' : ''}"
    data-node-id={node.id}
    on:click={handleClick}
    on:mousedown={handleMouseDown}
>
    <div class="node-content">
        <span class="tag-name">{node.tagName}</span>
        
        {#if node.props?.textContent}
            <span class="text-content">{node.props.textContent}</span>
        {/if}
        
        <!-- Add node properties visualization if needed -->
    </div>
    
    {#if node.children && node.children.length > 0}
        <div class="children">
            {#each node.children as childId}
                {#if vdom.getNode(childId)}
                    <svelte:self 
                        node={vdom.getNode(childId)} 
                        {vdom} 
                        bind:selectedNodeId 
                        bind:x 
                        bind:y 
                        bind:draggingNodeId
                        {isReorderable}
                    />
                {/if}
            {/each}
        </div>
    {/if}
</div>

<style>
    .node {
        margin: 5px 0;
        padding: 5px;
        border: 1px solid #ccc;
        border-radius: 4px;
        cursor: pointer;
    }
    
    .node.selected {
        border-color: #3B82F6;
        background-color: rgba(59, 130, 246, 0.1);
    }
    
    .node.dragging {
        opacity: 0.7;
        border-style: dashed;
        position: relative;
        z-index: 10;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
    }
    
    .node.reorderable {
        cursor: grab;
        border-style: dashed;
        border-color: #6366F1;
        position: relative;
    }
    
    .node.reorderable:hover {
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        background-color: rgba(99, 102, 241, 0.05);
    }
    
    .node.reorderable:hover::before {
        content: "⋮⋮";
        position: absolute;
        left: -15px;
        top: 50%;
        transform: translateY(-50%);
        font-size: 12px;
        color: #6366F1;
    }
    
    .node-content {
        display: flex;
        align-items: center;
        font-family: monospace;
    }
    
    .tag-name {
        color: #6366F1;
        font-weight: bold;
        margin-right: 5px;
    }
    
    .text-content {
        color: #333;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        max-width: 200px;
    }
    
    .children {
        margin-left: 20px;
        border-left: 1px dotted #ccc;
        padding-left: 10px;
    }
</style>