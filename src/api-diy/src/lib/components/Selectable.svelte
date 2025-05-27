<script>
    import { createEventDispatcher, onMount } from "svelte";
    import { selectedNodeId, hoveredNodeId, isDraggingAny } from "$lib/store";

    // Props
    let { children, id, isRoot = false, isDisabled = false } = $props();

    // Event handling
    const dispatch = createEventDispatcher();

    // State tracking
    let isSelected = $derived(id === $selectedNodeId);
    let isHovered = $derived(id === $hoveredNodeId);
    let isMouseDown = $state(false);
    let mouseDownPos = $state({ x: 0, y: 0 });
    let dragThreshold = 5; // pixels
    let isDragDetected = $state(false);
    let element = $derived.by(() => {
        if (typeof document !== "undefined") {
            return document.getElementById(id);
        }
    });
    // Simple selection handling
    function handleSelection(event) {
        console.log(element);
        if (isDisabled) return;
        if (!element) return;
        const treeWalker = document.createTreeWalker(
            element,
            NodeFilter.SHOW_ELEMENT,
        );
        console.log(element);

        let isParent = false;
        let first = null;
        while (treeWalker.nextNode()) {
            let isChild = false;

            if (
                treeWalker.currentNode ==
                document.elementFromPoint(event.clientX, event.clientY)
            ) {
                console.log("a");
                break;
            }
            if (treeWalker.currentNode.classList.contains("selectable")) {
                if (first == null) {
                    first = treeWalker.currentNode;
                } else {
                    isParent = true;
                    console.log("b", treeWalker.currentNode);
                    break;
                }
            }
        }
        if (isParent || first == null) {
            return;
        }

        // Stop propagation and handle selection
        event.stopPropagation();
        event.preventDefault();
        // Select this node
        console.log(`[Selectable] Selecting node: ${id}`);
        selectedNodeId.set(id);
        dispatch("select", { id: id });
    }

    // Handle mousedown - intercept all pointer events to control drag behavior
    function handleMouseDown(event) {
        if (isDisabled) return;

        // Track mouse down state and position
        isMouseDown = true;
        isDragDetected = false;
        mouseDownPos = { x: event.clientX, y: event.clientY };

        // Select immediately if not already selected
        handleSelection(event);

        // Add listeners to detect drag vs click (browser only)
        if (typeof document !== "undefined") {
            document.addEventListener("mousemove", handleMouseMove);
            document.addEventListener("mouseup", handleMouseUp);
        }
    }

    // Detect drag threshold
    function handleMouseMove(event) {
        if (!isMouseDown) return;

        const deltaX = Math.abs(event.clientX - mouseDownPos.x);
        const deltaY = Math.abs(event.clientY - mouseDownPos.y);

        // If we exceed threshold, start dragging
        if (deltaX > dragThreshold || deltaY > dragThreshold) {
            console.log(
                `[Selectable] Drag threshold exceeded for node ${id}, starting drag`,
            );
            isDragDetected = true;
            startDragging(event);

            // Clean up listeners
            if (typeof document !== "undefined") {
                document.removeEventListener("mousemove", handleMouseMove);
                document.removeEventListener("mouseup", handleMouseUp);
            }
        }
    }

    // Handle mouse up - clean up if no drag was detected
    function handleMouseUp(event) {
        isMouseDown = false;

        // Clean up listeners
        if (typeof document !== "undefined") {
            document.removeEventListener("mousemove", handleMouseMove);
            document.removeEventListener("mouseup", handleMouseUp);
        }

        // Reset drag detection after a brief delay
        setTimeout(() => {
            isDragDetected = false;
        }, 10);
    }

    // Start dragging by calling the Draggable component
    function startDragging(event) {
        console.log(`[Selectable] Starting drag for node ${id}`);

        // Set global drag state
        isDraggingAny.set(true);

        // Dispatch event to parent to trigger actual dragging
        dispatch("startdrag", {
            id: id,
            originalEvent: event,
            startPos: mouseDownPos,
        });
    }

    // Handle drag end from actual dragging components
    function handleDragEnd() {
        console.log(`[Selectable] Drag ended for node ${id}`);

        // Reset states
        isMouseDown = false;
        isDragDetected = false;

        // Reset global drag state
        setTimeout(() => {
            isDraggingAny.set(false);
        }, 10);

        // Ensure this node stays selected after dragging
        if (!isSelected) {
            selectedNodeId.set(id);
            dispatch("select", { id: id });
        }
    }

    // Hover handling
    function handleMouseEnter() {
        if (!isDisabled) {
            hoveredNodeId.set(id);
            dispatch("hover", { id: id, isHovering: true });
        }
    }

    function handleMouseLeave() {
        if (!isDisabled && $hoveredNodeId === id) {
            hoveredNodeId.set(null);
            dispatch("hover", { id: id, isHovering: false });
        }
    }
</script>

<div
    class="selectable"
    class:selected={isSelected}
    class:hovered={isHovered && !$isDraggingAny}
    class:root={isRoot}
    class:dragging={$isDraggingAny}
    onmousedown={handleMouseDown}
    ondragend={handleDragEnd}
    onmouseenter={handleMouseEnter}
    onmouseleave={handleMouseLeave}
    data-node-id={id}
    data-selected={isSelected ? "true" : "false"}
    data-dragging={$isDraggingAny ? "true" : "false"}
    role="button"
    tabindex="0"
>
    <div>
        {@render children()}
        {#if isSelected && !$isDraggingAny}
            <div class="selection-indicators">
                <div class="selection-handle top-left"></div>
                <div class="selection-handle top-right"></div>
                <div class="selection-handle bottom-left"></div>
                <div class="selection-handle bottom-right"></div>
            </div>
        {/if}
    </div>
</div>

<style>
    .selectable {
        position: relative;
        transition: all 0.15s ease;
        cursor: pointer;
        user-select: none; /* Prevent text selection while selecting/dragging */
    }

    .selected {
        outline: 3px solid #4299e1 !important;
        z-index: 10;
        box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.5);
        position: relative; /* Ensure z-index works */
        pointer-events: auto !important; /* Ensure element can be clicked */
    }

    .hovered:not(.selected) {
        outline: 1px dashed #4299e1;
    }

    /* Reset dragging state styles when not dragging */
    :global(.snappable:not(.snappable-dragging)) {
        pointer-events: auto !important;
    }

    .dragging {
        cursor: grabbing !important;
        z-index: 100;
        outline: none !important; /* Remove outline during drag */
    }

    .root {
        z-index: 1;
    }

    .selection-indicators {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        pointer-events: none;
        z-index: 999; /* Ensure visible above other elements */
    }

    .selection-handle {
        position: absolute;
        width: 8px;
        height: 8px;
        background: white;
        border: 2px solid #4299e1;
        z-index: 15;
        pointer-events: none; /* Ensure handles don't interfere with interaction */
        border-radius: 50%; /* Make handles round */
        box-shadow: 0 0 3px rgba(0, 0, 0, 0.3);
    }

    .top-left {
        top: -4px;
        left: -4px;
    }

    .top-right {
        top: -4px;
        right: -4px;
    }

    .bottom-left {
        bottom: -4px;
        left: -4px;
    }

    .bottom-right {
        bottom: -4px;
        right: -4px;
    }
</style>
