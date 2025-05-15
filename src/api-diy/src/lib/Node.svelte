<script lang="ts">
    import { onMount } from "svelte";
    import Snappable from "./components/Snappable.svelte";

    // Use proper TypeScript types
    type NodeId = string;
    type NodeProps = Record<string, any>;
    type StyleProps = Record<string, any>;

    // Node Props
    let {
        id = crypto.randomUUID(),
        tagName = "div",
        parentId = null as NodeId | null,
        children = [],
        props = {},
        styleProps = {},
        selectedNodeId = $bindable<NodeId | null>(null),
        showBlueprintMode = false,
    } = $props();

    // Node registry for the entire tree
    let nodesRegistry = $state<Map<NodeId, any>>(new Map());

    // Register current node in the registry immediately
    nodesRegistry.set(id, {
        id,
        tagName,
        parentId,
        children,
        props,
        styleProps,
        appendChild,
        insertBefore,
        removeChild,
        setStyle,
        setProperty,
    });

    console.log(`Node registered: ${id} (${tagName})`);
    
    // Also register on mount for safety
    onMount(() => {
        console.log(`Node mounted: ${id} (${tagName})`);
        
        // Force styling update
        const domElement = document.querySelector(`[data-node-id="${id}"]`);
        if (domElement) {
            console.log(`DOM element found for node ${id}`);
            Object.entries(styleProps || {}).forEach(([key, value]) => {
                const propertyName = key.replace(/([A-Z])/g, (match) => `-${match.toLowerCase()}`);
                (domElement as HTMLElement).style.setProperty(propertyName, value as string);
            });
        } else {
            console.warn(`DOM element NOT found for node ${id}`);
        }

        // Clean up on unmount
        return () => {
            console.log(`Node unmounted: ${id}`);
            nodesRegistry.delete(id);
        };
    });

    // Node methods
    function appendChild(childId: NodeId) {
        if (!children.includes(childId)) {
            children = [...children, childId];

            // Update the child's parentId reference
            const childNode = nodesRegistry.get(childId);
            if (childNode) {
                childNode.parentId = id;
            }
        }
    }

    function insertBefore(childId: NodeId, referenceId: NodeId | null) {
        if (referenceId) {
            const index = children.indexOf(referenceId);
            if (index !== -1) {
                const newChildren = [...children];
                newChildren.splice(index, 0, childId);
                children = newChildren;
            } else {
                appendChild(childId);
            }
        } else {
            appendChild(childId);
        }

        // Update the child's parentId reference
        const childNode = nodesRegistry.get(childId);
        if (childNode) {
            childNode.parentId = id;
        }
    }

    function removeChild(childId: NodeId) {
        const index = children.indexOf(childId);
        if (index !== -1) {
            const newChildren = [...children];
            newChildren.splice(index, 1);
            children = newChildren;

            // Update the child's parentId reference
            const childNode = nodesRegistry.get(childId);
            if (childNode) {
                childNode.parentId = null;
            }
        }
    }

    function setStyle(property: string, value: any) {
        console.log(`[Node ${id}] Setting style ${property} = ${value}`);
        styleProps = { ...styleProps, [property]: value };

        // Force update of DOM element if it exists
        try {
            const domElement = document.querySelector(`[data-node-id="${id}"]`);
            if (domElement) {
                // Apply style directly to DOM element
                const propertyName = property.replace(
                    /([A-Z])/g,
                    (match) => `-${match.toLowerCase()}`,
                ); // camelCase to kebab-case
                (domElement as HTMLElement).style.setProperty(
                    propertyName,
                    value,
                );
                console.log(
                    `Applied style ${propertyName}=${value} to DOM element ${id}`,
                );
            } else {
                console.warn(`Could not find DOM element for node ${id}`);
            }
        } catch (e) {
            console.warn(`Error updating DOM for node ${id}:`, e);
        }
    }

    function setProperty(name: string, value: any) {
        props = { ...props, [name]: value };
    }

    // UI event handlers
    function handleClick(event: MouseEvent) {
        // Important fix for the parent selection issue
        // Get the actual DOM element at the exact click position
        const elemUnderClick = document.elementFromPoint(
            event.clientX,
            event.clientY,
        );

        // Find the closest node-containing element from exact click position
        const nodeUnderClick = elemUnderClick
            ? elemUnderClick.closest("[data-node-id]")
            : null;

        // If we found a different node (not this one) and it's a direct descendant of this node
        if (
            nodeUnderClick &&
            nodeUnderClick !== event.currentTarget &&
            (event.currentTarget as HTMLElement).contains(
                nodeUnderClick as HTMLElement,
            )
        ) {
            // Do not handle this event - let the child handle it
            return;
        }

        // We're the actual target, so stop the event here
        event.stopPropagation();
        event.preventDefault();

        // Select this node
        selectedNodeId = id;
    }

    // Helper functions
    function isSelected() {
        return id === selectedNodeId;
    }

    function camelToKebab(str: string) {
        return str.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
    }

    // Svelte 5 effects
    $effect(() => {
        if (selectedNodeId === id) {
            const element = document.querySelector(`[data-node-id="${id}"]`);
            if (element) {
                element.classList.add("selected");
            }
        }
    });

    // Expose node API for parent components
    export function getNodeById(nodeId: NodeId) {
        return nodesRegistry.get(nodeId);
    }

    // Create node helper method to be used by parent components
    export function createNode(
        newTagName: string,
        newParentId: NodeId | null = null,
    ) {
        const newId = crypto.randomUUID();
        const NodeComponent = this;

        // Create and register a new node component
        const newNode = new NodeComponent({
            target: document.createElement("div"), // Temporary target
            props: {
                id: newId,
                tagName: newTagName,
                parentId: newParentId,
                selectedNodeId,
                showBlueprintMode,
            },
        });

        if (newParentId) {
            const parentNode = nodesRegistry.get(newParentId);
            if (parentNode) {
                parentNode.appendChild(newId);
            }
        }

        return newId;
    }
</script>

<Snappable>
    <div
        class="node {tagName} reorderable"
        class:root={parentId == null}
        class:selected={isSelected()}
        class:blueprint={showBlueprintMode}
        id={id}
        data-node-id={id}
        data-node-type={tagName}
        draggable={isSelected()}
        onclick={handleClick}
        role="button"
        tabindex="0"
        onkeydown={(e) => e.key === "Enter" && handleClick(e)}
        style={Object.entries(styleProps || {}).map(([k, v]) => `${camelToKebab(k)}: ${v}`).join('; ')}
    >
        {#if showBlueprintMode}
            <div class="node-content">
                <span class="tag-name">&lt;{tagName}&gt;</span>
                {#if props?.textContent}
                    <span class="text-content">"{props.textContent}"</span>
                {/if}
            </div>
        {:else if props?.textContent}
            <span>{props.textContent}</span>
        {/if}

        {#if children && children.length > 0}
            <div class="children">
                {#each children as childId}
                    {#if nodesRegistry.has(childId)}
                        <svelte:self
                            id={childId}
                            tagName={nodesRegistry.get(childId)?.tagName || 'div'}
                            parentId={id}
                            children={nodesRegistry.get(childId)?.children ||
                                []}
                            props={nodesRegistry.get(childId)?.props || {}}
                            styleProps={nodesRegistry.get(childId)
                                ?.styleProps || {}}
                            {selectedNodeId}
                            {showBlueprintMode}
                        />
                    {/if}
                {/each}
            </div>
        {/if}
    </div>
</Snappable>

<style>
    .root {
        width: 100%;
        height: 100%;
    }
    .node {
        position: relative;
        min-height: 20px;
        min-width: 20px;
        box-sizing: border-box;
        transition:
            background-color 0.15s ease,
            outline 0.15s ease;
        /* Add this to ensure proper stacking */
        z-index: 1;
    }

    .node.selected {
        outline: 2px solid #4299e1;
        /* Increase z-index when selected */
        z-index: 10;
        box-shadow: 0 0 0 2px rgba(66, 153, 225, 0.5);
    }

    .node.dragging {
        opacity: 0.6;
    }

    .node.blueprint {
        border: 1px dashed #536b8b;
        padding: 6px;
        margin: 4px;
        background-color: rgba(165, 214, 255, 0.1);
        border-radius: 4px;
    }

    .node-content {
        font-family: monospace;
        font-size: 12px;
        color: #64748b;
    }

    .tag-name {
        color: #9333ea;
        font-weight: bold;
    }

    .text-content {
        color: #059669;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 100px;
    }

    .children {
        margin-left: 10px;
        position: relative;
        /* Make sure children are stacked above parent to capture events first */
        z-index: 2;
        /* Allow clicks to go to children first */
        pointer-events: none;
    }

    /* Make sure items in children container can receive events */
    .children .node {
        z-index: 2;
        pointer-events: auto;
    }

    /* When selected, boost even higher */
    .node.selected {
        z-index: 10 !important;
    }

    .node.drop-before {
        position: relative;
    }

    .node.drop-before::before {
        content: "";
        position: absolute;
        top: -2px;
        left: 0;
        right: 0;
        height: 4px;
        background-color: #4299e1;
        z-index: 11;
    }

    .node.drop-after {
        position: relative;
    }

    .node.drop-after::after {
        content: "";
        position: absolute;
        bottom: -2px;
        left: 0;
        right: 0;
        height: 4px;
        background-color: #4299e1;
        z-index: 11;
    }

    .node.drop-inside {
        background-color: rgba(66, 153, 225, 0.1);
        outline: 2px dashed #4299e1;
        outline-offset: -2px;
    }

    :global(.drag-ghost) {
        position: fixed;
        pointer-events: none;
        z-index: 1000;
        opacity: 0.7;
        box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
        transform: translate(-50%, -50%);
        transform-origin: center center;
        transition: transform 0.05s ease;
        backdrop-filter: blur(1px);
        will-change: transform, left, top;
    }

    :global(body.dragging) {
        cursor: grabbing !important;
    }
</style>
