<script lang="ts">
    // Props
    let {
        styles = {},
        onUpdate = (name, value) => {},
        onRemove = (name) => {},
    } = $props();
    
    // State
    let newStyleName = $state("");
    let newStyleValue = $state("");
    let isAdding = $state(false);
    
    // Common CSS properties for quick access
    const commonProperties = [
        { name: "width", examples: ["100px", "50%", "auto"] },
        { name: "height", examples: ["100px", "50%", "auto"] },
        { name: "color", examples: ["#000", "red", "rgba(0,0,0,0.5)"] },
        { name: "background", examples: ["#fff", "transparent", "url(...)"] },
        { name: "margin", examples: ["10px", "10px 20px", "auto"] },
        { name: "padding", examples: ["10px", "10px 20px 10px 20px"] },
        { name: "font-size", examples: ["16px", "1.2em", "1rem"] },
        { name: "font-weight", examples: ["normal", "bold", "500"] },
        { name: "border", examples: ["1px solid #ccc", "none"] },
        { name: "border-radius", examples: ["4px", "50%"] },
        { name: "display", examples: ["block", "flex", "grid", "none"] },
        { name: "position", examples: ["relative", "absolute", "fixed"] },
    ];
    
    // For kebab-case to camelCase conversion
    function kebabToCamel(kebab) {
        if (!kebab) return '';
        return kebab.replace(/-([a-z])/g, (g) => g[1].toUpperCase());
    }
    
    function camelToKebab(camel) {
        if (!camel) return '';
        // If already kebab-case, return as is
        if (camel.includes('-')) return camel;
        return camel.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
    }
    
    // Handle adding a new style
    function addStyle() {
        if (!newStyleName.trim()) return;
        
        // Convert kebab-case to camelCase if needed
        const camelName = newStyleName.includes('-') 
            ? kebabToCamel(newStyleName) 
            : newStyleName;
            
        console.log(`Adding style: ${camelName} = ${newStyleValue}`);
        
        // Apply the style multiple times to ensure it's set
        onUpdate(camelName, newStyleValue || '');
        
        // Apply the style again to ensure it's set
        setTimeout(() => {
            onUpdate(camelName, newStyleValue || '');
            
            // And one more time for good measure
            setTimeout(() => {
                onUpdate(camelName, newStyleValue || '');
            }, 100);
        }, 10);
        
        // Reset form
        newStyleName = "";
        newStyleValue = "";
        isAdding = false;
    }
    
    // Handle style property click
    function selectCommonProperty(name) {
        newStyleName = name;
    }
</script>

<div class="style-editor">
    <div class="header">
        <h4>Styles</h4>
        <button 
            class="add-button" 
            on:click={() => isAdding = !isAdding}
            aria-label={isAdding ? "Cancel adding style" : "Add new style"}
        >
            {isAdding ? "✕" : "+"}
        </button>
    </div>
    
    {#if isAdding}
        <div class="add-style-form">
            <div class="input-group">
                <label for="style-name">Property</label>
                <input 
                    type="text" 
                    id="style-name" 
                    placeholder="e.g. color, width" 
                    bind:value={newStyleName}
                />
            </div>
            <div class="input-group">
                <label for="style-value">Value</label>
                <input 
                    type="text" 
                    id="style-value" 
                    placeholder="e.g. red, 100px" 
                    bind:value={newStyleValue}
                />
            </div>
            <div class="actions">
                <button class="cancel-button" on:click={() => isAdding = false}>Cancel</button>
                <button class="add-style-button" on:click={addStyle}>Add Style</button>
            </div>
            
            <div class="common-properties">
                <h5>Common Properties</h5>
                <div class="property-list">
                    {#each commonProperties as prop}
                        <button 
                            class="property-button"
                            class:selected={newStyleName === prop.name} 
                            on:click={() => selectCommonProperty(prop.name)}
                        >
                            {prop.name}
                        </button>
                    {/each}
                </div>
                
                {#if newStyleName}
                    {#each commonProperties.filter(p => p.name === newStyleName) as prop}
                        <div class="examples">
                            <span class="examples-label">Examples:</span>
                            {#each prop.examples as example}
                                <button 
                                    class="example-button"
                                    on:click={() => newStyleValue = example}
                                >
                                    {example}
                                </button>
                            {/each}
                        </div>
                    {/each}
                {/if}
            </div>
        </div>
    {:else}
        <div class="styles-list">
            {#if Object.keys(styles).length === 0}
                <div class="no-styles">
                    <p>No styles applied to this element</p>
                </div>
            {:else}
                {#each Object.entries(styles) as [name, value]}
                    <div class="style-item">
                        <div class="style-name">{camelToKebab(name)}</div>
                        <div class="style-value">
                            <input 
                                type="text" 
                                value={value} 
                                on:keyup={(e) => {
                                    // Update immediately on every keystroke
                                    onUpdate(name, e.target.value);
                                }}
                                on:input={(e) => {
                                    // Update on input
                                    onUpdate(name, e.target.value);
                                }}
                                on:change={(e) => {
                                    // Also update on change event
                                    onUpdate(name, e.target.value);
                                }}
                                on:blur={(e) => {
                                    // Final update on blur
                                    onUpdate(name, e.target.value);
                                }}
                            />
                            <button 
                                class="update-button" 
                                on:click={(e) => {
                                    const input = e.target.closest('.style-item').querySelector('input');
                                    if (input) {
                                        // Force apply the style value multiple times
                                        onUpdate(name, input.value);
                                        console.log(`Applied style ${name} = ${input.value} via button click`);
                                        
                                        // Apply again after a short delay
                                        setTimeout(() => {
                                            onUpdate(name, input.value);
                                        }, 50);
                                    }
                                }}
                                aria-label="Apply style"
                            >
                                ✓
                            </button>
                        </div>
                        <button 
                            class="remove-button" 
                            on:click={() => onRemove(name)}
                            aria-label="Remove style"
                        >
                            ✕
                        </button>
                    </div>
                {/each}
            {/if}
        </div>
    {/if}
</div>

<style>
    .style-editor {
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
    
    .add-style-form {
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
    
    .add-style-button {
        background: #4299e1;
        border: none;
        color: white;
        border-radius: 3px;
        padding: 4px 10px;
        font-size: 11px;
        cursor: pointer;
    }
    
    .add-style-button:hover {
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
    
    .examples {
        background: #333;
        border-radius: 3px;
        padding: 8px;
        margin-top: 8px;
    }
    
    .examples-label {
        display: block;
        margin-bottom: 6px;
        font-size: 10px;
        color: #aaa;
    }
    
    .example-button {
        background: #444;
        border: none;
        color: #ddd;
        border-radius: 3px;
        padding: 2px 6px;
        margin-right: 6px;
        margin-bottom: 6px;
        font-size: 10px;
        cursor: pointer;
    }
    
    .example-button:hover {
        background: #555;
    }
    
    .styles-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
    }
    
    .style-item {
        display: grid;
        grid-template-columns: 1fr 2.5fr auto;
        gap: 8px;
        align-items: center;
        padding: 6px 8px;
        background-color: #2a2a2a;
        border-radius: 3px;
    }
    
    .style-name {
        color: #4299e1;
        font-size: 11px;
    }
    
    .style-value {
        display: flex;
        align-items: center;
        gap: 4px;
    }
    
    .style-value input {
        flex: 1;
        background-color: #333;
        border: 1px solid #444;
        border-radius: 3px;
        padding: 4px 6px;
        color: #fff;
        font-size: 11px;
    }
    
    .update-button {
        background: #2d7e3a;
        border: none;
        color: white;
        width: 18px;
        height: 18px;
        border-radius: 3px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 9px;
        cursor: pointer;
        padding: 0;
        margin-left: 2px;
    }
    
    .update-button:hover {
        background: #3c9e4a;
    }
    
    .remove-button {
        background: none;
        border: none;
        color: #888;
        width: 20px;
        height: 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 10px;
        cursor: pointer;
        border-radius: 2px;
    }
    
    .remove-button:hover {
        background: #444;
        color: #fff;
    }
    
    .no-styles {
        padding: 16px 0;
        text-align: center;
        color: #888;
        font-style: italic;
    }
</style>