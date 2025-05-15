<script lang="ts">
    import { mount } from "svelte";
    import Dom from "$lib/Dom.svelte";
    import { onMount } from "svelte";
    import Document from "$lib/components/Document.svelte";
    import VDom from "$lib/VDom.svelte";

    let activeVDom = $state();

    // Use $derived to read store values
    let selectedNodeId = $state(null);

    // Flag to track when DOM is ready
    let isVDomReady = $state(false);

    // Debugging state

    let mouseX = $state(0);
    let mouseY = $state(0);

    function handleMouseMove(event: MouseEvent) {
        mouseX.set(event.clientX);
        mouseY.set(event.clientY);
    }

    function populate() {
        if (!activeVDom) {
            return;
        }

        let rootId = activeVDom.rootNodeId;
        console.log("Root node for population:", rootId);

        // Add h1 heading
        const h1Id = activeVDom.addNode("h1", rootId);
        console.log("Created h1 with id:", h1Id);
        const h1Node = activeVDom.getNode(h1Id);
        if (h1Node) {
            console.log("Setting h1 properties");
            h1Node.setProperty(
                "textContent",
                "Virtual DOM Test from +page.svelte",
            );
            h1Node.setStyle("color", "blue");
            h1Node.setStyle("textAlign", "center");
            h1Node.setStyle("marginTop", "20px");
        } else {
            console.error("Failed to get h1Node");
        }

        // Add paragraph
        const pId = activeVDom.addNode("p", rootId);
        console.log("Created p with id:", pId);
        const pNode = activeVDom.getNode(pId);
        if (pNode) {
            console.log("Setting p properties");
            pNode.setProperty(
                "textContent",
                "Hello, Youtube! This is draggable content.",
            );
            pNode.setStyle("margin", "20px");
            pNode.setStyle("fontFamily", "Arial, sans-serif");
        } else {
            console.error("Failed to get pNode");
        }

        // Add button
        const btnId = activeVDom.addNode("button", rootId);
        console.log("Created button with id:", btnId);
        const btnNode = activeVDom.getNode(btnId);
        if (btnNode) {
            console.log("Setting button properties");
            btnNode.setProperty("textContent", "Click Me");
            btnNode.setStyle("padding", "10px 20px");
            btnNode.setStyle("backgroundColor", "#4CAF50");
            btnNode.setStyle("color", "white");
            btnNode.setStyle("border", "none");
            btnNode.setStyle("borderRadius", "4px");
            btnNode.setStyle("cursor", "pointer");
            btnNode.setStyle("margin", "20px");
            btnNode.setProperty("onClick", () => alert("Button clicked!"));
        } else {
            console.error("Failed to get btnNode");
        }

        // Add list
        const ulId = activeVDom.addNode("ul", rootId);
        console.log("Created ul with id:", ulId);
        const ulNode = activeVDom.getNode(ulId);
        if (ulNode) {
            console.log("Setting ul properties");
            ulNode.setStyle("listStyleType", "disc");
            ulNode.setStyle("margin", "20px");
            ulNode.setStyle("backgroundColor", "#ffaaaa");
            ulNode.setStyle("padding", "15px");
            ulNode.setStyle("borderRadius", "8px");
            ulNode.setStyle("borderLeft", "5px solid #ff5555");
            
            // Add list items
            for (let i = 1; i <= 3; i++) {
                const liId = activeVDom.addNode("li", ulId);
                console.log(`Created li ${i} with id:`, liId);
                const liNode = activeVDom.getNode(liId);
                if (liNode) {
                    console.log(`Setting li ${i} properties`);
                    liNode.setProperty("textContent", `List item ${i}`);
                    liNode.setStyle("padding", "5px");
                    liNode.setStyle("margin", "8px 0");
                    liNode.setStyle("color", "#aa0000");
                    liNode.setStyle("fontWeight", "bold");
                } else {
                    console.error(`Failed to get liNode ${i}`);
                }
            }
        } else {
            console.error("Failed to get ulNode");
        }

        // Helper to convert VNode and its children to the PageContentNode structure
        function convertToPageContentStructure(
            nodeId: string | null,
            sourceVDom: VDom,
        ): any | null {
            if (!nodeId) return null;
            const node = sourceVDom.getNode(nodeId);
            if (!node) return null;
            return {
                id: node.id, // Assuming initializeActiveVDom can handle existing IDs or VDom class needs adjustment
                type: node.tagName,
                props: { ...node.props },
                styleProps: { ...node.styleProps },
                children: node.children
                    .map((childId) =>
                        convertToPageContentStructure(childId, sourceVDom),
                    )
                    .filter((c) => c !== null),
            };
        }

        // Convert the root of activeVDom to the data structure expected by initializeActiveVDom
        const pageRootData = convertToPageContentStructure(
            activeVDom.rootNodeId,
            activeVDom,
        );
        // Initialize/update the shared activeVDom via the exported function

        isVDomReady = true;

        // Log DOM structure to help debug
        setTimeout(() => {
            console.log("Checking for reorderable elements:");
            const reorderables = document.querySelectorAll(".reorderable");
            console.log(`Found ${reorderables.length} reorderable elements`);

            reorderables.forEach((el) => {
                console.log(
                    `Reorderable: ${el.tagName} - ID: ${el.id}, data-node-id: ${el.getAttribute("data-node-id")}`,
                );
            });
        }, 1000);
    }

    let isInitialized = $state(false);

    // Debug selected node changes
    $effect(() => {
        if (activeVDom && activeVDom.rootNodeId && !isInitialized) {
            console.log("activeVDom ready, initializing...");
            // Delay to ensure components are fully mounted
            setTimeout(() => {
                populate();
                isInitialized = true;
                
                // Check what elements are visible
                setTimeout(() => {
                    checkVisibleElements();
                }, 500);
            }, 200);
        }
    });

    function checkVisibleElements() {
        console.log("Checking visible elements...");
        // Find all .node elements and log them
        const nodes = document.querySelectorAll('.node');
        console.log(`Found ${nodes.length} node elements:`, nodes);
        
        // Find all reorderable elements
        const reorderables = document.querySelectorAll('.reorderable');
        console.log(`Found ${reorderables.length} reorderable elements:`, reorderables);
    }

    onMount(() => {
        console.log("Component mounted");
    });
</script>

<Document
    on:mousemove={handleMouseMove}
    bind:activeVDom
    {mouseX}
    {mouseY}
    bind:selectedNodeId
/>

<div class="debug-panel">
    <h3>Debug Info</h3>
    <p>Selected Node: {selectedNodeId || "none"}</p>
    <p>VDom Ready: {isVDomReady ? "Yes" : "No"}</p>
    <p>Root Node ID: {activeVDom?.rootNodeId}</p>
    <p>
        Has addNode method: {activeVDom &&
        typeof activeVDom.addNode === "function"
            ? "Yes"
            : "No"}
    </p>

    <div class="button-row">
        <button
            class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded mb-2 mr-2"
            on:click={() => {
                if (activeVDom) populate();
            }}
        >
            Repopulate Nodes
        </button>
        
        <button
            class="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded mb-2"
            on:click={() => {
                checkVisibleElements();
            }}
        >
            Check Elements
        </button>
    </div>
</div>

<style>
    .debug-panel {
        position: fixed;
        bottom: 10px;
        right: 10px;
        width: 400px;
        max-height: 400px;
        overflow-y: auto;
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 10px;
        border-radius: 4px;
        font-family: monospace;
        font-size: 12px;
        z-index: 1000;
    }

    .log-container {
        margin-top: 10px;
        border-top: 1px solid #444;
        padding-top: 10px;
        max-height: 200px;
        overflow-y: auto;
    }

    .log-line {
        font-size: 11px;
        margin-bottom: 2px;
        white-space: pre-wrap;
        word-break: break-all;
    }

    .debug {
        margin-top: 20px;
        padding: 10px;
        background: #f0f0f0;
        border-radius: 4px;
        font-family: monospace;
        font-size: 12px;
    }

    .loading {
        padding: 20px;
        background: #eeeeff;
        border-radius: 4px;
        text-align: center;
        font-style: italic;
        color: #6666aa;
    }

    .drag-drop-test-area {
        position: fixed;
        bottom: 20px;
        right: 20px;
        width: 600px;
        background: white;
        border-radius: 8px;
        border: 2px solid #3b82f6;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        padding: 15px;
        z-index: 5000;
    }

    .drag-drop-test-area h3 {
        margin: 0 0 15px 0;
        font-size: 16px;
        color: #3b82f6;
        text-align: center;
    }

    .drop-zone {
        padding: 15px;
        background: #f8f9fc;
        border: 2px dashed #cbd5e1;
        border-radius: 8px;
        margin-bottom: 15px;
    }

    .drop-zone h4 {
        margin: 0 0 10px 0;
        font-size: 14px;
        color: #64748b;
    }

    .nested-container {
        margin: 10px 0;
        padding: 10px;
        background: #f1f5f9;
        border: 1px solid #cbd5e1;
        border-radius: 6px;
    }

    .nested-container.empty {
        min-height: 50px;
        border: 1px dashed #94a3b8;
        background: #f8fafc;
    }

    .nested-header {
        font-size: 12px;
        color: #64748b;
        margin-bottom: 8px;
        font-weight: 500;
    }

    .draggable-item {
        padding: 10px 15px;
        background: white;
        border: 1px solid #e2e8f0;
        border-radius: 6px;
        margin-bottom: 8px;
        cursor: grab;
        position: relative;
        user-select: none;
        transition: background 0.2s;
    }

    .draggable-item:hover {
        background: #f1f5f9;
    }

    .draggable-item .handle {
        position: absolute;
        left: 5px;
        top: 50%;
        transform: translateY(-50%);
        color: #94a3b8;
        font-size: 14px;
    }

    .draggable-item.dragging {
        opacity: 0.7;
        box-shadow: 0 5px 10px rgba(0, 0, 0, 0.15);
    }
</style>
