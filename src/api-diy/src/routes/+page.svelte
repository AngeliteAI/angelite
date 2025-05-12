<script lang="ts">
    import { VDom, initializeActiveVDom, activeVDom, draggedCurrentX, draggedCurrentY, draggedElement } from '$lib/VDom.svelte';
    import Dom from '$lib/Dom.svelte';
    import { onMount } from 'svelte';
    
    // Use $derived to read store values
    let draggedElementId = $derived($draggedElement);
    let currentX = $derived($draggedCurrentX);
    let currentY = $derived($draggedCurrentY);

    let selectedNodeId = $state(null);
    
    // Flag to track when DOM is ready
    let isVDomReady = $state(false);
    
    onMount(() => {
        // Populate pageSpecificVDom
        const rootId = activeVDom.addNode('div', null);
        const rootNodeCheck = activeVDom.getNode(rootId);
        if (!rootNodeCheck) return; // Should not happen if addNode is correct

        const h1Id = activeVDom.addNode('h1', rootId);
        const h1Node = activeVDom.getNode(h1Id);
        if (h1Node) {
          h1Node.setProperty('textContent', 'Virtual DOM Test from +page.svelte');
          h1Node.setStyle('color', 'blue');
          h1Node.setStyle('textAlign', 'center');
        } else { console.error("Failed to get h1Node"); }
        
        const pId = activeVDom.addNode('p', rootId);
        const pNode = activeVDom.getNode(pId);
        if (pNode) {
            pNode.setProperty('textContent', 'Hi Dr Krain! This is editable content.');
            pNode.setStyle('margin', '20px');
            pNode.setStyle('fontFamily', 'Arial, sans-serif');
        } else { console.error("Failed to get pNode"); }
        
        const btnId = activeVDom.addNode('button', rootId);
        const btnNode = activeVDom.getNode(btnId);
        if (btnNode) {
            btnNode.setProperty('textContent', 'Click Me');
            btnNode.setStyle('padding', '10px 20px');
            btnNode.setStyle('backgroundColor', '#4CAF50');
            btnNode.setStyle('color', 'white');
            btnNode.setStyle('border', 'none');
            btnNode.setStyle('borderRadius', '4px');
            btnNode.setStyle('cursor', 'pointer');
            btnNode.setStyle('margin', '20px');
            btnNode.setProperty('onClick', () => alert('Button clicked!'));
        } else { console.error("Failed to get btnNode"); }
        
        const ulId = activeVDom.addNode('ul', rootId);
        const ulNode = activeVDom.getNode(ulId);
        if (ulNode) {
            ulNode.setStyle('listStyleType', 'circle');
            ulNode.setStyle('margin', '20px');
            for (let i = 1; i <= 3; i++) {
                const liId = activeVDom.addNode('li', ulId);
                const liNode = activeVDom.getNode(liId);
                if (liNode) {
                    liNode.setProperty('textContent', `List item ${i}`);
                    liNode.setStyle('padding', '5px');
                } else { console.error(`Failed to get liNode ${i}`); }
            }
        } else { console.error("Failed to get ulNode"); }
        
        // Helper to convert VNode and its children to the PageContentNode structure
        function convertToPageContentStructure(nodeId: string | null, sourceVDom: VDom): any | null {
            if (!nodeId) return null;
            const node = sourceVDom.getNode(nodeId);
            if (!node) return null;
            return {
                id: node.id, // Assuming initializeActiveVDom can handle existing IDs or VDom class needs adjustment
                type: node.tagName, 
                props: { ...node.props },
                children: node.children.map(childId => convertToPageContentStructure(childId, sourceVDom)).filter(c => c !== null)
            };
        }

        // Convert the root of activeVDom to the data structure expected by initializeActiveVDom
        const pageRootData = convertToPageContentStructure(activeVDom.rootNodeId, activeVDom);

        // Initialize/update the shared activeVDom via the exported function
        initializeActiveVDom(pageRootData);
        
        
        isVDomReady = true;

        // Log DOM structure to help debug
        setTimeout(() => {
            console.log("Checking for reorderable elements:");
            const reorderables = document.querySelectorAll('.reorderable');
            console.log(`Found ${reorderables.length} reorderable elements`);
            
            reorderables.forEach(el => {
                console.log(`Reorderable: ${el.tagName} - ID: ${el.id}, data-node-id: ${el.getAttribute('data-node-id')}`);
            });
        }, 1000);
    });
    
    // Debug selected node changes
    $effect(() => {
    });
</script>

{#if isVDomReady && activeVDom}
    <Dom 
        vdom={activeVDom} 
        bind:selectedNodeId
        {draggedElementId}
        {currentX}
        {currentY}
    />

    <!-- Add a simple dedicated drag and drop test area -->
    <div class="drag-drop-test-area">
        <h3>Drag & Drop Test Area</h3>
        
        <div class="drop-zone" id="drop-zone-1" data-node-id="drop-zone-1">
            <h4>Drop Zone 1</h4>
            
            <div 
                class="draggable-item" 
                id="item-1"
                data-node-id="item-1"
                draggable="true"
                on:mousedown={(e) => {
                    const el = e.currentTarget as HTMLElement;
                    const rect = el.getBoundingClientRect();
                    
                    // Create a drag event with fixed positioning
                    const dragEvent = new CustomEvent('element-drag-start', {
                        bubbles: true,
                        detail: {
                            id: el.id,
                            initialX: rect.left,
                            initialY: rect.top,
                            offsetX: e.clientX - rect.left,
                            offsetY: e.clientY - rect.top,
                            element: el
                        }
                    });
                    
                    document.dispatchEvent(dragEvent);
                    e.preventDefault();
                    e.stopPropagation();
                }}
            >
                <span class="handle">↕</span>
                Item 1
            </div>
            
            <!-- Nested container to test parent-child relationships -->
            <div 
                class="nested-container" 
                id="nested-1" 
                data-node-id="nested-1"
            >
                <div class="nested-header">Nested Container</div>
                <div 
                    class="draggable-item" 
                    id="item-2"
                    data-node-id="item-2"
                    draggable="true"
                    on:mousedown={(e) => {
                        const el = e.currentTarget as HTMLElement;
                        const rect = el.getBoundingClientRect();
                        
                        const dragEvent = new CustomEvent('element-drag-start', {
                            bubbles: true,
                            detail: {
                                id: el.id,
                                initialX: rect.left,
                                initialY: rect.top,
                                offsetX: e.clientX - rect.left,
                                offsetY: e.clientY - rect.top,
                                element: el
                            }
                        });
                        
                        document.dispatchEvent(dragEvent);
                        e.preventDefault();
                        e.stopPropagation();
                    }}
                >
                    <span class="handle">↕</span>
                    Item 2 (nested)
                </div>
            </div>
        </div>
        
        <div class="drop-zone" id="drop-zone-2" data-node-id="drop-zone-2">
            <h4>Drop Zone 2</h4>
            
            <div 
                class="draggable-item" 
                id="item-3"
                data-node-id="item-3"
                draggable="true"
                on:mousedown={(e) => {
                    const el = e.currentTarget as HTMLElement;
                    const rect = el.getBoundingClientRect();
                    
                    // Create a drag event with fixed positioning
                    const dragEvent = new CustomEvent('element-drag-start', {
                        bubbles: true,
                        detail: {
                            id: el.id,
                            initialX: rect.left,
                            initialY: rect.top,
                            offsetX: e.clientX - rect.left,
                            offsetY: e.clientY - rect.top,
                            element: el
                        }
                    });
                    
                    document.dispatchEvent(dragEvent);
                    e.preventDefault();
                    e.stopPropagation();
                }}
            >
                <span class="handle">↕</span>
                Item 3
            </div>
            
            <!-- Empty nested container to drop into -->
            <div 
                class="nested-container empty" 
                id="nested-2" 
                data-node-id="nested-2"
            >
                <div class="nested-header">Empty Container (drop here)</div>
            </div>
        </div>
    </div>
{:else}
    <div class="loading">Loading virtual DOM...</div>
{/if}

<style>
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
        border: 2px solid #3B82F6;
        box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        padding: 15px;
        z-index: 5000;
    }
    
    .drag-drop-test-area h3 {
        margin: 0 0 15px 0;
        font-size: 16px;
        color: #3B82F6;
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
        box-shadow: 0 5px 10px rgba(0,0,0,0.15);
    }
</style>

