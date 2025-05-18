<script lang="ts">
    import { onMount } from "svelte";
    import VNode from "./VNode.svelte";
    import { virtualScale } from "$lib/store";

    // Props
    let {
        selectedNodeId = $bindable<string | null>(),
        showBlueprintMode = $bindable(true), // Default to true for debugging
    } = $props();
    let currentScale = $state($virtualScale);

    // Simple node type definition
    type Node = {
        id: string;
        tagName: string;
        parentId: string | null;
        children: string[];
        props: Record<string, any>;
        styles: Record<string, string>;
    };

    // Nodes collection using reactive state
    let nodes = $state<Record<string, Node>>({});
    let updateCount = $state(0);

    // Initialize root node
    const rootId = "root";
    nodes[rootId] = {
        id: rootId,
        tagName: "div",
        parentId: null,
        children: [],
        props: { textContent: "Root Node" },
        styles: {
            width: "100%",
            height: "100%",
            padding: "20px",
            border: "1px dashed blue",
            background: "rgba(240, 240, 255, 0.2)",
        }
    };

    // Add a new node
    function addNode(tagName: string, parentId: string | null = null): string {
        // Use root as default parent if none provided
        if (parentId === null) parentId = rootId;
        
        // Generate node ID
        const nodeId = crypto.randomUUID();
        
        // Create node
        nodes[nodeId] = {
            id: nodeId,
            tagName,
            parentId,
            children: [],
            props: {},
            styles: {}
        };
        
        // Add to parent's children
        if (parentId && nodes[parentId]) {
            nodes[parentId].children.push(nodeId);
        }
        
        // Force update
        updateCount++;
        return nodeId;
    }

    // Get a node with helper methods
    function getNode(id: string) {
        if (!nodes[id]) return null;
        
        const node = nodes[id];
        
        return {
            ...node,
            setProperty(name: string, value: any) {
                nodes[id].props[name] = value;
                updateCount++;
            },
            setStyle(name: string, value: string) {
                nodes[id].styles[name] = value;
                updateCount++;
            },
            appendChild(childId: string) {
                if (nodes[childId] && !nodes[id].children.includes(childId)) {
                    // Update parent reference
                    nodes[childId].parentId = id;
                    // Add to children array
                    nodes[id].children.push(childId);
                    updateCount++;
                }
            },
            removeChild(childId: string) {
                const index = nodes[id].children.indexOf(childId);
                if (index !== -1) {
                    nodes[id].children.splice(index, 1);
                    updateCount++;
                }
            }
        };
    }

    // Handle node selection
    function handleNodeSelect(event) {
        selectedNodeId = event.detail.id;
        console.log(`Selected node: ${selectedNodeId}`);
    }

    // Add some sample content on mount
    onMount(() => {
        // Add a div node
        const divId = addNode("div");
        const div = getNode(divId);
        div.setStyle("width", "200px");
        div.setStyle("height", "100px");
        div.setStyle("background", "lightblue");
        div.setStyle("margin", "20px");
        div.setProperty("textContent", "Hello, Virtual DOM!");

        // Add a child element
        const spanId = addNode("span", divId);
        const span = getNode(spanId);
        span.setStyle("color", "red");
        span.setStyle("fontWeight", "bold");
        span.setProperty("textContent", "I am a child element");
        
        console.log("Sample nodes created:", nodes);
    });

    // Expose the API
    export { addNode, getNode };
</script>

<div class="vdom-container">
    <VNode
        id={rootId}
        nodes={nodes}
        selectedNodeId={selectedNodeId}
        showBlueprintMode={showBlueprintMode}
        updateCount={updateCount}
    />
</div>

<!-- Debug info -->
<div class="debug-overlay">
    <div>Root ID: {rootId}</div>
    <div>Nodes: {Object.keys(nodes).length}</div>
    <div>Updates: {updateCount}</div>
    <div>Selected: {selectedNodeId || "none"}</div>
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