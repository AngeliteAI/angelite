<script lang="ts">
    import { createEventDispatcher } from "svelte";

    // Props with default values
    let {
        children,
        id = crypto.randomUUID(),
        startX = 0,
        startY = 0,
        mouseX = 0,
        mouseY = 0,
        virtualScale = 0.2,
        selected = false,
        disabled = false,
        bounds = null,
        snapToGrid = false,
        gridSize = 10,
        snapThreshold = 10,
        dragHandleSelector = null,
        zIndexSelected = 10,
        zIndexDragging = 100,
        useTransform = true,
        preserveAspectRatio = false,
        customStyles = "",
        customDraggableClass = "",
        customSelectedClass = "",
        customDraggingClass = "",
    } = $props();

    const dispatch = createEventDispatcher();

    // State variables
    let element: HTMLElement;
    let isDragging = $state(false);
    let position = $state({ x: startX, y: startY });
    let aspectRatio = $state(1);
    let boundingRect = $state(null);

    // Variables to track movement
    let startMouseX = $state(0);
    let startMouseY = $state(0);
    let startPosX = $state(0);
    let startPosY = $state(0);
    
    // Tracking for velocity calculations
    let lastX = $state(0);
    let lastY = $state(0);
    let lastTimestamp = $state(0);

    // Derived values
    let positionStyle = $derived(
        useTransform
            ? `transform: translate(${position.x}px, ${position.y}px)`
            : `left: ${position.x}px; top: ${position.y}px`,
    );

    let zIndexStyle = $derived(
        selected
            ? `z-index: ${zIndexSelected};`
            : isDragging
              ? `z-index: ${zIndexDragging};`
              : "",
    );

    let classNames = $derived(
        [
            "draggable",
            customDraggableClass,
            selected ? `selected ${customSelectedClass}` : "",
            isDragging ? `dragging ${customDraggingClass}` : "",
        ]
            .filter(Boolean)
            .join(" "),
    );

    // Initialize position from props
    $effect(() => {
        position = { x: startX, y: startY };
        console.log(`Draggable ${id}: virtualScale = ${virtualScale}`);
    });

    // Prepare bounds if provided
    function initializeBounds() {
        if (bounds && typeof bounds === "string") {
            const boundsElement = document.querySelector(bounds);
            if (boundsElement) {
                boundingRect = boundsElement.getBoundingClientRect();
            }
        } else if (bounds && typeof bounds === "object") {
            boundingRect = bounds;
        }
    }

    // Calculate aspect ratio if needed
    function calculateAspectRatio() {
        if (element && preserveAspectRatio) {
            const rect = element.getBoundingClientRect();
            aspectRatio = rect.width / rect.height;
        }
    }

    // Handle drag start
    function onPointerDown(event: PointerEvent) {
        if (disabled) return;

        // Only handle left mouse button for mouse events
        if (event.pointerType === "mouse" && event.button !== 0) return;

        // Check if we should only allow dragging from specific handle
        if (dragHandleSelector) {
            let target = event.target as HTMLElement;
            let isHandle = false;

            // Check if target or any of its parents match the handle selector
            while (target && target !== element) {
                if (target.matches(dragHandleSelector)) {
                    isHandle = true;
                    break;
                }
                target = target.parentElement as HTMLElement;
            }

            if (!isHandle) return;
        }

        // Select this element if it's not already selected
        if (!selected) {
            dispatch("select", { id });
        }

        // Prevent default browser behavior
        event.preventDefault();
        
        // Save starting positions for calculating deltas
        startMouseX = event.clientX;
        startMouseY = event.clientY;
        startPosX = position.x;
        startPosY = position.y;

        // Mark as dragging
        isDragging = true;

        // Initialize bounds if needed
        initializeBounds();

        // Calculate aspect ratio if needed
        calculateAspectRatio();

        // Store values for velocity calculation
        lastX = event.clientX;
        lastY = event.clientY;
        lastTimestamp = Date.now();

        // Add window event listeners
        window.addEventListener("pointermove", onPointerMove);
        window.addEventListener("pointerup", onPointerUp);
        window.addEventListener("pointercancel", onPointerUp);

        // Dispatch drag start event
        dispatch("dragstart", {
            id,
            position: { x: position.x, y: position.y },
            event,
        });
    }

    // Handle drag movement
    function onPointerMove(event: PointerEvent) {
        if (!isDragging) return;

        // Get the scale factor
        const scaleFactor = virtualScale > 0 ? virtualScale : 0.2;
        
        // Calculate the movement delta
        const deltaX = event.clientX - startMouseX;
        const deltaY = event.clientY - startMouseY;
        
        // Apply the delta to the starting position, accounting for scale
        let newX = startPosX + (deltaX / scaleFactor);
        let newY = startPosY + (deltaY / scaleFactor);

        // Apply aspect ratio constraint if needed
        if (preserveAspectRatio) {
            // This is simplified - real implementation would be more complex
            const deltaX = newX - position.x;
            const deltaY = newY - position.y;
            if (Math.abs(deltaX) > Math.abs(deltaY)) {
                newY = position.y + deltaX / aspectRatio;
            } else {
                newX = position.x + deltaY * aspectRatio;
            }
        }

        // Apply bounds constraints if specified
        if (boundingRect) {
            const elemRect = element.getBoundingClientRect();

            // Calculate limits - adjust for scale
            const minX = boundingRect.left / scaleFactor;
            const maxX = boundingRect.right / scaleFactor - elemRect.width / scaleFactor;
            const minY = boundingRect.top / scaleFactor;
            const maxY = boundingRect.bottom / scaleFactor - elemRect.height / scaleFactor;

            // Apply constraints
            newX = Math.max(minX, Math.min(maxX, newX));
            newY = Math.max(minY, Math.min(maxY, newY));
        }

        // Calculate velocity
        const timestamp = Date.now();
        const dt = timestamp - lastTimestamp;
        if (dt > 0) {
            const velocityX = ((event.clientX - lastX) / dt) * 100;
            const velocityY = ((event.clientY - lastY) / dt) * 100;

            dispatch("velocityupdate", {
                id,
                velocityX,
                velocityY,
                timestamp,
            });
        }

        // Update last values for next velocity calculation
        lastX = event.clientX;
        lastY = event.clientY;
        lastTimestamp = timestamp;

        // Check for potential snap positions if enabled
        let snappedPosition = snapToGrid ? findSnapPosition(newX, newY) : null;
        let finalPosition = snappedPosition || { x: newX, y: newY };
        
        // Update position
        position = finalPosition;

        // Dispatch position update
        dispatch("positionupdate", {
            id,
            position: finalPosition,
            isSnapped: !!snappedPosition,
        });
    }

    // Handle drag end
    function onPointerUp(event: PointerEvent) {
        if (!isDragging) return;

        // Clean up
        isDragging = false;
        window.removeEventListener("pointermove", onPointerMove);
        window.removeEventListener("pointerup", onPointerUp);
        window.removeEventListener("pointercancel", onPointerUp);

        // Dispatch drag end event
        dispatch("dragend", {
            id,
            finalPosition: { x: position.x, y: position.y },
            event,
        });
    }

    // Find potential snap positions
    function findSnapPosition(x: number, y: number) {
        // Grid snapping
        const snapToGridX = Math.round(x / gridSize) * gridSize;
        const snapToGridY = Math.round(y / gridSize) * gridSize;

        // If we're close to a grid point, snap to it
        if (
            Math.abs(x - snapToGridX) < snapThreshold ||
            Math.abs(y - snapToGridY) < snapThreshold
        ) {
            return {
                x: Math.abs(x - snapToGridX) < snapThreshold ? snapToGridX : x,
                y: Math.abs(y - snapToGridY) < snapThreshold ? snapToGridY : y,
            };
        }

        return null;
    }

    // Update position programmatically
    function setPosition(x: number, y: number) {
        position = { x, y };
        dispatch("positionupdate", {
            id,
            position: { x, y },
            isSnapped: false,
        });
    }

    // Reset to initial position
    function resetPosition() {
        position = { x: startX, y: startY };
        dispatch("positionupdate", {
            id,
            position: { x: startX, y: startY },
            isSnapped: false,
        });
    }

    // Export public methods
    export { setPosition, resetPosition };
</script>

<div
    bind:this={element}
    class="relative {classNames}"
    style="{positionStyle}; {zIndexStyle} {customStyles}"
    onpointerdown={onPointerDown}
    onpointerup={onPointerUp}
>
    {@render children()}
</div>

<style>
    .draggable {
        position: absolute;
        top: 0;
        left: 0;
        cursor: move;
        will-change: transform;
        user-select: none;
        touch-action: none;
        transition:
            box-shadow 0.2s ease,
            transform 0.05s linear;
    }

    .selected {
        box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
    }

    .dragging {
        opacity: 0.9;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
        transition: none;
    }
</style>