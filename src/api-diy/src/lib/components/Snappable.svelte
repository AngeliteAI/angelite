<script>
    import { createEventDispatcher } from "svelte";
    import Draggable from "./Draggable.svelte";
    import { mouseX, mouseY, virtualScale, isDraggingAny } from "$lib/store";
    import { nonpassive } from "svelte/legacy";
    import Page from "../../routes/+page.svelte";

    let {
        children,
        id = crypto.randomUUID(),
        draggable = $bindable(),
        position = $bindable({ x: 0, y: 0 }),
        dropZoneQuery = ".drop-zone", // CSS selector for valid drop zones
        animationDuration = 300, // Duration of smooth animations in ms
        dropThreshold = 0.5, // How much of element needs to be inside drop zone (0-1)
        includeParentsAsDropZones = true, // Whether parent elements can be drop zones
        previewMode = false, // If true, shows preview but doesn't actually move elements
    } = $props();

    $effect(() => {
        draggable = draggableComponent;
    });
    let width = $state("100%");
    let height = $state("100%");

    let dispatch = createEventDispatcher();

    let clientWidth = $state();
    let clientHeight = $state();
    let offsetWidth = $state();
    let offsetHeight = $state();
    let realOffsetHeight = $state();
    let element = $derived.by(() => {
        if (typeof document === "undefined") return null;
        return document.getElementById(id);
    });
    let draggingEnabled = $state(true);
    let draggableComponent = $state();
    let isDragging = $state(false);
    let isSnapped = $state(false);
    let hasTransitioned = $state(false);
    let startParent = $state(null);
    let startIndex = $state(-1);
    let overrideX = $state(0);
    let overrideY = $state(0);
    let startRect = $state(null);
    let currentDropZone = $state(); // The element we are currently considering dropping into/relative to
    let dropPosition = $state(); // The action to take (e.g., 'insertBefore', 'appendTo')
    let dropPreviewElement = $state();
    let originalStyle = $state(); // The DOM element used for preview

    let lastSnappedDraggablePosition = $state({ x: null, y: null });
    let isStickilySnapped = $state(false);

    // Export function to safely access draggable component
    export function startExternalDrag(event) {
        if (draggableComponent && draggableComponent.startDrag) {
            draggableComponent.startDrag(event);
        }
    }

    function handleDragStart(customEvent) {
        let event = customEvent.detail; // Draggable component wraps native event in detail
        if (!draggingEnabled || !element) return;

        isDragging = true;

        startParent = event.startParent || element.parentElement;
        startIndex =
            event.startIndex !== undefined
                ? event.startIndex
                : startParent
                  ? Array.from(startParent.children).indexOf(element)
                  : 0;
        startRect = element.getBoundingClientRect(); // Capture original rect for delta calculations

        element.classList.add("snappable-dragging");

        originalStyle = window.getComputedStyle(element);

        isStickilySnapped = false; // Reset sticky snap state
        lastSnappedDraggablePosition.x = null;
        lastSnappedDraggablePosition.y = null;

        dispatch("dragstart", {
            id,
            position: event.position, // Assuming Draggable event.detail contains position
            startParent,
            startIndex,
        });
    }

    function checkDropZones() {
        console.log(element);
        const draggedElRect = element?.getBoundingClientRect();
        const draggedElStyle = window.getComputedStyle(element);
        const draggedMarginTop = parseFloat(draggedElStyle.marginTop) || 0;
        const draggedMarginBottom =
            parseFloat(draggedElStyle.marginBottom) || 0;
        const draggedMarginLeft = parseFloat(draggedElStyle.marginLeft) || 0;
        const draggedMarginRight = parseFloat(draggedElStyle.marginRight) || 0;

        const parentEl = element.parentElement;
        const SNAP_THRESHOLD_PX = 15; // Raw pixels, scale adjustment will be applied where needed
        const snapThreshold = SNAP_THRESHOLD_PX / $virtualScale;

        // --- Part 1: Snapping to gaps between siblings ---
        if (parentEl) {
            const children = Array.from(parentEl.children);
            for (const siblingEl of children) {
                if (siblingEl === element) continue;

                const siblingRect = siblingEl.getBoundingClientRect();
                const siblingStyle = window.getComputedStyle(siblingEl);
                const siblingMarginTop =
                    parseFloat(siblingStyle.marginTop) || 0;
                const siblingMarginBottom =
                    parseFloat(siblingStyle.marginBottom) || 0;
                const siblingMarginLeft =
                    parseFloat(siblingStyle.marginLeft) || 0;
                const siblingMarginRight =
                    parseFloat(siblingStyle.marginRight) || 0;

                // Vertical gap (implies horizontal overlap with sibling)
                const horizontalOverlap = Math.max(
                    0,
                    Math.min(draggedElRect.right, siblingRect.right) -
                        Math.max(draggedElRect.left, siblingRect.left),
                );
                const minHorizontalOverlapForVerticalSnap =
                    Math.min(draggedElRect.width, siblingRect.width) * 0.3;

                if (horizontalOverlap > minHorizontalOverlapForVerticalSnap) {
                    // Check for space ABOVE sibling (draggedEl would be placed before siblingEl)
                    const gapTopEdge = siblingRect.top - siblingMarginTop;
                    const draggedBottomEdgeWithMargin =
                        draggedElRect.bottom + draggedMarginBottom;
                    if (
                        Math.abs(draggedBottomEdgeWithMargin - gapTopEdge) <
                            snapThreshold &&
                        $mouseY < gapTopEdge &&
                        $mouseY >
                            gapTopEdge - siblingRect.height / 2 - snapThreshold
                    ) {
                        // Mouse is in upper half of conceptual gap
                        return {
                            dropTarget: parentEl,
                            referenceElement: siblingEl,
                            dropAction: "before",
                        };
                    }

                    // Check for space BELOW sibling (draggedEl would be placed after siblingEl)
                    const gapBottomEdge =
                        siblingRect.bottom + siblingMarginBottom;
                    const draggedTopEdgeWithMargin =
                        draggedElRect.top - draggedMarginTop;
                    if (
                        Math.abs(draggedTopEdgeWithMargin - gapBottomEdge) <
                            snapThreshold &&
                        $mouseY > gapBottomEdge &&
                        $mouseY <
                            gapBottomEdge +
                                siblingRect.height / 2 +
                                snapThreshold
                    ) {
                        // Mouse is in lower half of conceptual gap
                        return {
                            dropTarget: parentEl,
                            referenceElement: siblingEl.nextSibling,
                            dropAction: "after",
                        }; // insertAfter effectively
                    }
                }

                // Horizontal gap (implies vertical overlap with sibling)
                const verticalOverlap = Math.max(
                    0,
                    Math.min(draggedElRect.bottom, siblingRect.bottom) -
                        Math.max(draggedElRect.top, siblingRect.top),
                );
                const minVerticalOverlapForHorizontalSnap =
                    Math.min(draggedElRect.height, siblingRect.height) * 0.3;

                if (verticalOverlap > minVerticalOverlapForHorizontalSnap) {
                    // Check for space LEFT of sibling (draggedEl would be placed before siblingEl)
                    const gapLeftEdge = siblingRect.left - siblingMarginLeft;
                    const draggedRightEdgeWithMargin =
                        draggedElRect.right + draggedMarginRight;
                    if (
                        Math.abs(draggedRightEdgeWithMargin - gapLeftEdge) <
                            snapThreshold &&
                        $mouseX < gapLeftEdge &&
                        $mouseX >
                            gapLeftEdge - siblingRect.width / 2 - snapThreshold
                    ) {
                        // Mouse in left half of conceptual gap
                        return {
                            dropTarget: parentEl,
                            referenceElement: siblingEl,
                            dropAction: "before",
                        };
                    }

                    // Check for space RIGHT of sibling (draggedEl would be placed after siblingEl)
                    const gapRightEdge = siblingRect.right + siblingMarginRight;
                    const draggedLeftEdgeWithMargin =
                        draggedElRect.left - draggedMarginLeft;
                    if (
                        Math.abs(draggedLeftEdgeWithMargin - gapRightEdge) <
                            snapThreshold &&
                        $mouseX > gapRightEdge &&
                        $mouseX <
                            gapRightEdge + siblingRect.width / 2 + snapThreshold
                    ) {
                        // Mouse in right half of conceptual gap
                        return {
                            dropTarget: parentEl,
                            referenceElement: siblingEl.nextSibling,
                            dropAction: "after",
                        }; // insertAfter effectively
                    }
                }
            }
        }

        // --- Part 2: Fallback to checking designated .drop-zone elements ---
        let queryTargetElements = document.querySelectorAll(dropZoneQuery);
        let potentialDropZones = [];

        for (let i = 0; i < queryTargetElements.length; i++) {
            const currentQueryEl = queryTargetElements[i];
            if (currentQueryEl === element) continue; // Skip self

            let depth = 0;
            let tempParent = currentQueryEl.parentElement;
            let isDescendantOfDragged = false;
            while (tempParent != null) {
                if (tempParent === element) {
                    isDescendantOfDragged = true;
                    break;
                }
                tempParent = tempParent.parentElement;
                depth++;
            }
            if (isDescendantOfDragged) continue;

            potentialDropZones.push({
                domElement: currentQueryEl,
                depth: depth,
            });
        }

        potentialDropZones.sort((a, b) => b.depth - a.depth); // Deeper or more specific targets first

        const directHoverMargin = 1 / $virtualScale;
        for (let i = 0; i < potentialDropZones.length; i++) {
            const zoneInfo = potentialDropZones[i];
            const zoneRect = zoneInfo.domElement.getBoundingClientRect();

            if (
                $mouseX >= zoneRect.left - directHoverMargin &&
                $mouseX <= zoneRect.right + directHoverMargin &&
                $mouseY >= zoneRect.top - directHoverMargin &&
                $mouseY <= zoneRect.bottom + directHoverMargin
            ) {
                // Mouse is over this drop zone. Determine action based on position within it.
                const thirdHeight = zoneRect.height / 3;
                const isContainerLike = true; // Assume for now, could be a prop or class-based check

                if (isContainerLike) {
                    // If it's a container, prioritize dropping inside.
                    // Could further divide into append/prepend based on mouse Y
                    if ($mouseY < zoneRect.top + thirdHeight) {
                        return {
                            dropTarget: zoneInfo.domElement,
                            referenceElement: zoneInfo.domElement.firstChild,
                            dropAction: "prepend",
                        }; // Prepend
                    } else if ($mouseY > zoneRect.bottom - thirdHeight) {
                        return {
                            dropTarget: zoneInfo.domElement,
                            referenceElement: null,
                            dropAction: "append",
                        }; // Append
                    } else {
                        // Middle part of container, default to append or a specific 'inside' action
                        return {
                            dropTarget: zoneInfo.domElement,
                            referenceElement: null,
                            dropAction: "append",
                        };
                    }
                } else {
                    // If not a container, treat as a sibling-like target: insert before or after it.
                    if ($mouseY < zoneRect.top + zoneRect.height / 2) {
                        return {
                            dropTarget: zoneInfo.domElement, // The sibling element
                            referenceElement: zoneInfo.domElement, // Can be the same for clarity or other uses
                            dropAction: "before", // Action is 'before' the dropTarget (sibling)
                        };
                    } else {
                        return {
                            dropTarget: zoneInfo.domElement, // The sibling element
                            referenceElement: zoneInfo.domElement, // Can be the same for clarity or other uses
                            dropAction: "after", // Action is 'after' the dropTarget (sibling)
                        };
                    }
                }
            }
        }

        return { dropTarget: null, referenceElement: null, dropAction: null }; // No valid drop found
    }

    let contentElement = $state();

    function handleDragMove(customEvent) {
        if (!isDragging) return;

        let draggableEventDetail = customEvent.detail || {};
        // Assuming draggableEventDetail.dx & .dy are the total translation from drag start due to mouse

        const {
            dropTarget,
            dropAction,
            referenceElement: newRef,
        } = checkDropZones();

        // 3. Update DOM preview and global/sticky states if a target was determined
        if (dropTarget && dropAction) {
            if (!dropPreviewElement) {
                dropPreviewElement = document.createElement("div");
                dropPreviewElement.classList.add("ghost-placeholder");
            }
            if (dropPosition != dropAction || currentDropZone != dropTarget) {
                hasTransitioned = false;
            }
            currentDropZone = dropTarget;
            dropPosition = dropAction;
            let pre;

            if (dropPreviewElement.parentNode == null) {
                pre = element.getBoundingClientRect();
            } else {
                pre = dropPreviewElement.getBoundingClientRect();
            }

            if (currentDropZone != null && dropPosition != null) {
                moveElement(dropPreviewElement, currentDropZone, dropPosition);
            }
            let newparent = currentDropZone;
            currentDropZone.offsetHeight;
            // The .ghost-placeholder class handles other aspects like background, border, display.
            dropPreviewElement.style = window.getComputedStyle(contentElement);
            console.log(dropPreviewElement.style);
            dropPreviewElement.style.position = "static";
            dropPreviewElement.style.display = "block";
            dropPreviewElement.style.minWidth = `${clientWidth}px`;
            dropPreviewElement.style.minHeight = `${clientHeight}px`;
            dropPreviewElement.offsetHeight;

            const post = dropPreviewElement.getBoundingClientRect();

            element.offsetHeight;
            console.log(element);
            moveElement(element, dropTarget, dropPosition);
            isSnapped = true;
            dropPreviewElement.offsetHeight;
            element.style.zIndex = 1000;

            /**
                 *
                 *  element.style.position = "absolute";
            element.offsetHeight;

            element.style.transform = `translate(${rect.left / $virtualScale}px, ${rect.top / $virtualScale}px)`;
            element.style.transition = 'all 5.0s ease';
            console.log(rect.left+" "+rect.top+"poopopp");
            element.style.transition = 'none';
            element.offsetHeight;
            element.style.transform = `translate(0px, 0px)`;
            hasTransitioned = true;
                 */

            // Calculate initial translation to make element appear at its original spot, relative to new parent
            element.style.position = "fixed";
            const deltaX = (post.x - pre.x) / $virtualScale;
            const deltaY = (post.y - pre.y) / $virtualScale;
            draggableComponent.move(-deltaX, -deltaY);
            if (dropAction == "before" || dropAction == "prepend") {
                let margin = window.getComputedStyle(dropTarget).margin;
                let margins = margin.split(" ");
                let marginBottom =
                    parseFloat(margins[0]) || parseFloat(margins[2]) || 0;
                overrideY = -marginBottom;
            } else if (dropAction == "after" || dropAction == "append") {
                overrideY = -post.height;
            }
            draggableComponent.startAnimation();
        }

        // Dispatch the dragmove event with current details
        dispatch("dragmove", {
            ...(draggableEventDetail || {}), // Use event.detail from the Draggable component
            dropZone: currentDropZone,
            dropPosition: dropPosition,
        });
    }

    function handleDragEnd(customEvent) {
        // Ensure preview is removed from DOM before committing final drop

        element.style = originalStyle;
        element.offsetHeight;
        overrideX = 0;
        overrideY = 0;

        if (!isDragging) return;
        moveElement(element, currentDropZone, dropPosition);
        if (dropPreviewElement) {
            dropPreviewElement.parentNode.removeChild(dropPreviewElement);
            dropPreviewElement = null;
        }
        isDragging = false;
        let draggableEventDetail = customEvent.detail || {};
        element.offsetHeight; // Force reflow after DOM move
        let actualFinalRect = element.getBoundingClientRect();
        console.log(
            "[Snappable handleDragEnd] Actual element BoundingRect AFTER DOM move:",
            actualFinalRect,
        );

        dispatch("drop", {
            id,
            target: currentDropZone, // This is the actionTargetElement
            action: dropPosition,
            originalEvent: draggableEventDetail,
        });

        element.classList.remove("snappable-dragging");

        // Explicitly reset pointer events to ensure element is selectable
        if (element) {
            element.style.pointerEvents = "auto";
            // Force a reflow to ensure styles are applied
            element.offsetHeight;
        }

        // Reset sticky states for the draggable element too
        isStickilySnapped = false;
        lastSnappedDraggablePosition.x = null;
        lastSnappedDraggablePosition.y = null;

        // Reset the position prop for the Draggable component to remove its transform
        position.x = 0;
        position.y = 0;

        startParent = null;
        startIndex = -1;
        startRect = null;

        dispatch("dragend", {
            ...(draggableEventDetail || {}),
            success: !!(currentDropZone && dropPosition),
        });
    }

    // New generic function to move an element (preview or actual) into the DOM
    function moveElement(elementToMove, actionTargetElement, actionName) {
        // --- Logging for moveElement (especially for the main element) ---
        if (elementToMove === element) {
            console.log("[Snappable moveElement] Called for MAIN element.");
            console.log("  elementToMove:", elementToMove);
            console.log("  actionTargetElement:", actionTargetElement);
            console.log("  actionName:", actionName);
            console.log("  previewMode:", previewMode);
        }
        // --- End Logging ---

        // If we are trying to move the main snappable element and it's previewMode, do nothing.
        if (elementToMove === element && previewMode) {
            console.log(
                "[Snappable moveElement] Bailing out: previewMode is true for main element.",
            );
            return;
        }

        if (!actionTargetElement || !elementToMove) {
            console.warn(
                "[Snappable moveElement] Bailing out: Missing elementToMove or actionTargetElement.",
                { elementToMove, actionTargetElement, actionName },
            );
            return;
        }

        // Remove from current parent before re-inserting
        // This ensures it's properly detached if it's already in the DOM (e.g., the preview element)
        if (elementToMove.parentNode) {
            elementToMove.parentNode.removeChild(elementToMove);
        }

        try {
            switch (actionName) {
                case "before": // actionTargetElement is the SIBLING to insert before
                    if (actionTargetElement.parentNode) {
                        actionTargetElement.parentNode.insertBefore(
                            elementToMove,
                            actionTargetElement,
                        );
                    } else {
                        console.error(
                            "moveElement ('before'): actionTargetElement has no parentNode.",
                            actionTargetElement,
                        );
                    }
                    break;
                case "after": // actionTargetElement is the SIBLING to insert after
                    if (actionTargetElement.parentNode) {
                        actionTargetElement.parentNode.insertBefore(
                            elementToMove,
                            actionTargetElement.nextSibling,
                        );
                    } else {
                        console.error(
                            "moveElement ('after'): actionTargetElement has no parentNode.",
                            actionTargetElement,
                        );
                    }
                    break;
                case "append": // actionTargetElement is the CONTAINER
                    actionTargetElement.appendChild(elementToMove);
                    break;
                case "prepend": // actionTargetElement is the CONTAINER
                    actionTargetElement.insertBefore(
                        elementToMove,
                        actionTargetElement.firstChild,
                    );
                    break;
                default:
                    console.warn(
                        "moveElement: Unknown actionName:",
                        actionName,
                        "Falling back to append if possible.",
                    );
                    if (actionTargetElement.appendChild) {
                        // Fallback: attempt to append to actionTargetElement
                        actionTargetElement.appendChild(elementToMove);
                    }
                    break;
            }
        } catch (e) {
            console.error("moveElement: Error during DOM manipulation:", e, {
                elementToMove,
                actionTargetElement,
                actionName,
            });
        }

        // Dispatch 'move' event ONLY if it's the main snappable element being moved and not in previewMode
        if (elementToMove === element && !previewMode) {
            dispatch("move", {
                id,
                fromParent: startParent, // Captured at drag start
                toParent: elementToMove.parentElement,
                // fromIndex: startIndex, // Captured at drag start, could be added if still accurate/needed
                action: actionName,
                targetId: actionTargetElement.id, // ID of the container or sibling
                // referenceId: null // currentReferenceElement could be passed to moveElement if needed for event
            });
        }
    }

    // Helper: Check if mouse is over an element (used for sticky preview)
    function isMouseOverElement(targetElement, x, y, tolerance = 0) {
        const rect = targetElement.getBoundingClientRect();
        return (
            x >= rect.left - tolerance &&
            x <= rect.right + tolerance &&
            y >= rect.top - tolerance &&
            y <= rect.bottom + tolerance
        );
    }
</script>

<div
    style:width
    style:height
    bind:offsetHeight={realOffsetHeight}
    class="snappable {isSnapped ? 'snappable-snapped' : ''} {isDragging
        ? 'snappable-dragging'
        : ''}"
    data-node-id={id}
>
    <Draggable
        bind:this={draggableComponent}
        {id}
        overridable={true}
        {overrideX}
        {overrideY}
        bind:position
        on:dragstart={handleDragStart}
        on:dragmove={handleDragMove}
        on:dragend={handleDragEnd}
    >
        <div
            class="snappable-content"
            bind:this={contentElement}
            bind:clientWidth
            bind:clientHeight
        >
            {@render children()}
        </div>
    </Draggable>
</div>

<style>
    .snappable {
        touch-action: none; /* Prevent scrolling on touch devices when dragging */
        cursor: grab;
        position: relative; /* For absolute positioning of children if needed, or stacking context */
        /* user-select: none; */ /* Might be too aggressive, consider for specific child elements */
    }

    .snappable-dragging {
        opacity: 0.8;
        z-index: 1000000;
        transition: all 0.5s ease-in-out;
        /* transform: scale(1.02); */ /* Subtle scale effect */
        /* box-shadow: 0 4px 12px rgba(0,0,0,0.2); */
        /* Do not change display or position here, let Draggable handle visuals of the item being dragged */
    }

    /* Ghost placeholder style for the preview element when it's part of the DOM flow */
    :global(.ghost-placeholder) {
        box-sizing: border-box; /* Important for width/height calculations */
        display: block;
        position: static;
    }

    /* If you still need a version for an absolutely positioned ghost (not used by current request) */
    /* .drop-preview-absolute {
        position: absolute;
        z-index: 1000;
        pointer-events: none;
        background-color: rgba(59, 130, 246, 0.2);
        border: 1px dashed #3B82F6;
        box-sizing: border-box;
    } */
</style>
