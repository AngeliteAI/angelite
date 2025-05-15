<script lang="ts">
    import { onMount } from "svelte";
    
    // Props
    let {
        selectedNodeId = $bindable<string | null>(null),
        showBlueprintMode = false,
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

    // Simple node methods
    function addNode(elementType, parentId = null) {
        // Default to root if no parent specified
        if (parentId === null) {
            parentId = rootNodeId;
        }

        // Generate ID
        const nodeId = crypto.randomUUID();
        console.log(`Adding node ${nodeId} (${elementType}) to parent ${parentId}`);
        
        // Create node object
        // Add to registry
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
            nodeRegistry.set(parentId, {...parentNode}); // Update parent in registry
            console.log(`Added ${nodeId} to parent ${parentId}, children count: ${parentNode.children.length}`);
        }
        
        // Force refresh to ensure the node is rendered
        forceRefresh();
        
        return nodeId;
    }
    
    function getNode(id) {
        if (!nodeRegistry.has(id)) {
            console.log(`Node ${id} not found in registry`);
            return null;
        }
        
        const node = nodeRegistry.get(id);
        
        // Add methods
        return {
            ...node,
            setProperty: (name, value) => {
                console.log(`Setting property ${name}=${value} on node ${id}`);
                node.props[name] = value;
                // This forces Svelte to recognize the change
                nodeRegistry.set(id, {...node});
                nodeCount++; // Increment counter to trigger reactivity
                forceRefresh();
            },
            setStyle: (property, value) => {
                console.log(`Setting style ${property}=${value} on node ${id}`);
                node.styleProps[property] = value;
                // This forces Svelte to recognize the change
                nodeRegistry.set(id, {...node});
                nodeCount++; // Increment counter to trigger reactivity
                forceRefresh();
            }
        };
    }
    
    // Force refresh function to update the DOM
    // Store a global copy of our registry to prevent it from being lost
    let globalRegistry = new Map();
    
    function forceRefresh() {
        setTimeout(() => {
            // Protect our registry from being destroyed
            if (nodeRegistry.size > globalRegistry.size) {
                // Update global registry if needed
                globalRegistry = new Map(nodeRegistry);
            } else if (globalRegistry.size > nodeRegistry.size) {
                // Restore registry from global if it was lost
                nodeRegistry = new Map(globalRegistry);
                console.log("Restored registry from global copy, nodes:", nodeRegistry.size);
            }
            
            console.log("Forcing refresh of VDOM");
            console.log("Current nodes:", Array.from(nodeRegistry.keys()));
            
            const vdomContainer = document.querySelector('.vdom-container');
            if (vdomContainer) {
                // Create nodes directly in the DOM instead of using innerHTML
                createDomNodesDirectly(vdomContainer);
                
                // Log all reorderable elements after render
                setTimeout(() => {
                    const reorderables = document.querySelectorAll('.reorderable');
                    console.log(`Found ${reorderables.length} reorderable elements after refresh`);
                    reorderables.forEach(el => {
                        console.log(`Reorderable: ${el.tagName} - ID: ${el.id}, data-node-id: ${el.getAttribute('data-node-id')}`);
                    });
                }, 10);
            }
        }, 0);
    }
    
    // Directly create DOM nodes instead of using innerHTML
    function createDomNodesDirectly(container) {
        // Clear the container
        container.innerHTML = '';
        
        // Create the root node first
        const rootNode = createDomNodeForId(rootNodeId);
        if (rootNode) {
            container.appendChild(rootNode);
        }
    }
    
    // Create a DOM node for a specific node ID
    function createDomNodeForId(nodeId) {
        if (!nodeRegistry.has(nodeId)) {
            console.warn(`Node ${nodeId} not found in registry`);
            return null;
        }
        
        const node = nodeRegistry.get(nodeId);
        const isRoot = node.parentId === null;
        const isSelected = nodeId === selectedNodeId;
        
        // Create the DOM element
        const element = document.createElement('div');
        element.id = nodeId;
        element.setAttribute('data-node-id', nodeId);
        element.setAttribute('data-node-type', node.tagName);
        element.className = `node ${node.tagName} reorderable ${isRoot ? 'root' : ''} ${isSelected ? 'selected' : ''}`;
        element.draggable = true;
        
        // Set styles
        for (const [key, value] of Object.entries(node.styleProps || {})) {
            const kebabKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
            element.style[kebabKey] = value;
        }
        
        // Set click handler
        element.onclick = (e) => {
            e.stopPropagation();
            window.handleNodeClick(nodeId);
        };
        
        // Add content based on props
        if (node.props.textContent) {
            const span = document.createElement('span');
            span.className = 'node-content';
            span.textContent = node.props.textContent;
            element.appendChild(span);
        }
        
        // Add children
        if (node.children && node.children.length > 0) {
            const childrenContainer = document.createElement('div');
            childrenContainer.className = 'children';
            
            for (const childId of node.children) {
                console.log(`Creating DOM element for child ${childId} of ${nodeId}`);
                const childElement = createDomNodeForId(childId);
                if (childElement) {
                    childrenContainer.appendChild(childElement);
                }
            }
            
            element.appendChild(childrenContainer);
        }
        
        return element;
    }
    
    // Handle node selection
    function handleNodeClick(id) {
        console.log(`Node clicked: ${id}`);
        selectedNodeId = id;
    }
    
    // Helper to render a node and its children
    function renderNode(nodeId) {
        if (!nodeRegistry.has(nodeId)) {
            console.log(`Cannot render node ${nodeId}, not in registry`);
            return '';
        }
        
        const node = nodeRegistry.get(nodeId);
        const isRoot = node.parentId === null;
        const isSelected = nodeId === selectedNodeId;
        
        // Convert style object to inline style string
        const styleStr = Object.entries(node.styleProps || {})
            .map(([key, value]) => {
                const kebabKey = key.replace(/([A-Z])/g, '-$1').toLowerCase();
                return `${kebabKey}: ${value}`;
            })
            .join('; ');
            
        // Start of element - making sure to add reorderable class
    let html = `<div 
        id="${nodeId}" 
        data-node-id="${nodeId}" 
        data-node-type="${node.tagName}"
        class="node ${node.tagName} reorderable ${isRoot ? 'root' : ''} ${isSelected ? 'selected' : ''}"
        style="${styleStr}"
        onclick="window.handleNodeClick('${nodeId}');"
        draggable="true"
    >`;
        
        // Add content based on props
        if (node.props.textContent) {
            html += `<span class="node-content">${node.props.textContent}</span>`;
        }
        
        // Add children
        // Loop through all children
            if (node.children && node.children.length > 0) {
                html += `<div class="children">`;
                for (const childId of node.children) {
                    console.log(`Rendering child ${childId} of ${nodeId}`);
                    if (nodeRegistry.has(childId)) {
                        html += renderNode(childId);
                    } else if (globalRegistry && globalRegistry.has(childId)) {
                        // Try to recover from global registry if available
                        nodeRegistry.set(childId, globalRegistry.get(childId));
                        html += renderNode(childId);
                    } else {
                        console.warn(`Child ${childId} not found in registry!`);
                    }
                }
                html += `</div>`;
            }
        
        // Close element
        html += `</div>`;
        
        return html;
    }
    
    // Make the click handler global so it can be called from rendered HTML
    onMount(() => {
        window.handleNodeClick = (id) => {
            console.log(`Node clicked via global handler: ${id}`);
            selectedNodeId = id;
            forceRefresh();
        };
        
        // Initial render - create DOM nodes directly
        setTimeout(() => {
            console.log('Initial render, nodes in registry:', nodeRegistry.size);
            console.log('Nodes:', Array.from(nodeRegistry.keys()));
            
            // Create DOM nodes directly
            const vdomContainer = document.querySelector('.vdom-container');
            if (vdomContainer) {
                createDomNodesDirectly(vdomContainer);
                
                // Check for reorderable elements
                setTimeout(() => {
                    const reorderables = document.querySelectorAll('.reorderable');
                    console.log(`Found ${reorderables.length} reorderable elements after direct creation`);
                }, 50);
            }
        }, 100);
        
        return () => {
            delete window.handleNodeClick;
        };
    });
    
    // Export functions for external use
    export { rootNodeId, addNode, getNode, forceRefresh };
</script>

<!-- Render the node tree using direct DOM creation -->
<div class="vdom-container" id="vdom-container">
    <!-- Container for nodes created by createDomNodesDirectly -->
    <!-- Invisible counter to force reactivity: {nodeCount} -->
</div>

<!-- Debug button to force DOM regeneration -->
<button 
    class="debug-button" 
    on:click={() => {
        const container = document.querySelector('.vdom-container');
        if (container) createDomNodesDirectly(container);
    }}
>
    Regenerate DOM
</button>

<!-- Debug info -->
<div class="debug-overlay">
    <div>Root ID: {rootNodeId}</div>
    <div>Nodes: {nodeRegistry.size}</div>
    <div>Updates: {nodeCount}</div>
    <div>Selected: {selectedNodeId || 'none'}</div>
</div>

<style>
    .vdom-container {
        width: 100%;
        height: 100%;
        position: relative;
    }
    
    :global(.node) {
        position: relative;
        min-height: 20px;
        min-width: 20px;
        box-sizing: border-box;
        transition: background-color 0.15s ease, outline 0.15s ease;
        z-index: 1;
    }
    
    :global(.node.selected) {
        outline: 2px solid #4299e1;
        z-index: 10;
        box-shadow: 0 0 0 2px rgba(66, 153, 225, 0.5);
    }
    
    :global(.children) {
        margin-left: 10px;
        position: relative;
        z-index: 2;
    }
    
    :global(.root) {
        width: 100%;
        height: 100%;
    }
    
    :global(.node-content) {
        display: inline-block;
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
    
    .debug-button {
        position: fixed;
        top: 10px;
        right: 10px;
        background: rgba(66, 153, 225, 0.9);
        color: white;
        padding: 5px 10px;
        border-radius: 4px;
        font-family: monospace;
        font-size: 12px;
        z-index: 9999;
        cursor: pointer;
        border: none;
    }
    
    .debug-button:hover {
        background: rgba(66, 153, 225, 1);
    }
</style>
