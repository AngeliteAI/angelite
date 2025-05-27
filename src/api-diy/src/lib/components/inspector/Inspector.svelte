<script lang="ts">
    import { selectedNodeId } from "$lib/store";
    import StyleEditor from "./StyleEditor.svelte";
    import NodeInfo from "./NodeInfo.svelte";
    import StyleUpdater from "./StyleUpdater.svelte";

    // Props
    let {
        vdom = null,
        showInspector = $bindable(true),
        activeTab = $bindable("styles"), // styles, properties, events
    } = $props();
    
    // Style updater component reference
    let styleUpdater;

    // Reactive state
    let tabs = [
        { id: "styles", label: "Styles", icon: "🎨" },
        { id: "properties", label: "Properties", icon: "⚙️" },
        { id: "events", label: "Events", icon: "👆" },
    ];

    // Get current node data and node API
    let nodeData = $derived(() => {
        console.log("[Inspector] Deriving nodeData. selectedNodeId:", $selectedNodeId);
        if (!$selectedNodeId) {
            console.log("[Inspector] No selectedNodeId");
            return null;
        }
        if (!vdom) {
            console.log("[Inspector] No vdom instance");
            return null;
        }
        if (typeof vdom.getNode !== 'function') {
            console.log("[Inspector] vdom.getNode is not a function");
            return null;
        }
        
        try {
            const node = vdom.getNode($selectedNodeId);
            console.log("[Inspector] Got node data:", node);
            return node; // This returns the node with methods attached
        } catch (error) {
            console.error("[Inspector] Error getting node:", error);
            return null;
        }
    });

    // Access to raw node data for rendering
    let selectedNode = $derived(() => {
        if (!nodeData) {
            // Try to get node data directly from vdom
            if (vdom && typeof vdom.getNode === 'function' && $selectedNodeId) {
                try {
                    return vdom.getNode($selectedNodeId);
                } catch (e) {
                    console.log("[Inspector] Failed to get node data via vdom.getNode");
                }
            }
            return null;
        }
        
        // Make sure we have access to styles and props
        const defaultNode = { 
            styles: {}, 
            props: {},
            tagName: 'unknown'
        };
        
        return {
            ...defaultNode,
            ...nodeData
        };
    });

    // Add reactive effect to debug selected node updates
    $effect(() => {
        console.log("Selected node ID:", $selectedNodeId);
        console.log("VDom available:", !!vdom);
        
        if (vdom) {
            console.log("VDom methods:", Object.keys(vdom));
            console.log("getNode function type:", typeof vdom.getNode);
        }
        
        if (nodeData) {
            console.log("Selected node data:", nodeData);
            console.log("Current styles:", nodeData.styles || {});
            console.log("Current properties:", nodeData.props || {});
            console.log(
                "Available methods on node:",
                Object.keys(nodeData).filter(
                    (key) => typeof nodeData[key] === "function",
                ),
            );
        } else {
            console.log("No node data available");
        }
    });

    // Handle property updates
    function updateStyle(name: string, value: string) {
        if (!$selectedNodeId) {
            console.error("[Inspector] Cannot update style: No node selected");
            return;
        }
        
        console.log(`[Inspector] Setting style ${name} = ${value} for node ${$selectedNodeId}`);
        
        // Use direct setStyle function if available
        if (vdom && typeof vdom.setStyle === 'function') {
            const success = vdom.setStyle($selectedNodeId, name, value);
            
            if (success) {
                console.log(`[Inspector] Style updated successfully via vdom.setStyle for ${$selectedNodeId}.${name} = ${value}`);
            } else {
                console.error(`[Inspector] Failed to update style via vdom.setStyle for ${$selectedNodeId}`);
            }
            
            // Also try to update DOM element directly as a backup
            try {
                const element = document.getElementById($selectedNodeId);
                if (element) {
                    // Try both camelCase and kebab-case versions
                    const kebabName = name.replace(/([A-Z])/g, '-$1').toLowerCase();
                    element.style[name] = value;
                    element.style.setProperty(kebabName, value);
                    console.log(`[Inspector] Also updated DOM element directly for ${$selectedNodeId}`);
                }
            } catch (e) {
                console.log("[Inspector] Could not update DOM directly:", e);
            }
        } else {
            console.error("[Inspector] Failed to update style: vdom.setStyle not available");
            console.log("[Inspector] vdom available:", !!vdom);
            console.log("[Inspector] vdom.setStyle available:", typeof vdom?.setStyle === 'function');
        }
    }

    function updateProperty(name: string, value: any) {
        console.log(`[Inspector] Setting property ${name} = ${value}`);
        
        if (!$selectedNodeId) {
            console.error("[Inspector] No node selected");
            return;
        }
        
        // Use direct setProperty function if available
        if (vdom && typeof vdom.setProperty === 'function') {
            const success = vdom.setProperty($selectedNodeId, name, value);
            
            if (success) {
                console.log(`[Inspector] Property updated successfully via vdom.setProperty for ${$selectedNodeId}.${name}`);
            } else {
                console.error(`[Inspector] Failed to update property via vdom.setProperty for ${$selectedNodeId}`);
            }
        } 
        // Fallback to node method if available
        else if (nodeData && typeof nodeData.setProperty === 'function') {
            try {
                nodeData.setProperty(name, value);
                console.log(`[Inspector] Property updated via nodeData.setProperty for ${$selectedNodeId}.${name}`);
            } catch (e) {
                console.error("[Inspector] Error updating property via nodeData.setProperty:", e);
            }
        } else {
            console.error("[Inspector] Failed to update property: No update method available");
        }
    }

    function removeStyle(name: string) {
        if (!$selectedNodeId) {
            console.error("[Inspector] Cannot remove style: No selected node");
            return;
        }

        console.log(`[Inspector] Removing style ${name} from node ${$selectedNodeId}`);
        
        // Use direct setStyle function to set empty value
        if (vdom && typeof vdom.setStyle === 'function') {
            const success = vdom.setStyle($selectedNodeId, name, "");
            if (success) {
                console.log(`[Inspector] Style removed successfully via vdom.setStyle for ${$selectedNodeId}.${name}`);
                
                // Also try to update DOM element directly
                try {
                    const element = document.getElementById($selectedNodeId);
                    if (element) {
                        const kebabName = name.replace(/([A-Z])/g, '-$1').toLowerCase();
                        element.style[name] = "";
                        element.style.removeProperty(kebabName);
                    }
                } catch (e) {
                    // Ignore DOM errors
                }
            } else {
                console.error(`[Inspector] Failed to remove style via vdom.setStyle for ${$selectedNodeId}.${name}`);
            }
        } else if (nodeData && typeof nodeData.setStyle === "function") {
            // Fallback to node method
            nodeData.setStyle(name, "");
            console.log(`[Inspector] Style removed via nodeData.setStyle for ${$selectedNodeId}.${name}`);
        } else {
            console.error("[Inspector] Cannot remove style: No method available");
        }
    }
</script>

<div class="inspector" class:collapsed={!showInspector}>
    <div class="inspector-header">
        <h3>Inspector</h3>
        <button
            class="toggle-button"
            on:click={() => (showInspector = !showInspector)}
            aria-label={showInspector
                ? "Collapse inspector"
                : "Expand inspector"}
        >
            {showInspector ? "◀" : "▶"}
        </button>
    </div>

    {#if showInspector}
        {#if $selectedNodeId}
            <div class="inspector-content">
                <div class="tabs">
                    {#each tabs as tab}
                        <button
                            class="tab-button"
                            class:active={activeTab === tab.id}
                            on:click={() => (activeTab = tab.id)}
                        >
                            <span class="tab-icon">{tab.icon}</span>
                            <span class="tab-label">{tab.label}</span>
                        </button>
                    {/each}
                </div>

                <div class="tab-content">
                    {#if activeTab === "styles"}
                                            <div class="debug-info">
                                                <p class="debug-title">
                                                    Selected Node ID: <span class="debug-value"
                                                        >{$selectedNodeId || "NONE"}</span
                                                    >
                                                </p>
                                                <p class="debug-title">
                                                    Node Type: <span class="debug-value"
                                                        >{selectedNode?.tagName || "Unknown"}</span
                                                    >
                                                </p>
                                                <button class="debug-button" on:click={() => {
                                                    console.log("[Inspector] Current selectedNodeId:", $selectedNodeId);
                                                    console.log("[Inspector] vdom:", vdom);
                                                    console.log("[Inspector] selectedNode:", selectedNode);
                                                    console.log("[Inspector] nodeData:", nodeData);
                                                }}>Debug Log State</button>
                                                
                                                <div class="manual-selection">
                                                    <p class="debug-title">Manual Selection:</p>
                                                    <div class="selection-buttons">
                                                        <button class="select-button" on:click={() => selectedNodeId.set("root")}>Select Root</button>
                                                        {#if vdom && vdom.nodes}
                                                            {#each Object.keys(vdom.nodes).slice(0, 5) as nodeId}
                                                                <button class="select-button" on:click={() => selectedNodeId.set(nodeId)}>
                                                                    {nodeId.substring(0, 6)}...
                                                                </button>
                                                            {/each}
                                                        {/if}
                                                    </div>
                                                </div>
                                            </div>
                                            <StyleEditor
                                                styles={(selectedNode?.styles || 
                                                  (vdom && typeof vdom.getNodeStyles === 'function' && $selectedNodeId) ? 
                                                    vdom.getNodeStyles($selectedNodeId) : {}
                                                )}
                                                onUpdate={updateStyle}
                                                onRemove={removeStyle}
                                            />
                    {:else if activeTab === "properties"}
                        <NodeInfo
                            node={selectedNode}
                            properties={selectedNode?.props || {}}
                            onUpdate={updateProperty}
                        />
                    {:else if activeTab === "events"}
                        <div class="events-editor">
                            <p class="coming-soon">
                                Event handling coming soon
                            </p>
                        </div>
                    {/if}
                </div>
            </div>
        {:else}
            <div class="no-selection">
                <p>No element selected</p>
                <p class="hint">
                    Click on an element to select it and edit its properties
                </p>
            </div>
        {/if}
    {/if}
</div>

<style>
    .inspector {
        background-color: #1e1e1e;
        color: #f0f0f0;
        width: 300px;
        height: 100%;
        border-left: 1px solid #333;
        transition: width 0.3s ease;
        overflow: hidden;
        display: flex;
        flex-direction: column;
    }

    .debug-info {
        margin-top: 16px;
        padding: 8px;
        background-color: #2a2a2a;
        border-radius: 4px;
        font-size: 10px;
    }
    
    .debug-button {
        background: #3a3a3a;
        color: #4299e1;
        border: 1px solid #4299e1;
        border-radius: 4px;
        padding: 4px 8px;
        font-size: 11px;
        margin-top: 8px;
        cursor: pointer;
        width: 100%;
    }
    
    .debug-button:hover {
        background: #4a4a4a;
        color: #63b3ed;
    }
    
    .manual-selection {
        margin-top: 10px;
        padding: 8px;
        background-color: #2a2a2a;
        border-radius: 4px;
    }
    
    .selection-buttons {
        display: flex;
        flex-wrap: wrap;
        gap: 5px;
        margin-top: 5px;
    }
    
    .select-button {
        background: #333;
        color: #fff;
        border: 1px solid #555;
        border-radius: 3px;
        padding: 3px 6px;
        font-size: 10px;
        cursor: pointer;
    }
    
    .select-button:hover {
        background: #444;
        border-color: #4299e1;
    }

    .debug-title {
        margin: 0 0 4px 0;
        color: #999;
    }

    .debug-value {
        color: #4299e1;
        font-family: monospace;
    }

    .collapsed {
        width: 30px;
    }

    .inspector-header {
        padding: 8px 12px;
        border-bottom: 1px solid #333;
        display: flex;
        justify-content: space-between;
        align-items: center;
        background-color: #252525;
    }

    .inspector-header h3 {
        margin: 0;
        font-size: 14px;
        font-weight: 500;
    }

    .toggle-button {
        background: none;
        border: none;
        color: #999;
        cursor: pointer;
        font-size: 14px;
        padding: 2px 6px;
        border-radius: 3px;
    }

    .toggle-button:hover {
        background-color: #333;
        color: #fff;
    }

    .inspector-content {
        flex: 1;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
    }

    .tabs {
        display: flex;
        border-bottom: 1px solid #333;
    }

    .tab-button {
        background: none;
        border: none;
        color: #ccc;
        padding: 8px 12px;
        cursor: pointer;
        flex: 1;
        font-size: 12px;
        transition: background-color 0.2s;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 4px;
    }

    .tab-button:hover {
        background-color: #2a2a2a;
    }

    .tab-button.active {
        background-color: #3a3a3a;
        color: #fff;
        border-bottom: 2px solid #4299e1;
    }

    .tab-icon {
        font-size: 16px;
    }

    .tab-label {
        font-size: 11px;
    }

    .tab-content {
        flex: 1;
        padding: 12px;
        overflow-y: auto;
    }

    .no-selection {
        padding: 24px 12px;
        text-align: center;
        color: #888;
    }

    .hint {
        font-size: 12px;
        margin-top: 8px;
        color: #666;
    }

    .coming-soon {
        font-style: italic;
        color: #888;
        text-align: center;
        padding: 20px;
    }
</style>
