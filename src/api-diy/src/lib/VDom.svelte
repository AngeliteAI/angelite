<script lang="ts">
    import Node from "./Node.svelte";

    // Props
    let {
        selectedNodeId = $bindable<string | null>(null),
        showBlueprintMode = false,
        virtualScale = $bindable(0.2),
    } = $props();

    // Create a simple registry
    let nodeRegistry = $state(new Map());
    let nodeCount = $state(0);
    let rootNodeId = $state("root");

    // Check if root node is already present
    if (!nodeRegistry.has(rootNodeId)) {
        // Initialize root node
        nodeRegistry.set(rootNodeId, {
            id: rootNodeId,
            tagName: "div",
            parentId: null,
            children: [],
            props: {},
            styleProps: {
                width: "100%",
                height: "100%",
                position: "relative",
                padding: "20px",
            },
        });
    }

    // Listen for changes to virtualScale
    $effect(() => {
        console.log(`VDom: virtualScale updated to ${virtualScale}`);
    });

    // Simple node methods
    function addNode(elementType, parentId = null) {
        // Default to root if no parent specified
        if (parentId === null) {
            parentId = rootNodeId;
        }

        // Generate ID
        const nodeId = crypto.randomUUID();
        console.log(
            `Adding node ${nodeId} (${elementType}) to parent ${parentId}`,
        );

        // Create node object
        nodeRegistry.set(nodeId, {
            id: nodeId,
            tagName: elementType,
            parentId: parentId,
            children: [],
            props: {},
            styleProps: {},
        });
        nodeCount++; // Increment counter to trigger reactivity

        // Add to parent's children list
        if (parentId && nodeRegistry.has(parentId)) {
            const parentNode = nodeRegistry.get(parentId);
            parentNode.children.push(nodeId);
            nodeRegistry.set(parentId, { ...parentNode }); // Update parent in registry
            console.log(
                `Added ${nodeId} to parent ${parentId}, children count: ${parentNode.children.length}`,
            );
        }

        return nodeId;
    }

    function getNode(id) {
        if (!nodeRegistry.has(id)) {
            console.log(`Node ${id} not found in registry`);
            return null;
        }

        const node = nodeRegistry.get(id);

        // Return node with methods
        return {
            ...node,
            setProperty: (name, value) => {
                console.log(`Setting property ${name}=${value} on node ${id}`);
                node.props[name] = value;
                // This forces Svelte to recognize the change
                nodeRegistry.set(id, { ...node });
                nodeCount++; // Increment counter to trigger reactivity
            },
            setStyle: (property, value) => {
                console.log(`Setting style ${property}=${value} on node ${id}`);
                node.styleProps[property] = value;
                // This forces Svelte to recognize the change
                nodeRegistry.set(id, { ...node });
                nodeCount++; // Increment counter to trigger reactivity
            },
        };
    }

    // Recursively render a node and its children using Svelte components
    function renderNodes(nodeId) {
        if (!nodeRegistry.has(nodeId)) {
            return null;
        }
        
        const node = nodeRegistry.get(nodeId);
        
        return {
            id: node.id,
            tagName: node.tagName,
            parentId: node.parentId,
            children: node.children,
            props: node.props,
            styleProps: node.styleProps
        };
    }

    // Handle node selection
    function handleNodeSelect(event) {
        console.log(`Node selected: ${event.detail.id}`);
        selectedNodeId = event.detail.id;
    }

    // Export functions for external use
    export { rootNodeId, addNode, getNode };
</script>

<div class="vdom-container">
    {#if nodeRegistry.has(rootNodeId)}
        <Node 
            id={rootNodeId}
            tagName={nodeRegistry.get(rootNodeId).tagName}
            parentId={null}
            children={nodeRegistry.get(rootNodeId).children}
            props={nodeRegistry.get(rootNodeId).props}
            styleProps={nodeRegistry.get(rootNodeId).styleProps}
            selectedNodeId={selectedNodeId}
            showBlueprintMode={showBlueprintMode}
            {virtualScale}
            on:select={handleNodeSelect}
        />
    {/if}
</div>

<!-- Debug info -->
<div class="debug-overlay">
    <div>Root ID: {rootNodeId}</div>
    <div>Nodes: {nodeRegistry.size}</div>
    <div>Updates: {nodeCount}</div>
    <div>Selected: {selectedNodeId || "none"}</div>
    <div>Scale: {virtualScale.toFixed(2)}</div>
</div>

<style>
    .vdom-container {
        width: 100%;
        height: 100%;
        position: relative;
    }

    .debug-overlay {
        position: fixed;
        bottom: 10px;
        left: 10px;
        background: rgba(0, 0, 0, 0.7);
        color: white;
        padding: 5px 10px;
        font-family: monospace;
        font-size: 12px;
        border-radius: 4px;
        z-index: 9999;
    }
</style>