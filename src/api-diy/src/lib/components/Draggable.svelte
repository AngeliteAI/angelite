<script lang="ts">
    import { createEventDispatcher, onMount } from "svelte";

    // Props with default values
    import { virtualScale, mouseX, mouseY } from "$lib/store";
    let {
        children,
        id = crypto.randomUUID(),
        absolute = false,
        scaleShift = false,
        startX = 0,
        startY = 0,
        overridable = false,
        overrideX = 0,
        overrideY = 0,
        screenspace = false,
        selected = false,
        disabled = false,
        bounds = null,
        snapToGrid = false,
        gridSize = 10,
        snapThreshold = 10,
        zIndexSelected = 10,
        zIndexDragging = 100,
        useTransform = true,
        preserveAspectRatio = false,
        customStyles = "",
        customDraggableClass = "",
        customSelectedClass = "",
        customDraggingClass = "",
        position = $bindable({ x: startX, y: startY }),
    } = $props();
    let clientWidth = $state();
    let clientHeight = $state();
    const dispatch = createEventDispatcher();

    // State variables
    let element: HTMLElement;
    let isDragging = $state(false);
    let aspectRatio = $state(1);
    let boundingRect = $state(null);

    // Variables to track movement
    let startMouseX = $state(0);
    let startMouseY = $state(0);
    let startPosX = $state(0);
    let startPosY = $state(0);
    let velocityX = $state(0);
    let velocityY = $state(0);
    let dragTargetX = $state(0);
    let dragTargetY = $state(0);
    let targetX = $derived(
        overridable && overrideX != null ? overrideX : dragTargetX,
    );
    let targetY = $derived(
        overridable && overrideY != null ? overrideY : dragTargetY,
    );
    let rotationAngle = $state(0);
    let animationFrame = $state(null);
    let friction = $state(0.8);
    let maxRotation = $state(3);
    let lastSpeed = $state(0);
    let snappedPosition = $state();

    // Tracking for velocity calculations
    let lastX = $state(0);
    let lastY = $state(0);
    let lastTimestamp = $state(0);
    let offset = $state({ x: 0, y: 0 });
    let modified = $derived(position);

    let oldScale = 0;
    let baseMinRotation = $state(0.2);
    let baseMaxRotation = $state(2.0);
    let lastModified = $state();
    $effect(() => {
        if (!element) return;

        // Calculate a size factor (smaller = higher value)
        // Reference size is 100px (gives max rotation)
        // 1000px will give about 1/10th of the rotation
        const sizeFactor = Math.sqrt(clientWidth * clientHeight);

        // Clamp the factor between 0.01 and 1 (so very large elements don't get too little rotation)
        const sizeRatio = (sizeFactor - 10) / (1000 - 10);
        maxRotation =
            baseMinRotation + sizeRatio * (baseMaxRotation - baseMinRotation);
    });

    // Derived values
    let positionStyle = $derived(
        useTransform
            ? `transform: translate(${modified.x}px, ${modified.y}px) rotate(${rotationAngle}deg)`
            : `left: ${modified.x}px; top: ${modified.y}px; transform: rotate(${rotationAngle}deg)`,
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
    onMount(() => {
        position = { x: startX, y: startY };
        console.log(`Draggable ${id}: virtualScale = ${$virtualScale}`);
    });
    // Prepare bounds if provided
    export function move(x, y) {
        position.x += x;
        position.y += y;
    }
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

    export function impulseDirection(rotation, impulse) {
        //get the horizontal and vertical component of the impulse via rotation using trig
        const horizontalComponent =
            impulse * Math.cos(rotation % (2 * Math.PI));
        const verticalComponent = impulse * Math.sin(rotation % (2 * Math.PI));
        console.log(velocityX, velocityY);

        //apply the impulse to the velocity
        velocityX += horizontalComponent;
        velocityY += verticalComponent;
    }

    export function startAnimation() {
        // Cancel any existing animation
        if (animationFrame !== null) {
            cancelAnimationFrame(animationFrame);
        }

        const animate = () => {
            const timestamp = Date.now();
            const dt = Math.min((timestamp - lastTimestamp) / 1000, 1 / 60);

            // Update last values for next velocity calculation
            lastX = position.x;
            lastY = position.y;
            lastTimestamp = timestamp; // Check for potential snap positions if enabled

            // If dragging, move towards target position with some easing
            console.log(
                Math.sqrt(targetX * targetX + targetY * targetY),
                Math.sqrt(position.x * position.x + position.y * position.y),
            );
            let diffX = targetX - position.x;
            let diffY = targetY - position.y;
            console.log(targetX, targetY, position);
            impulseDirection(Math.atan2(diffY, diffX), 1000);
            console.log("YOOOO");
            // Simple easing towards target position (80% of the way there)
            console.log(velocityX, velocityY);
            position.x +=
                (velocityX * dt * (screenspace ? 1 : 1 / $virtualScale)) / 60;
            position.y +=
                (velocityY * dt * (screenspace ? 1 : 1 / $virtualScale)) / 60;

            // Calculate rotation based on velocity
            const direction = Math.sign(velocityX);
            const speed = Math.sqrt(
                velocityX * velocityX + velocityY * velocityY,
            );
            const horizontalFactor =
                Math.abs(velocityX) /
                (Math.abs(velocityX) + Math.abs(velocityY) + 0.1);

            // Set rotation based on velocity
            console.log(
                speed / $virtualScale,
                Math.sqrt(clientWidth * clientHeight) / $virtualScale,
            );
            var threshold = 100;
            rotationAngle =
                speed >
                (threshold * Math.sqrt(clientWidth * clientHeight)) /
                    $virtualScale
                    ? direction *
                      Math.min(speed / 50, 1) *
                      maxRotation *
                      horizontalFactor
                    : 0;
            // If not dragging, apply inertia
            var dragging =
                Math.sqrt(diffX * diffX + diffY * diffY) <
                Math.sqrt(clientWidth * clientHeight) / $virtualScale;
            var decelerating = lastSpeed - speed > 0;
            lastSpeed = speed;
            console.log();

            let approaching = diffX * velocityX + diffY * velocityY > 0;
            let close =
                Math.sqrt(diffX * diffX + diffY * diffY) <
                20 / (screenspace ? 1 : $virtualScale);

            if ((dragging && decelerating) || (approaching && close)) {
                // Apply friction
                velocityX *= friction;
                velocityY *= friction;

                // Reduce rotation gradually
                rotationAngle *= 0.9;
            }

            // Apply bounds if needed
            if (boundingRect) {
                const elemRect = element.getBoundingClientRect();
                const minX = boundingRect.left / $virtualScale;
                const maxX =
                    boundingRect.right / $virtualScale -
                    elemRect.width / $virtualScale;
                const minY = boundingRect.top / $virtualScale;
                const maxY =
                    boundingRect.bottom / $virtualScale -
                    elemRect.height / $virtualScale;

                // Apply bounds with bounce effect
                if (position.x < minX) {
                    position.x = minX;
                    velocityX *= -0.7;
                }

                if (position.x > maxX) {
                    position.x = maxX;
                    velocityX *= -0.7;
                }

                if (position.y < minY) {
                    position.y = minY;
                    velocityY *= -0.7;
                }

                if (position.y > maxY) {
                    position.y = maxY;
                    velocityY *= -0.7;
                }
            }

            // Apply snap to grid if enabled
            if (snapToGrid && !isDragging) {
                snappedPosition = findSnapPosition(position.x, position.y);
                if (snappedPosition && lastModified + 100 < Date.now()) {
                    lastModified = Date.now();
                    position.x = snappedPosition.x;
                    position.y = snappedPosition.y;
                    // Reset velocity when snapped
                    velocityX = 0;
                    velocityY = 0;
                }
            }

            // Dispatch position update
            dispatch("positionupdate", {
                id,
                position: { x: position.x, y: position.y },
                velocity: { x: velocityX, y: velocityY },
                rotation: rotationAngle,
            });

            // Continue animation if dragging or if there's still significant movement
            let useful =
                Math.abs(velocityX) > 0.1 ||
                Math.abs(velocityY) > 0.1 ||
                Math.abs(rotationAngle) > 0.1;
            let distant =
                Math.abs(position.x - targetX) > 1 ||
                Math.abs(position.y - targetY) > 1;
            if (isDragging || (useful && distant)) {
                animationFrame = requestAnimationFrame(animate);
            } else {
                // Reset rotation when stopped and cancel animation
                rotationAngle = 0;
                animationFrame = null;
            }
        };

        animationFrame = requestAnimationFrame(animate);
    }

    // Handle pointer down - prioritize selection over dragging
    function onPointerDown(event: PointerEvent) {
        if (disabled) return;

        // Only handle left mouse button for mouse events
        if (event.pointerType === "mouse" && event.button !== 0) return;

        // Check if we should only allow dragging from specific handle
        const treeWalker = document.createTreeWalker(
            element,
            NodeFilter.SHOW_ELEMENT,
        );
        let isParent = false;
        while (treeWalker.nextNode()) {
            if (
                treeWalker.currentNode ==
                document.elementFromPoint(event.clientX, event.clientY)
            ) {
                break;
            }
            if (treeWalker.currentNode.classList.contains("draggable")) {
                isParent = true;
                break;
            }
        }
        if (isParent) {
            return;
        }

        // Always select first, don't start dragging immediately
        if (!selected) {
            dispatch("select", { id });
            // Stop here for new selections - no dragging
            return;
        }

        // Only start drag if already selected
        if (selected) {
            startDrag(event);
        }
    }

    // Start drag only when called explicitly
    export function startDrag(event) {
        console.log(disabled, isDragging);
        if (disabled || isDragging) return;

        // Prevent default browser behavior and stop propagation to avoid double drag
        event.preventDefault();
        event.stopPropagation();

        // Save starting positions
        startMouseX = event.clientX;
        startMouseY = event.clientY;
        startPosX = position.x;
        startPosY = position.y;

        // Set initial target position to current position
        dragTargetX = position.x;
        dragTargetY = position.y;

        // Mark as dragging
        isDragging = true;

        // Initialize bounds if needed
        initializeBounds();

        // Start animation loop
        startAnimation();

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
        console.log($mouseX);

        $mouseX = event.clientX;
        $mouseY = event.clientY;
        // Calculate the movement delta
        const deltaX =
            (event.clientX - startMouseX) *
            (screenspace ? $virtualScale : 1 / $virtualScale);
        const deltaY =
            (event.clientY - startMouseY) *
            (screenspace ? $virtualScale : 1 / $virtualScale);

        // Update target position based on drag
        dragTargetX = startPosX + deltaX;
        dragTargetY = startPosY + deltaY;

        // Calculate velocity
        console.log("drag move");
        dispatch("dragmove", {
            id,
            position: { x: position.x, y: position.y },
            event,
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

        // Explicitly reset pointer events to ensure element is selectable
        if (element) {
            element.style.pointerEvents = "auto";
            // Force a reflow to ensure styles are applied
            element.offsetHeight;
        }

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
    export function setPosition(x: number, y: number) {
        position = { x, y };
        dispatch("positionupdate", {
            id,
            position: { x, y },
            isSnapped: false,
        });
    }

    // Reset to initial position
    export function resetPosition() {
        position = { x: startX, y: startY };
        dispatch("positionupdate", {
            id,
            position: { x: startX, y: startY },
            isSnapped: false,
        });
    }

    // Export public methods
</script>

<div
    bind:this={element}
    bind:clientWidth
    bind:clientHeight
    class:absolute
    class:relative={!absolute}
    class="{classNames} draggable"
    style={disabled
        ? ""
        : `${positionStyle}; ${zIndexStyle} ${customStyles}; width: 100%; height: max-content;`}
    onpointerdown={onPointerDown}
    onpointerup={onPointerUp}
>
    {@render children()}
</div>

<style>
    .draggable {
        top: 0;
        bottom: 0;
        left: 0;
        cursor: move;
        will-change: transform;
        user-select: none;
        touch-action: none;
        transition:
            box-shadow 0.2s ease,
            transform 0.05s ease;
    }

    .selected {
        box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
    }

    .dragging {
        opacity: 0.9;
        box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
        transition: none;
        pointer-events: auto !important;
    }
</style>
