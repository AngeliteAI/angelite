<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import Draggable from "./components/Draggable.svelte";
    import Snappable from "./components/Snappable.svelte";
    import Selectable from "./components/Selectable.svelte";
    import { isDraggingAny } from "$lib/store";

    // Props
    let {
        id,
        nodes,
        showBlueprintMode = $bindable(false),
        updateCount = 0,
    } = $props();

    let draggableComponent = $state();

    // Event handling
    const dispatch = createEventDispatcher();

    // Use global drag state instead of local state

    // Helper to convert camelCase to kebab-case for CSS properties
    function camelToKebab(str: string) {
        if (!str) return "";
        if (str.includes("-")) return str; // Already kebab case
        return str.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
    }

    // Forward selection events to parent

    // Direct style setting function
    export function setStyle(name: string, value: string) {
        if (!nodes[id]) return;
        console.log(`Setting style directly: ${id}.${name} = ${value}`);
        nodes[id].styles[name] = value;
        updateCount++;
        return true; // Return success
    }

    // Handle drag events from Snappable to coordinate with Selectable
    function handleDragStart(event) {
        console.log(
            `Node ${id} started dragging - setting isDraggingAny to true`,
        );
        // Set global drag state - VNode is the single source of truth
        isDraggingAny.set(true);
        dispatch("dragstart", { id });
    }

    function handleDragEnd(event) {
        console.log(
            `Node ${id} ended dragging - setting isDraggingAny to false`,
        );
        // Reset global state immediately - VNode is the single source of truth
        isDraggingAny.set(false);

        // Add additional reset with delay to ensure clean state
        setTimeout(() => {
            console.log(`Node ${id} force resetting drag state after timeout`);
            isDraggingAny.set(false);

            // Force reset any drag classes that might be stuck (browser only)
            if (typeof document !== "undefined") {
                document
                    .querySelectorAll(".snappable-dragging, .dragging")
                    .forEach((el) => {
                        el.classList.remove("snappable-dragging", "dragging");
                        if (el instanceof HTMLElement) {
                            el.style.pointerEvents = "auto";
                        }
                    });
            }
        }, 100);

        dispatch("dragend", { id });
    }

    // Handle selection events from Selectable
    function handleSelectionEvent(event) {
        console.log(
            `Node ${id} received selection event, current isDraggingAny: ${$isDraggingAny}`,
        );
        // Forward the event up to the parent
        dispatch("select", event.detail);
    }

    // Handle when Selectable wants to start dragging
    function handleSelectableStartDrag(event) {
        console.log(
            `Node ${id} received startdrag from Selectable for node ${event.detail.id}`,
        );

        draggableComponent.startDrag(event.detail.originalEvent);
    }

    // Get node data
    $effect(() => {
        // This ensures we re-run this effect when updateCount changes
        updateCount;
    });

    let dropSettings = $state({
        within: true,
        append: true,
        before: true,
    });
    let anyDrop = $derived(
        () => dropSettings.within || dropSettings.append || dropSettings.before,
    );
    $effect(() => {
        if (!nodes[id]?.parentId) {
            dropSettings.append = false;
            dropSettings.before = false;
        }
    });
</script>

<div {id}>
    <Selectable
        {id}
        isRoot={!nodes[id]?.parentId}
        on:select={handleSelectionEvent}
        on:startdrag={handleSelectableStartDrag}
    >
        <Snappable
            {id}
            bind:draggable={draggableComponent}
            on:dragstart={handleDragStart}
            on:dragend={handleDragEnd}
        >
            <div
                class="vnode static h-max {nodes[id]?.tagName || 'div'}"
                class:drop-zone={anyDrop}
                class:root={!nodes[id]?.parentId}
                class:blueprint={showBlueprintMode}
                class:dragging={$isDraggingAny}
                data-drop-settings={JSON.stringify(dropSettings)}
                data-node-type={nodes[id]?.tagName || "div"}
                data-node-id={id}
                data-dragging={$isDraggingAny ? "true" : "false"}
                role="button"
                tabindex="0"
                style={Object.entries(nodes[id]?.styles || {})
                    .map(([k, v]) => `${camelToKebab(k)}: ${v}`)
                    .join("; ")}
            >
                <!-- Debug label when in blueprint mode -->
                {#if showBlueprintMode}
                    <div class="node-debug">
                        <span class="tag-name"
                            >&lt;{nodes[id]?.tagName || "div"}&gt;</span
                        >
                        <span class="children-count"
                            >[{nodes[id]?.children?.length || 0} children]</span
                        >
                    </div>
                {/if}

                <!-- Node content -->
                {#if nodes[id]?.props?.textContent}
                    <span class="text-content"
                        >{nodes[id].props.textContent}</span
                    >
                {/if}

                <!-- Recursively render children -->
                {#if nodes[id]?.children?.length > 0}
                    <div class="children static">
                        {#each nodes[id].children as childId (childId)}
                            <svelte:self
                                id={childId}
                                {nodes}
                                {showBlueprintMode}
                                {updateCount}
                            />
                        {/each}
                    </div>
                {/if}
            </div>
        </Snappable>
    </Selectable>
</div>

<style>
    .vnode {
        position: relative;
        min-height: 30px;
        min-width: 30px;
        box-sizing: border-box;
        transition:
            background-color 0.15s ease,
            outline 0.15s ease;
        z-index: 1;
        border: 1px solid rgba(100, 100, 100, 0.2);
        padding: 8px;
        margin: 2px;
        user-select: none;
    }

    .root {
        width: 100%;
        height: 100%;
    }

    .node-debug {
        position: absolute;
        top: -12px;
        left: 0;
        font-size: 10px;
        background: #334155;
        color: white;
        padding: 1px 4px;
        border-radius: 2px;
        z-index: 5;
    }

    .blueprint {
        border: 1px dashed #536b8b;
        padding: 6px;
        margin: 4px;
        background-color: rgba(165, 214, 255, 0.2);
        border-radius: 4px;
    }

    .dragging {
        cursor: grabbing;
        z-index: 100;
        opacity: 0.8;
    }

    .text-content {
        word-break: break-word;
    }

    .children {
        margin-left: 10px;
        position: relative;
        z-index: 2;
    }

    .children .vnode {
        z-index: 2;
    }

    .tag-name {
        color: #a5b4fc;
        font-weight: bold;
    }

    .children-count {
        font-size: 9px;
        color: #a5f3fc;
        margin-left: 4px;
    }
</style>
