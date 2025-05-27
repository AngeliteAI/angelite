<script lang="ts">
    // Props
    let {
        node = null,
        properties = {},
        onUpdate = (name, value) => {
            console.log(`Property update called but no handler provided: ${name} = ${value}`);
        },
    } = $props();

    // State
    let newPropName = $state("");
    let newPropValue = $state("");
    let isAdding = $state(false);
    
    // Handle adding a new property
    function addProperty() {
        if (!newPropName.trim()) return;
        
        console.log(`Adding property: ${newPropName} = ${newPropValue}`);
        onUpdate(newPropName, newPropValue);
        
        // Reset form
        newPropName = "";
        newPropValue = "";
        isAdding = false;
    }
    
    // Common element properties
    const commonProperties = [
        { name: "textContent", label: "Text Content", type: "text" },
        { name: "href", label: "Link URL", type: "url" },
        { name: "src", label: "Source URL", type: "url" },
        { name: "alt", label: "Alt Text", type: "text" },
        { name: "title", label: "Title", type: "text" },
        { name: "placeholder", label: "Placeholder", type: "text" },
        { name: "value", label: "Value", type: "text" },
        { name: "checked", label: "Checked", type: "checkbox" },
        { name: "disabled", label: "Disabled", type: "checkbox" },
        { name: "readonly", label: "Read Only", type: "checkbox" },
        { name: "required", label: "Required", type: "checkbox" },
    ];
</script>

<div class="node-info">
    <div class="header">
        <h4>Node Properties</h4>
        <button 
            class="add-button" 
            on:click={() => isAdding = !isAdding}
            aria-label={isAdding ? "Cancel adding property" : "Add new property"}
        >
            {isAdding ? "✕" : "+"}
        </button>
    </div>
    
    <!-- Node information -->
    <div class="node-meta">
            <div class="meta-item">
                <span class="meta-label">Type:</span>
                <span class="meta-value">{node?.tagName || 'Unknown'}</span>
            </div>
            <div class="meta-item">
                <span class="meta-label">ID:</span>
                <span class="meta-value node-id">{node?.id || 'None'}</span>
            </div>
            {#if node?.parentId}
                <div class="meta-item">
                    <span class="meta-label">Parent:</span>
                    <span class="meta-value">{node.parentId}</span>
                </div>
            {/if}
            <div class="meta-item">
                <span class="meta-label">Children:</span>
                <span class="meta-value">{node?.children?.length || 0}</span>
            </div>
            {#if node}
                <button class="refresh-button" on:click={() => {console.log("Node data refreshed"); node = node;}}>
                    Refresh Data
                </button>
            {/if}
        </div>
    
    {#if isAdding}
        <div class="add-property-form">
            <div class="input-group">
                <label for="prop-name">Property</label>
                <input 
                    type="text" 
                    id="prop-name" 
                    placeholder="e.g. textContent, href" 
                    bind:value={newPropName}
                />
            </div>
            <div class="input-group">
                <label for="prop-value">Value</label>
                <input 
                    type="text" 
                    id="prop-value" 
                    placeholder="Value" 
                    bind:value={newPropValue}
                />
            </div>
            <div class="actions">
                <button class="cancel-button" on:click={() => isAdding = false}>Cancel</button>
                <button class="add-button-primary" on:click={addProperty}>Add Property</button>
            </div>
            
            <div class="common-properties">
                <h5>Common Properties</h5>
                <div class="property-list">
                    {#each commonProperties as prop}
                        <button 
                            class="property-button"
                            class:selected={newPropName === prop.name} 
                            on:click={() => newPropName = prop.name}
                        >
                            {prop.label}
                        </button>
                    {/each}
                </div>
            </div>
        </div>
    {:else}
        <div class="properties-list">
            {#if Object.keys(properties).length === 0}
                <div class="no-properties">
                    <p>No custom properties set</p>
                </div>
            {:else}
                {#each Object.entries(properties) as [name, value]}
                    <div class="property-item">
                        <div class="property-name">{name}</div>
                        <div class="property-value">
                            {#if typeof value === 'boolean'}
                                <input 
                                    type="checkbox" 
                                    checked={value} 
                                    on:change={(e) => onUpdate(name, e.target.checked)}
                                />
                            {:else}
                                <input 
                                    type="text" 
                                    value={value} 
                                    on:change={(e) => onUpdate(name, e.target.value)}
                                    on:blur={(e) => onUpdate(name, e.target.value)}
                                />
                            {/if}
                        </div>
                    </div>
                {/each}
            {/if}
        </div>
    {/if}
</div>

<style>
    .node-info {
        font-size: 12px;
    }
    
    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
    }
    
    .header h4 {
        margin: 0;
        font-size: 14px;
        font-weight: 500;
    }
    
    .add-button {
        background: #3a3a3a;
        color: #fff;
        border: none;
        border-radius: 3px;
        width: 24px;
        height: 24px;
        font-size: 16px;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
    }
    
    .add-button:hover {
        background: #4a4a4a;
    }
    
    .node-meta {
        background-color: #2a2a2a;
        border-radius: 4px;
        padding: 10px;
        margin-bottom: 16px;
        position: relative;
    }
    
    .refresh-button {
        position: absolute;
        top: 10px;
        right: 10px;
        background: #333;
        border: none;
        color: #aaa;
        padding: 3px 6px;
        font-size: 10px;
        border-radius: 3px;
        cursor: pointer;
    }
    
    .refresh-button:hover {
        background: #444;
        color: #fff;
    }
    
    .meta-item {
        display: flex;
        margin-bottom: 6px;
    }
    
    .meta-item:last-child {
        margin-bottom: 0;
    }
    
    .meta-label {
        width: 80px;
        color: #999;
        font-size: 11px;
    }
    
    .meta-value {
        color: #ddd;
        font-size: 11px;
    }
    
    .node-id {
        font-family: monospace;
        background: #333;
        padding: 1px 4px;
        border-radius: 2px;
        font-size: 10px;
    }
    
    .add-property-form {
        background-color: #2a2a2a;
        border-radius: 4px;
        padding: 12px;
        margin-bottom: 16px;
    }
    
    .input-group {
        margin-bottom: 10px;
    }
    
    .input-group label {
        display: block;
        margin-bottom: 4px;
        color: #ccc;
        font-size: 11px;
    }
    
    .input-group input {
        width: 100%;
        background-color: #333;
        border: 1px solid #444;
        border-radius: 3px;
        padding: 6px 8px;
        color: #fff;
        font-size: 12px;
    }
    
    .actions {
        display: flex;
        justify-content: flex-end;
        gap: 8px;
        margin-top: 12px;
    }
    
    .cancel-button {
        background: none;
        border: 1px solid #555;
        color: #ccc;
        border-radius: 3px;
        padding: 4px 8px;
        font-size: 11px;
        cursor: pointer;
    }
    
    .cancel-button:hover {
        background: #333;
    }
    
    .add-button-primary {
        background: #4299e1;
        border: none;
        color: white;
        border-radius: 3px;
        padding: 4px 10px;
        font-size: 11px;
        cursor: pointer;
    }
    
    .add-button-primary:hover {
        background: #3182ce;
    }
    
    .common-properties {
        margin-top: 16px;
        border-top: 1px solid #444;
        padding-top: 12px;
    }
    
    .common-properties h5 {
        margin: 0 0 8px 0;
        font-size: 12px;
        font-weight: normal;
        color: #aaa;
    }
    
    .property-list {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        margin-bottom: 12px;
    }
    
    .property-button {
        background: #333;
        border: 1px solid #444;
        color: #ddd;
        border-radius: 3px;
        padding: 3px 8px;
        font-size: 10px;
        cursor: pointer;
    }
    
    .property-button:hover {
        background: #3a3a3a;
    }
    
    .property-button.selected {
        background: #2d4263;
        border-color: #4299e1;
    }
    
    .properties-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
    }
    
    .property-item {
        display: grid;
        grid-template-columns: 1fr 2fr;
        gap: 8px;
        align-items: center;
        padding: 6px 8px;
        background-color: #2a2a2a;
        border-radius: 3px;
    }
    
    .property-name {
        color: #4299e1;
        font-size: 11px;
    }
    
    .property-value input[type="text"] {
        width: 100%;
        background-color: #333;
        border: 1px solid #444;
        border-radius: 3px;
        padding: 4px 6px;
        color: #fff;
        font-size: 11px;
    }
    
    .property-value input[type="checkbox"] {
        width: 16px;
        height: 16px;
        cursor: pointer;
    }
    
    .no-properties {
        padding: 16px 0;
        text-align: center;
        color: #888;
        font-style: italic;
    }
</style>