<script lang="ts">
    import { onMount } from "svelte";
    import VNode from "./VNode.svelte";
    import { virtualScale, selectedNodeId } from "$lib/store";

    // Props
    let {
        showBlueprintMode = $bindable(true), // Default to true for debugging
        nodes = $bindable<Record<string, Node>>({}),
        updateCount = $bindable(0),
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

    // Nodes collection using reactive state - exported as bindable

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
        },
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
            styles: {},
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
    export function getNode(id: string) {
        if (!nodes[id]) {
            console.log(`[VDom] getNode: Node with id ${id} not found`);
            return null;
        }

        const node = nodes[id];
        console.log(
            `[VDom] getNode: Found node with id ${id}, type ${node.tagName}`,
        );

        return {
            ...node,
            setProperty(name: string, value: any) {
                return setProperty(id, name, value);
            },
            setStyle(name: string, value: string) {
                return setStyle(id, name, value);
            },
            appendChild(childId: string) {
                return appendChild(id, childId);
            },
            removeChild(childId: string) {
                return removeChild(id, childId);
            },
        };
    }

    // Direct property setting function for any node
    export function setProperty(id: string, name: string, value: any) {
        if (!nodes[id]) {
            console.log(`[VDom] setProperty: Node with id ${id} not found`);
            return false;
        }

        console.log(`[VDom] setProperty: Setting ${id}.${name} = ${value}`);

        // Ensure props object exists
        if (!nodes[id].props) {
            nodes[id].props = {};
        }

        // Update the property
        nodes[id].props[name] = value;
        updateCount++;

        return true;
    }

    // Direct appendChild function for any node
    export function appendChild(id: string, childId: string) {
        if (!nodes[id] || !nodes[childId]) {
            console.log(
                `[VDom] appendChild: Invalid id ${id} or childId ${childId}`,
            );
            return false;
        }

        if (!nodes[id].children.includes(childId)) {
            console.log(`[VDom] appendChild: Adding ${childId} to ${id}`);
            // Update parent reference
            nodes[childId].parentId = id;
            // Add to children array
            nodes[id].children.push(childId);
            updateCount++;
        }

        return true;
    }

    // Direct removeChild function for any node
    export function removeChild(id: string, childId: string) {
        if (!nodes[id]) {
            console.log(`[VDom] removeChild: Invalid id ${id}`);
            return false;
        }

        const index = nodes[id].children.indexOf(childId);
        if (index !== -1) {
            console.log(`[VDom] removeChild: Removing ${childId} from ${id}`);
            nodes[id].children.splice(index, 1);
            updateCount++;
            return true;
        }

        return false;
    }

    // Handle node selection
    function handleNodeSelect(event) {
        const nodeId = event.detail.id;
        console.log(`[VDom] Selected node: ${nodeId}`);
        console.log(`[VDom] Node details:`, nodes[nodeId]);
        // The actual selection state is managed by the Selectable component via the store
    }

    // Handle drag events from nodes
    function handleDragStart(event) {
        console.log(`[VDom] Node drag started: ${event.detail.id}`);
        // We could track dragging state here if needed
    }

    function handleDragEnd(event) {
        console.log(`[VDom] Node drag ended: ${event.detail.id}`);
        // We could do cleanup here if needed
    }

    // Add some sample content on mount
    onMount(() => {
        console.log("[VDom] Initializing sample content");

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

        console.log("[VDom] Sample nodes created:", nodes);
        console.log(
            "[VDom] VDom API methods available:",
            Object.keys(getNode(rootId)),
        );
    });

    // Export a direct style setting function for any node
    export function setStyle(nodeId: string, name: string, value: string) {
        if (!nodes[nodeId]) {
            console.log(`[VDom] setStyle: Node with id ${nodeId} not found`);
            return false;
        }

        console.log(`[VDom] setStyle: Setting ${nodeId}.${name} = ${value}`);

        // Ensure styles object exists
        if (!nodes[nodeId].styles) {
            nodes[nodeId].styles = {};
        }

        // Update the style
        nodes[nodeId].styles[name] = value;
        updateCount++;

        return true;
    }

    // Access to node styles directly
    export function getNodeStyles(id: string) {
        if (!nodes[id]) {
            console.log(`[VDom] getNodeStyles: Node with id ${id} not found`);
            return {};
        }

        return nodes[id].styles || {};
    }

    // Access to node properties directly
    export function getNodeProps(id: string) {
        if (!nodes[id]) {
            console.log(`[VDom] getNodeProps: Node with id ${id} not found`);
            return {};
        }

        return nodes[id].props || {};
    }

    // Get all node IDs
    export function getAllNodeIds() {
        return Object.keys(nodes);
    }

    // Force update
    export function forceUpdate() {
        updateCount++;
    }
</script>

<div class="vdom-container">
    <VNode
        id={rootId}
        {nodes}
        {showBlueprintMode}
        {updateCount}
        on:select={handleNodeSelect}
        on:dragstart={handleDragStart}
        on:dragend={handleDragEnd}
    />
</div>

<!-- Debug info -->
<div class="debug-overlay">
    <div>Root ID: {rootId}</div>
    <div>Nodes: {Object.keys(nodes).length}</div>
    <div>Updates: {updateCount}</div>
    <div>Selected: {$selectedNodeId || "none"}</div>
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
