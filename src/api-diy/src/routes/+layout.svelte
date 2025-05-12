<script lang="ts">
    import Dropdown from "$lib/Dropdown.svelte";
    import { onMount } from "svelte";
    import "../app.css";
    import { cubicOut, quartOut } from "svelte/easing";
    import { tweened } from "svelte/motion";
    import { fade, fly } from "svelte/transition";
    import { 
        draggedElement, 
        draggedCurrentX, 
        draggedCurrentY, 
        updateDraggedElement, 
        updateDraggedPosition,
        resetDragState,
        activeVDom
    } from "$lib/VDom.svelte";
    var virtualScale = $state(0.2);
    var offsetX = $state(0); // Content panning X relative to container
    var offsetY = $state(0); // Content panning Y relative to container
    var mouseX = $state(0); // Raw mouse X in viewport
    var mouseY = $state(0); // Raw mouse Y in viewport
    var cameraX = $state(0); // Camera translation X
    var cameraY = $state(0); // Camera translation Y
    var showRightSidebar = $state(true);
    var activeSidebarTab = $state("Style"); // "Style", "Settings", "Interactions"
    let { children } = $props();
    let selectedNodeId = $state<string | null>(null);

    // Read store values with $ syntax
    let elementId = $derived($draggedElement);
    let currentDragX = $derived($draggedCurrentX);
    let currentDragY = $derived($draggedCurrentY);

    // Create tweened values for smooth transitions (for device size changes)
    const tweenedWidth = tweened(1179, { duration: 300, easing: quartOut });
    const tweenedHeight = tweened(2556, { duration: 300, easing: quartOut });

    // --- Removed old device offset/scale saving logic - simplify for now ---
    let virtualDevices = [
        // ... (device definitions unchanged)
        {
            name: "iPhone 16",
            width: 1179,
            height: 2556,
            // Removed scale/offset storage per device for simplicity
        },
        {
            name: "Desktop",
            width: 1920,
            height: 1080,
        },
    ];
    let currentVirtualDeviceIndex = $state(0);
    let currentVirtualDevice = $derived(
        virtualDevices[currentVirtualDeviceIndex],
    );

    // --- Simplified device update logic ---
    function updateDeviceViewport() {
        const newWidth = currentVirtualDevice.width;
        const newHeight = currentVirtualDevice.height;

        // Reset camera/pan on device change for simplicity for now
        cameraX = 0;
        cameraY = 0;
        offsetX = 0;
        offsetY = 0;
        virtualScale = 0.2; // Reset scale too? Maybe make configurable.

        document.documentElement.style.setProperty('--virtual-scale', virtualScale.toString());
        document.documentElement.style.setProperty('--camera-x', `${cameraX}px`);
        document.documentElement.style.setProperty('--camera-y', `${cameraY}px`);
        document.documentElement.style.setProperty('--offset-x', `${offsetX}px`);
        document.documentElement.style.setProperty('--offset-y', `${offsetY}px`);

        tweenedWidth.set(newWidth);
        tweenedHeight.set(newHeight);
    }

    // Define types for padding and margin (keep these)
    type SpacingSide = 'top' | 'right' | 'bottom' | 'left';
    type SpacingObject = {
        top: number;
        right: number;
        bottom: number;
        left: number;
    };

    // --- REMOVE OLD DRAG STATE AND FUNCTIONS ---
    /*
    let isDragging = $state(false);
    let dragType = $state('none');
    let dragStartX = $state(0);
    let dragStartY = $state(0);
    let dragStartCameraX = $state(0);
    let dragStartCameraY = $state(0);
    let dragStartOffsetX = $state(0);
    let dragStartOffsetY = $state(0);
    let isDraggingElement = $state(false);
    let draggedElement = $state<string | null>(null);
    let dropTargetId = $state<string | null>(null);
    let dropTargetIndex = $state<number | null>(null);
    let dropIndicatorPosition = $state<{top: number, left: number, width: number, height: number} | null>(null);
    let initialClickOffsetX = $state(0);
    let initialClickOffsetY = $state(0);
    let initialElementX = $state(0);
    let initialElementY = $state(0);
    let isSnapped = $state(false);
    let snapTargetId = $state<string | null>(null);
    let isTransitioningSnap = $state(false);
    let pendingSnapTargetId = $state<string | null>(null);
    let snapTimeoutId: number | null = $state(null);

    function handleMouseDown(...) { ... }
    function findDropTarget(...) { ... }
    function isDescendant(...) { ... }
    function handleMouseMove(...) { ... }
    function handleMouseUp(...) { ... }
    function handleElementClick(...) { ... }
    function completeSnap(...) { ... }
    function cancelSnapTransition(...) { ... }
    function moveNode(...) { ... } // Old implementation removed
    */
    // --- END REMOVAL ---

    // +++ ADD NEW PHYSICS DRAGGING STATE +++
    let isDragging = $state(false); // Is any drag active (camera, content, or element)?
    let dragType = $state<'camera' | 'content' | 'element' | 'none'>('none'); // What is being dragged?
    let draggedElementRef = $state<HTMLElement | null>(null); // Reference to the actual DOM element

    // Initial positions on drag start
    let dragStartX = $state(0); // Mouse viewport X (or camera/content start)
    let dragStartY = $state(0); // Mouse viewport Y (or camera/content start)
    let initialElementX = $state(0); // Element's initial viewport X (top-left) when drag started
    let initialElementY = $state(0); // Element's initial viewport Y (top-left) when drag started
    let initialCameraX = $state(0); // Camera X at drag start
    let initialCameraY = $state(0); // Camera Y at drag start
    let initialContentOffsetX = $state(0); // Content offsetX at drag start
    let initialContentOffsetY = $state(0); // Content offsetY at drag start
    let initialClickOffsetX = $state(0); // Click offset within element X
    let initialClickOffsetY = $state(0); // Click offset within element Y

    // Physics state (updated in animation loop for element drag)
    let velocityX = $state(0);
    let velocityY = $state(0);
    let currentRotation = $state(0); // Tilt

    // Target state (where the element *wants* to go during element drag)
    let targetX = $state(0); // Target viewport X
    let targetY = $state(0); // Target viewport Y
    let isSnapping = $state(false); // Are we aiming for a snap point?
    let snapTargetId = $state<string | null>(null); // ID of the element to snap relative to
    let snapTargetRect = $state<DOMRect | null>(null); // Bounding rect of the snap target for calculations
    let snapIndicatorPosition = $state<{top: number, left: number, width: number, height: number} | null>(null); // For visual feedback (placeholder)
    let snapPosition = $state<'before' | 'after' | 'inside' | null>(null); // Position relative to snap target

    // Animation loop control
    let rafId: number | null = null;

    // Physics Constants (tune these for the desired feel)
    const springConstant = 0.15;
    const dampingFactor = 0.65;
    const friction = 0.92; // Simulates air resistance/friction
    const tiltFactor = 0.1; // How much velocity affects tilt (degrees per pixel/frame velocity)
    const snapDistanceThreshold = 30; // Screen pixels distance to trigger final snap logic on mouseup
    const snapFinalizeDistanceThreshold = 5; // If element animates within this distance, consider it arrived
    let hasMovedInitially = $state(false);
    // +++ END NEW PHYSICS DRAGGING STATE +++

    function findNodeById(id: string): Node | null {
        //get the node from the dom
        const node = document.getElementById(id);
        return node;
    }

    // Fixed DOM manipulation to use data-node-id
    function moveNode(nodeId: string, targetId: string, position: 'before' | 'after' | 'inside') {
        console.log(`Moving node ${nodeId} ${position} ${targetId}`);
        
        try {
            // Get the elements by data-node-id
            const node = document.querySelector(`[data-node-id="${nodeId}"]`);
            const target = document.querySelector(`[data-node-id="${targetId}"]`);
            
            console.log("Found elements:", node, target);
            
            if (!node || !target) {
                console.error(`Cannot find elements with data-node-id ${nodeId} or ${targetId}`);
                return;
            }
            
            // Reset styles before moving to prevent issues
            node.style.position = '';
            node.style.top = '';
            node.style.left = '';
            node.style.zIndex = '';
            node.style.transform = '';
            node.style.transition = '';
            node.style.opacity = '';
            node.style.boxShadow = '';
            node.style.outline = '';
            node.style.margin = '';
            node.classList.remove('dragging');
            
            console.log(`Moving DOM: ${node.tagName}#${node.id} ${position} ${target.tagName}#${target.id}`);
            
            // Perform the move
            if (position === 'before') {
                target.parentNode?.insertBefore(node, target);
            } 
            else if (position === 'after') {
                if (target.nextSibling) {
                    target.parentNode?.insertBefore(node, target.nextSibling);
                } else {
                    target.parentNode?.appendChild(node);
                }
            } 
            else if (position === 'inside') {
                target.appendChild(node);
            }
            
            // Add visual feedback
            node.animate([
                { backgroundColor: 'rgba(99, 102, 241, 0.2)' },
                { backgroundColor: 'transparent' }
            ], {
                duration: 1000,
                easing: 'ease-out'
            });
            
            console.log(`Successfully moved node ${nodeId} to ${position} ${targetId}`);
        } catch (error) {
            console.error(`Error moving node:`, error);
        }
    }

    // --- Sidebar Styling/Logic (Restore/Keep) ---
    const sidebarWidth = tweened(showRightSidebar ? 300 : 36, {
        duration: 400,
        easing: quartOut,
    });

    const sidebarContentOpacity = tweened(showRightSidebar ? 1 : 0, {
        duration: 300,
        easing: cubicOut,
    });

    function toggleSidebar() {
        showRightSidebar = !showRightSidebar;
        sidebarWidth.set(showRightSidebar ? 300 : 36);
        sidebarContentOpacity.set(showRightSidebar ? 1 : 0);
    }

    function setActiveTab(tab: string) {
        activeSidebarTab = tab;
    }

    // Reactive styling properties for selected node
    let padding = $state<SpacingObject>({ top: 0, right: 0, bottom: 0, left: 0 });
    let margin = $state<SpacingObject>({ top: 0, right: 0, bottom: 0, left: 0 });
    let width = $state("Auto");
    let height = $state("Auto");
    let display = $state("Block");

    // Active spacing side selections
    let activeMarginSide = $state<SpacingSide | null>(null);
    let activePaddingSides = $state<SpacingSide[]>([]);

    function setMarginSide(side: SpacingSide) {
        activeMarginSide = activeMarginSide === side ? null : side;
    }

    function setPaddingSide(side: SpacingSide) {
        if (activePaddingSides.includes(side)) {
            activePaddingSides = activePaddingSides.filter(s => s !== side);
        } else {
            activePaddingSides = [...activePaddingSides, side];
        }
    }

    function updateMargin(value: number) {
        if (activeMarginSide === null) {
            margin = { top: value, right: value, bottom: value, left: value };
        } else {
            margin = { ...margin, [activeMarginSide]: value };
        }
    }

    function updatePadding(value: number) {
        if (activePaddingSides.length === 0) {
            padding = { top: value, right: value, bottom: value, left: value };
        } else {
            const newPadding = { ...padding };
            activePaddingSides.forEach(side => {
                newPadding[side] = value;
            });
            padding = newPadding;
        }
    }

    function selectElement(id: string) {
        selectedNodeId = id;
        padding = { top: 0, right: 0, bottom: 0, left: 0 };
        margin = { top: 0, right: 0, bottom: 0, left: 0 };
        activeMarginSide = null;
        activePaddingSides = [];
    }

    // Helper functions for spacing visualization
    function visualScale(value: number) {
        if (value === 0) return 0;
        return Math.min(Math.floor(Math.log(value + 1) * 10), 25);
    }

    function getContentSize(boxSize: number, paddingVisual: SpacingObject, marginVisual: SpacingObject) {
        return Math.max(
            boxSize -
                paddingVisual.top -
                paddingVisual.bottom -
                marginVisual.top -
                marginVisual.bottom,
            20,
        );
    }

    let marginVisual = $derived({
        top: visualScale(margin.top),
        right: visualScale(margin.right),
        bottom: visualScale(margin.bottom),
        left: visualScale(margin.left),
    });

    let paddingVisual = $derived({
        top: visualScale(padding.top),
        right: visualScale(padding.right),
        bottom: visualScale(padding.bottom),
        left: visualScale(padding.left),
    });
    // --- END Sidebar Styling/Logic ---

    // --- Wheel Zoom (Fix: remove updateDeviceProperties) ---
    function handleWheel(e: WheelEvent) {
        e.preventDefault();

        const viewportElement = document.getElementById('viewport');
        if (!viewportElement) return;

        const rect = viewportElement.getBoundingClientRect();
        const mouseRelativeX = e.clientX - rect.left - rect.width / 2;
        const mouseRelativeY = e.clientY - rect.top - rect.height / 2;

        const oldScale = virtualScale;

        // Calculate the point in the content that's under the mouse
        const contentX = (mouseRelativeX - cameraX) / oldScale;
        const contentY = (mouseRelativeY - cameraY) / oldScale;

        // Determine new scale
        let zoomAmount = 1.1;
        if (e.deltaY >= 0) {
            zoomAmount = 1 / 1.1;
        }
        const newScale = Math.max(0.05, Math.min(2, oldScale * zoomAmount));

        if (oldScale === newScale) return;
        virtualScale = newScale;

        // Calculate the scale ratio
        const scaleRatio = newScale / oldScale;

        // Calculate new camera position using the scale ratio
        cameraX = mouseRelativeX - (mouseRelativeX - cameraX) * scaleRatio;
        cameraY = mouseRelativeY - (mouseRelativeY - cameraY) * scaleRatio;

        // Update CSS variables
        document.documentElement.style.setProperty('--virtual-scale', virtualScale.toString());
        document.documentElement.style.setProperty('--camera-x', `${cameraX}px`);
        document.documentElement.style.setProperty('--camera-y', `${cameraY}px`);

        // REMOVED: updateDeviceProperties(); // This was causing issues
    }

    // Custom type for our drag event
    interface ElementDragStartEvent extends CustomEvent {
        detail: {
            id: string;
            initialX: number;
            initialY: number;
            offsetX: number;
            offsetY: number;
            element: HTMLElement;
        };
    }

    // --- Mount Logic ---
    onMount(() => {
        // Listen for custom drag start events from Node.svelte
        document.addEventListener('element-drag-start', ((e: ElementDragStartEvent) => {
            const detail = e.detail;
            console.log('Got element-drag-start event:', detail);
            
            // Call our existing drag start function with the event details
            isDragging = true;
            dragType = 'element';
            updateDraggedElement(detail.id);
            draggedElementRef = detail.element;
            selectedNodeId = detail.id;
            
            initialElementX = detail.initialX;
            initialElementY = detail.initialY;
            initialClickOffsetX = detail.offsetX;
            initialClickOffsetY = detail.offsetY;
            
            // Initialize physics state
            updateDraggedPosition(initialElementX, initialElementY);
            targetX = initialElementX;
            targetY = initialElementY;
            velocityX = 0;
            velocityY = 0;
            currentRotation = 0;
            isSnapping = false;
            hasMovedInitially = false;
            snapTargetId = null;
            snapTargetRect = null;
            snapIndicatorPosition = null;
            
            if (rafId) cancelAnimationFrame(rafId);
            rafId = requestAnimationFrame(animationLoop);
        }) as EventListener);
    });

    // ... rest of the script ...

    // +++ NEW EVENT HANDLERS & LOGIC +++

    function getDraggingStyles(): string {
        // CRITICAL CHECK: Only apply styles if we are actively dragging an element
        if (!isDragging || dragType !== 'element' || !draggedElementRef || !elementId) {
            return ''; 
        }

        // Calculate translation relative to the element's original position
        const translateX = currentDragX - initialElementX;
        const translateY = currentDragY - initialElementY;

        return `transform: translate(${translateX.toFixed(2)}px, ${translateY.toFixed(2)}px) rotate(${currentRotation.toFixed(2)}deg); transition: none;`;
    }

    const snapZonePadding = 40; // Pixels of padding around snap target to keep it sticky

    function isMouseInSnapZone(rect: DOMRect): boolean {
        if (!rect) return false;
        return (
            mouseX >= rect.left - snapZonePadding &&
            mouseX <= rect.right + snapZonePadding &&
            mouseY >= rect.top - snapZonePadding &&
            mouseY <= rect.bottom + snapZonePadding
        );
    }

    // Fix type for findSnapTarget
    type SnapTarget = { 
        element: HTMLElement; 
        id: string; 
        rect: DOMRect; 
        position: 'before' | 'after' | 'inside'; 
    };

    function findSnapTarget() {
        // Basic validation
        if (!draggedElementRef || !elementId) {
            return null;
        }

        // Define the return type
        interface SnapResult {
            element: HTMLElement;
            id: string;
            rect: DOMRect;
            position: 'before' | 'after' | 'inside';
        }

        // Get the current dragged element's position
        const dragRect = draggedElementRef.getBoundingClientRect();
        const dragCenterX = dragRect.left + dragRect.width / 2;
        const dragCenterY = dragRect.top + dragRect.height / 2;
        
        // Find the element directly under the mouse cursor with a data-node-id
        const element = document.elementFromPoint(dragCenterX, dragCenterY);
        if (!element) return null;
        
        // Find the closest parent with data-node-id
        let target = element.closest('[data-node-id]') as HTMLElement;
        if (!target || target === draggedElementRef) return null;
        
        // Get the target information
        const targetId = target.getAttribute('data-node-id');
        if (!targetId || targetId === elementId) return null;
        
        const targetRect = target.getBoundingClientRect();
        
        // Check if this is a container
        const isContainer = (
            target.classList.contains('drop-zone') || 
            target.classList.contains('nested-container') ||
            target.tagName === 'DIV' ||
            target.tagName === 'UL' || 
            target.tagName === 'OL'
        );
        
        // Determine position based on the cursor location
        // Default to 'inside' for containers 
        let position: 'before' | 'after' | 'inside';
        
        // For containers, use vertical position to determine position
        if (isContainer) {
            const upperThird = targetRect.top + (targetRect.height * 0.33);
            const lowerThird = targetRect.top + (targetRect.height * 0.66);
            
            if (dragCenterY < upperThird) {
                position = 'before';
            } else if (dragCenterY > lowerThird) {
                position = 'after';
            } else {
                position = 'inside';
            }
        } else {
            // For non-containers, just use middle point
            position = dragCenterY < targetRect.top + (targetRect.height / 2) ? 'before' : 'after';
        }
        
        console.log(`Target: ${targetId} (${target.tagName}) for position ${position}`);
        
        return {
            element: target,
            id: targetId,
            rect: targetRect,
            position: position
        };
    }
    
    // Helper function to check if an element is visible
    function isElementVisible(element: HTMLElement): boolean {
        const style = window.getComputedStyle(element);
        return style.display !== 'none' && 
               style.visibility !== 'hidden' &&
               style.opacity !== '0';
    }

    function animationLoop() {
        if (!isDragging || !elementId) {
            rafId = null; 
            return;
        }

        // Just follow mouse position directly
        const newX = mouseX - initialClickOffsetX;
        const newY = mouseY - initialClickOffsetY;
        
        // Update our state tracking
        targetX = newX;
        targetY = newY;
        updateDraggedPosition(targetX, targetY);

        // Update element position - use fixed positioning for viewport coordinates
        if (draggedElementRef) {
            draggedElementRef.style.position = 'fixed';
            draggedElementRef.style.zIndex = '9999';
            draggedElementRef.style.top = `${newY}px`;
            draggedElementRef.style.left = `${newX}px`;
            draggedElementRef.style.margin = '0';
            draggedElementRef.style.pointerEvents = 'none';
            draggedElementRef.style.opacity = '0.8';
            draggedElementRef.style.boxShadow = '0 5px 10px rgba(0,0,0,0.2)';
            draggedElementRef.classList.add('dragging');

            // Look for snap targets - get explicitly typed result
            const potentialTarget = findSnapTarget() as {
                element: HTMLElement;
                id: string;
                rect: DOMRect;
                position: 'before' | 'after' | 'inside';
            } | null;
            
            if (potentialTarget) {
                isSnapping = true;
                snapTargetId = potentialTarget.id;
                snapPosition = potentialTarget.position;
                
                // Show a visual indicator for the snap target
                draggedElementRef.style.outline = '2px solid #4f46e5';
                
                // Create or update snap indicator
                let indicator = document.getElementById('snap-indicator');
                if (!indicator) {
                    indicator = document.createElement('div');
                    indicator.id = 'snap-indicator';
                    indicator.style.position = 'fixed';
                    indicator.style.zIndex = '9998';
                    indicator.style.pointerEvents = 'none';
                    document.body.appendChild(indicator);
                }
                
                const targetRect = potentialTarget.rect;
                
                // Style the indicator based on snap position
                if (potentialTarget.position === 'before') {
                    indicator.style.height = '2px';
                    indicator.style.background = '#4f46e5';
                    indicator.style.width = `${targetRect.width}px`;
                    indicator.style.left = `${targetRect.left}px`;
                    indicator.style.top = `${targetRect.top - 2}px`;
                    indicator.style.border = 'none';
                } 
                else if (potentialTarget.position === 'after') {
                    indicator.style.height = '2px';
                    indicator.style.background = '#4f46e5';
                    indicator.style.width = `${targetRect.width}px`;
                    indicator.style.left = `${targetRect.left}px`;
                    indicator.style.top = `${targetRect.bottom + 2}px`;
                    indicator.style.border = 'none';
                }
                else if (potentialTarget.position === 'inside') {
                    indicator.style.height = `${targetRect.height}px`;
                    indicator.style.width = `${targetRect.width}px`;
                    indicator.style.left = `${targetRect.left}px`;
                    indicator.style.top = `${targetRect.top}px`;
                    indicator.style.background = 'rgba(79, 70, 229, 0.1)';
                    indicator.style.border = '2px solid #4f46e5';
                    indicator.style.borderRadius = '4px';
                }
                
                // Log the snap for debugging
                console.log(`Snapping to ${potentialTarget.position} of ${potentialTarget.id}`);
            }
            else {
                isSnapping = false;
                snapTargetId = null;
                snapPosition = null;
                draggedElementRef.style.outline = 'none';
                
                // Remove snap indicator if it exists
                const indicator = document.getElementById('snap-indicator');
                if (indicator) {
                    document.body.removeChild(indicator);
                }
            }
        }

        // Keep animation loop going
        rafId = requestAnimationFrame(animationLoop);
    }

    function handleGlobalMouseDown(event: MouseEvent | TouchEvent) {
        if (isDragging) return; // Don't start a new drag if one exists
        console.log(`handleGlobalMouseDown fired. Type: ${event.type}`);

        const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
        const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

        dragStartX = clientX;
        dragStartY = clientY;

        const target = event.target as HTMLElement;
        const isElement = target.closest('.reorderable');
        const isContent = target.closest('.virtual-content');

        console.log(` Mousedown target analysis: isElement=${!!isElement}, isContent=${!!isContent}`);

        // Note: Element dragging is now handled by the Node.svelte component and custom events
        if (isElement) {
            // The element itself will call updateDraggedElement via the custom event
            console.log(" Element dragging is handled by custom events");
        } else if (isContent) {
            console.log(` Mousedown on content detected, starting content drag.`);
            isDragging = true;
            dragType = 'content';
            initialContentOffsetX = offsetX;
            initialContentOffsetY = offsetY;
        } else { // Assume camera drag if not element or content
            console.log(` Mousedown on background detected, starting camera drag.`);
            isDragging = true;
            dragType = 'camera';
            initialCameraX = cameraX;
            initialCameraY = cameraY;
        }
        
        console.log(` Global drag started. Type: ${dragType}, isDragging: ${isDragging}`);
         // Prevent default for camera/content drag to avoid text selection
         if (dragType === 'camera' || dragType === 'content') {
             // Check if event is cancelable before calling preventDefault
             if (event.cancelable) {
                 console.log(` Calling preventDefault for ${dragType} drag.`);
                 event.preventDefault();
             }
         }
    }

    function handleGlobalMouseMove(event: MouseEvent | TouchEvent) {
        // Limit logging frequency if needed
        // console.log("handleGlobalMouseMove"); 
        const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
        const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

        // Update global mouse state regardless of dragging
        mouseX = clientX;
        mouseY = clientY;

        if (!isDragging) return;
        // console.log(` MouseMove with dragType: ${dragType}`);

        const deltaX = clientX - dragStartX;
        const deltaY = clientY - dragStartY;

        if (dragType === 'camera') {
            cameraX = initialCameraX + deltaX;
            cameraY = initialCameraY + deltaY;
            // Update CSS variables directly
            document.documentElement.style.setProperty('--camera-x', `${cameraX}px`);
            document.documentElement.style.setProperty('--camera-y', `${cameraY}px`);
        } else if (dragType === 'content') {
            offsetX = initialContentOffsetX + deltaX / virtualScale;
            offsetY = initialContentOffsetY + deltaY / virtualScale;
             // Update CSS variables directly
            document.documentElement.style.setProperty('--offset-x', `${offsetX}px`);
            document.documentElement.style.setProperty('--offset-y', `${offsetY}px`);
        } else if (dragType === 'element') {
            // Element movement is handled by the animationLoop
            // We just need the updated mouseX/mouseY which are already set
        }
        
        // Prevent default for camera/content drag
        if (dragType === 'camera' || dragType === 'content') {
            if (event.cancelable) {
                event.preventDefault();
            }
        }
    }

    function handleGlobalMouseUp(event: MouseEvent | TouchEvent) {
        if (!isDragging) return;

        // Get element references before resetting state
        const elementBeingReleasedId = elementId;
        const elementRefBeingReleased = draggedElementRef;

        if (dragType === 'element' && elementRefBeingReleased && elementBeingReleasedId) {
            // Stop animation loop
            if (rafId) {
                cancelAnimationFrame(rafId);
                rafId = null;
            }

            // Remove snap indicator if it exists
            const indicator = document.getElementById('snap-indicator');
            if (indicator) {
                document.body.removeChild(indicator);
            }

            // Check if we should finalize a snap
            if (isSnapping && snapTargetId && snapPosition) {
                console.log(`Snapping element ${elementBeingReleasedId} ${snapPosition} ${snapTargetId}`);
                
                // Reset styles first
                const styles = elementRefBeingReleased.style;
                styles.position = '';
                styles.top = '';
                styles.left = '';
                styles.zIndex = '';
                styles.transform = '';
                styles.transition = '';
                styles.pointerEvents = '';
                styles.opacity = '';
                styles.boxShadow = '';
                styles.outline = '';
                styles.margin = '';
                elementRefBeingReleased.classList.remove('dragging');
                
                // Move the element in the DOM
                try {
                    moveNode(elementBeingReleasedId, snapTargetId, snapPosition);
                } catch (error) {
                    console.error("Error moving node:", error);
                }
            }
            else {
                // Return to original position with animation
                console.log("Returning element to original position");
                elementRefBeingReleased.style.transition = 'all 0.3s ease';
                elementRefBeingReleased.style.position = '';
                elementRefBeingReleased.style.top = '';
                elementRefBeingReleased.style.left = '';
                elementRefBeingReleased.style.zIndex = '';
                elementRefBeingReleased.style.transform = '';
                elementRefBeingReleased.style.pointerEvents = '';
                elementRefBeingReleased.style.opacity = '';
                elementRefBeingReleased.style.boxShadow = '';
                elementRefBeingReleased.style.outline = '';
                elementRefBeingReleased.style.margin = '';
                elementRefBeingReleased.classList.remove('dragging');
                
                // Clear transition after animation completes
                setTimeout(() => {
                    if (elementRefBeingReleased) {
                        elementRefBeingReleased.style.transition = '';
                    }
                }, 300);
            }
        }

        // Reset all state variables
        isDragging = false;
        dragType = 'none';
        resetDragState();
        draggedElementRef = null;
        isSnapping = false;
        snapTargetId = null;
        snapTargetRect = null;
        snapIndicatorPosition = null;
        snapPosition = null;
        hasMovedInitially = false;
        velocityX = 0;
        velocityY = 0;
        currentRotation = 0;
        initialElementX = 0;
        initialElementY = 0;
        initialClickOffsetX = 0;
        initialClickOffsetY = 0;
    }

    // --- End New Handlers ---

    // --- KEEP VDOM Structure and Helpers ---
    // ...

    // Helper function for snap indicator styling
    function getSnapIndicatorStyle(rect: DOMRect, position: 'before' | 'after' | 'inside'): string {
        let style = '';
        
        if (position === 'before') {
            style = `
                left: ${rect.left}px;
                top: ${rect.top - 1.5}px;
                width: ${rect.width}px;
                height: 3px;
            `;
        } else if (position === 'after') {
            style = `
                left: ${rect.left}px;
                top: ${rect.bottom - 1.5}px;
                width: ${rect.width}px;
                height: 3px;
            `;
        } else if (position === 'inside') {
            style = `
                left: ${rect.left}px;
                top: ${rect.top}px;
                width: ${rect.width}px;
                height: ${rect.height}px;
            `;
        }
        
        return style;
    }
</script>

<div
    class="grid h-screen w-full grid-cols-[2.25rem_1fr_auto] grid-rows-[2.25rem_1fr] bg-black"
>
    <header class="col-span-3 bg-black z-10 flex items-center justify-center">
        <Dropdown
            options={virtualDevices.map((device) => device.name)}
            bind:value={currentVirtualDeviceIndex}
            label="Virtual Device"
            placeholder="Select a device"
            on:change={(e) => {
                // Smooth transition to new device
                const newIndex = e.detail;
                currentVirtualDeviceIndex = newIndex;
                
                // Pre-set tweened values for smoother start
                const newDevice = virtualDevices[newIndex];
                tweenedWidth.set(newDevice.width, { duration: 100 });
                tweenedHeight.set(newDevice.height, { duration: 100 });
            }}
        />
    </header>
    <nav class="col-start-1 row-start-2 flex flex-col items-center"></nav>
    <div
        class="col-start-2 row-start-2 bg-gray-500 overflow-hidden flex items-center justify-center"
        id="viewport"
        on:wheel={handleWheel}
        on:mousedown={handleGlobalMouseDown}
        on:mousemove={handleGlobalMouseMove}
        on:mouseup={handleGlobalMouseUp}
        on:mouseleave={handleGlobalMouseUp} 
        on:touchstart={handleGlobalMouseDown}
        on:touchmove|passive={handleGlobalMouseMove}
        on:touchend={handleGlobalMouseUp}
    >
        <div
            class="virtual-container"
            style="--virtual-scale: {virtualScale}; --camera-x: {cameraX}px; --camera-y: {cameraY}px; --offset-x: {offsetX}px; --offset-y: {offsetY}px;"
        >
            <main
                class="virtual-content"
                style="--virtual-width: {$tweenedWidth}px; --virtual-height: {$tweenedHeight}px;"
            >
                <!-- Add snap indicator if snapping -->
                {#if isSnapping && snapTargetRect && snapPosition}
                    <div class="snap-indicator" style={getSnapIndicatorStyle(snapTargetRect, snapPosition)}>
                        <div class="snap-indicator-line"></div>
                        {#if snapPosition === 'inside'}
                            <div class="snap-indicator-background"></div>
                        {/if}
                    </div>
                {/if}
                
                {@render children()}
                    
                <div class="text-sm text-gray-500 mt-8 opacity-50">
                    • <strong>Drag the gray background</strong> to move the camera view<br>
                    • <strong>Drag this white area</strong> to pan the page content<br>
                    • <strong>Click individual elements</strong> to select them
                </div>
            </main>
        </div>
    </div>

    <aside
        class="col-start-3 row-start-2 bg-black text-white overflow-hidden transition-all duration-300 ease-out"
        style="width: {$sidebarWidth}px;"
    >
        <div class="flex items-center h-[2.25rem] justify-start pl-1">
            <button
                class="w-[2.25rem] h-[2.25rem] rounded-md flex items-center justify-center text-white cursor-pointer transition-all duration-200 ease-out"
                style="transform: {showRightSidebar ? '' : 'rotate(180deg)'}"
                on:click={toggleSidebar}
            >
                {#if showRightSidebar}
                    <!-- Closed Eye (when sidebar is open) -->
                    <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="20"
                        height="20"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                    >
                        <path
                            d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"
                        ></path>
                        <line x1="1" y1="1" x2="23" y2="23"></line>
                    </svg>
                {:else}
                    <!-- Open Eye (when sidebar is closed) -->
                    <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="20"
                        height="20"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                    >
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"
                        ></path>
                        <circle cx="12" cy="12" r="3"></circle>
                    </svg>
                {/if}
            </button>
        </div>

        <div
            class="overflow-hidden transition-all duration-300 ease-out"
            style="opacity: {$sidebarContentOpacity}; max-height: {$sidebarContentOpacity *
                100}vh; transform: translateX({(1 - $sidebarContentOpacity) *
                10}px);"
        >
            <!-- Tab Navigation -->
            <div
                class="border-b border-[#27272a] overflow-x-auto scrollbar-none"
            >
                <div class="min-w-[260px] flex">
                    <button
                        class="px-3 py-2 text-xs {activeSidebarTab === 'Style'
                            ? 'border-b border-white'
                            : 'text-gray-400'}"
                        on:click={() => setActiveTab("Style")}
                    >
                        Style
                    </button>
                    <button
                        class="px-3 py-2 text-xs {activeSidebarTab ===
                        'Settings'
                            ? 'border-b border-white'
                            : 'text-gray-400'}"
                        on:click={() => setActiveTab("Settings")}
                    >
                        Settings
                    </button>
                    <button
                        class="px-3 py-2 text-xs {activeSidebarTab ===
                        'Interactions'
                            ? 'border-b border-white'
                            : 'text-gray-400'}"
                        on:click={() => setActiveTab("Interactions")}
                    >
                        Interactions
                    </button>
                </div>
            </div>

            <div
                class="overflow-y-auto scrollbar-thin scrollbar-thumb-[#3f3f46] scrollbar-track-transparent h-[calc(100vh-5rem)]"
            >
                {#if activeSidebarTab === "Style"}
                    <!-- Style Tab Content -->
                    <div
                        class="p-3"
                        in:fly={{
                            y: 10,
                            duration: 200,
                            delay: 50,
                            easing: cubicOut,
                        }}
                        out:fade={{ duration: 150 }}
                    >
                        <!-- Style selector section -->
                        <div class="mb-4 overflow-x-auto scrollbar-none">
                            <div class="min-w-[230px]">
                                <div
                                    class="flex justify-between items-center mb-2"
                                >
                                    <div
                                        class="text-xs text-gray-400 whitespace-nowrap"
                                    >
                                        Style selector
                                    </div>
                                    <div
                                        class="text-xs whitespace-nowrap text-gray-400"
                                    >
                                        Inheriting 1
                                    </div>
                                </div>

                                <!-- Selector Buttons -->
                                <div class="flex space-x-1.5 mb-3">
                                    <button
                                        class="border border-gray-600 p-1.5 rounded bg-[#27272a]"
                                    >
                                        <svg
                                            xmlns="http://www.w3.org/2000/svg"
                                            width="14"
                                            height="14"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                            stroke-linecap="round"
                                            stroke-linejoin="round"
                                        >
                                            <rect
                                                x="3"
                                                y="3"
                                                width="18"
                                                height="18"
                                                rx="2"
                                            ></rect>
                                        </svg>
                                    </button>
                                    <button
                                        class="border border-[#3B82F6] p-1.5 rounded bg-[#3B82F6] text-white text-xs"
                                    >
                                        Section
                                    </button>
                                </div>

                                <div class="text-xs text-gray-400">
                                    1 on this page
                                </div>
                            </div>
                        </div>

                        <div class="text-xs mb-3 text-gray-400">
                            Variable modes
                        </div>

                        <!-- Layout Section -->
                        <div
                            class="mt-4 border-t border-[#27272a] pt-3 overflow-x-auto scrollbar-none"
                        >
                            <div class="min-w-[230px]">
                                <h3 class="text-sm font-medium mb-3">Layout</h3>

                                <!-- Display Options -->
                                <div class="flex items-center mb-3">
                                    <div class="w-20 text-xs whitespace-nowrap">
                                        Display
                                    </div>
                                    <div class="flex space-x-1.5">
                                        <button
                                            class="px-2 py-1 bg-[#27272a] border border-gray-600 rounded text-xs {display ===
                                            'Block'
                                                ? 'bg-[#3f3f46]'
                                                : ''}"
                                        >
                                            Block
                                        </button>
                                        <button
                                            class="px-2 py-1 bg-[#27272a] border border-gray-600 rounded text-xs {display ===
                                            'Flex'
                                                ? 'bg-[#3f3f46]'
                                                : ''}"
                                        >
                                            Flex
                                        </button>
                                        <button
                                            class="px-2 py-1 bg-[#27272a] border border-gray-600 rounded text-xs {display ===
                                            'Grid'
                                                ? 'bg-[#3f3f46]'
                                                : ''}"
                                        >
                                            Grid
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Spacing Section -->
                        <div
                            class="mt-4 border-t border-[#27272a] pt-3 overflow-x-auto scrollbar-none"
                        >
                            <div class="min-w-[230px]">
                                <div
                                    class="flex justify-between items-center mb-3"
                                >
                                    <h3
                                        class="text-sm font-medium whitespace-nowrap"
                                    >
                                        Spacing
                                    </h3>
                                    <button
                                        class="p-1 border border-gray-600 rounded flex-shrink-0 bg-[#27272a]"
                                    >
                                        <svg
                                            xmlns="http://www.w3.org/2000/svg"
                                            width="14"
                                            height="14"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                            stroke-linecap="round"
                                            stroke-linejoin="round"
                                        >
                                            <rect
                                                x="3"
                                                y="3"
                                                width="18"
                                                height="18"
                                                rx="2"
                                                ry="2"
                                            ></rect>
                                            <line x1="3" y1="9" x2="21" y2="9"
                                            ></line>
                                            <line x1="3" y1="15" x2="21" y2="15"
                                            ></line>
                                            <line x1="9" y1="3" x2="9" y2="21"
                                            ></line>
                                            <line x1="15" y1="3" x2="15" y2="21"
                                            ></line>
                                        </svg>
                                    </button>
                                </div>

                                <!-- Spacing Visualizer - Fixed Size Box -->
                                <div class="mt-5 mb-4 mx-auto w-52 h-52 relative overflow-visible">
                                    <!-- Outermost Canvas - Background for Margin -->
                                    <div class="absolute inset-0 bg-[#1f1f23] overflow-visible rounded grid grid-cols-[auto_1fr_auto] grid-rows-[auto_1fr_auto]">
                                        <!-- Top-Left Corner (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.left}px; height: {marginVisual.top}px;"></div>
                                        </div>
                                        
                                        <!-- Top Edge (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="height: {marginVisual.top}px;">
                                                <button
                                                    class="absolute inset-x-0 top-0 h-full flex items-center justify-center overflow-visible"
                                                    style="height: {marginVisual.top}px;"
                                                    on:click={() => setMarginSide("top")}
                                                >
                                                    {#if margin.top > 0}
                                                        <span class="bg-[#1f1f23] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-20 
                                                                    {activeMarginSide === 'top' ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                  style="top: -25px; left: 50%; transform: translateX(-50%);">
                                                            {margin.top === 1 ? 'one pixel' : margin.top === 2 ? 'two pixels' : `${margin.top} pixels`}
                                                        </span>
                                                    {/if}
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <!-- Top-Right Corner (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.right}px; height: {marginVisual.top}px;"></div>
                                        </div>
                                        
                                        <!-- Left Edge (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.left}px;">
                                                <button
                                                    class="absolute inset-y-0 left-0 w-full flex items-center justify-center overflow-visible"
                                                    style="width: {marginVisual.left}px;"
                                                    on:click={() => setMarginSide("left")}
                                                >
                                                    {#if margin.left > 0}
                                                        <span class="bg-[#1f1f23] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-20
                                                                    {activeMarginSide === 'left' ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                  style="left: -30px; top: 50%; transform: translateY(-50%);">
                                                            {margin.left === 1 ? 'one pixel' : margin.left === 2 ? 'two pixels' : `${margin.left} pixels`}
                                                        </span>
                                                    {/if}
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <!-- Center (Padding + Content Area) -->
                                        <div class="bg-[#18181b] grid grid-cols-[auto_1fr_auto] grid-rows-[auto_1fr_auto] rounded overflow-visible relative">
                                            <!-- Top-Left Corner (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.left}px; height: {paddingVisual.top}px;"></div>
                                            </div>
                                            
                                            <!-- Top Edge (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="height: {paddingVisual.top}px;">
                                                    <button
                                                        class="absolute inset-x-0 top-0 h-full flex items-center justify-center overflow-visible"
                                                        style="height: {paddingVisual.top}px; left: {marginVisual.left + paddingVisual.left}px; right: {marginVisual.right + paddingVisual.right}px; top: {marginVisual.top}px;"
                                                        on:click={() => setPaddingSide("top")}
                                                    >
                                                        {#if padding.top > 0}
                                                            <span class="bg-[#18181b] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-10
                                                                        {activePaddingSides.includes('top') ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                      style="top: -5px; left: 50%; transform: translateX(-50%);">
                                                                {padding.top === 1 ? 'one pixel' : padding.top === 2 ? 'two pixels' : `${padding.top} pixels`}
                                                            </span>
                                                        {/if}
                                                    </button>
                                                </div>
                                            </div>
                                            
                                            <!-- Top-Right Corner (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.right}px; height: {paddingVisual.top}px;"></div>
                                            </div>
                                            
                                            <!-- Left Edge (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.left}px;">
                                                    <button
                                                        class="absolute inset-y-0 left-0 w-full flex items-center justify-center overflow-visible"
                                                        style="width: {paddingVisual.left}px; top: {marginVisual.top + paddingVisual.top}px; bottom: {marginVisual.bottom + paddingVisual.bottom}px; left: {marginVisual.left}px;"
                                                        on:click={() => setPaddingSide("left")}
                                                    >
                                                        {#if padding.left > 0}
                                                            <span class="bg-[#18181b] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-10
                                                                        {activePaddingSides.includes('left') ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                      style="left: -15px; top: 50%; transform: translateY(-50%);">
                                                                {padding.left === 1 ? 'one pixel' : padding.left === 2 ? 'two pixels' : `${padding.left} pixels`}
                                                            </span>
                                                        {/if}
                                                    </button>
                                                </div>
                                            </div>
                                            
                                            <!-- Content Area -->
                                            <div class="bg-[#121214] flex items-center justify-center rounded">
                                                <div class="text-xs text-gray-400">
                                                    Content
                                                </div>
                                            </div>
                                            
                                            <!-- Right Edge (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.right}px;">
                                                    <button
                                                        class="absolute inset-y-0 right-0 w-full flex items-center justify-center overflow-visible"
                                                        style="width: {paddingVisual.right}px; top: {marginVisual.top + paddingVisual.top}px; bottom: {marginVisual.bottom + paddingVisual.bottom}px; right: {marginVisual.right}px;"
                                                        on:click={() => setPaddingSide("right")}
                                                    >
                                                        {#if padding.right > 0}
                                                            <span class="bg-[#18181b] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-10
                                                                        {activePaddingSides.includes('right') ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                      style="right: -15px; top: 50%; transform: translateY(-50%);">
                                                                {padding.right === 1 ? 'one pixel' : padding.right === 2 ? 'two pixels' : `${padding.right} pixels`}
                                                            </span>
                                                        {/if}
                                                    </button>
                                                </div>
                                            </div>
                                            
                                            <!-- Bottom-Left Corner (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.left}px; height: {paddingVisual.bottom}px;"></div>
                                            </div>
                                            
                                            <!-- Bottom Edge (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="height: {paddingVisual.bottom}px;">
                                                    <button
                                                        class="absolute inset-x-0 bottom-0 h-full flex items-center justify-center overflow-visible"
                                                        style="height: {paddingVisual.bottom}px; left: {marginVisual.left + paddingVisual.left}px; right: {marginVisual.right + paddingVisual.right}px; bottom: {marginVisual.bottom}px;"
                                                        on:click={() => setPaddingSide("bottom")}
                                                    >
                                                        {#if padding.bottom > 0}
                                                            <span class="bg-[#18181b] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-10
                                                                        {activePaddingSides.includes('bottom') ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                      style="bottom: -5px; left: 50%; transform: translateX(-50%);">
                                                                {padding.bottom === 1 ? 'one pixel' : padding.bottom === 2 ? 'two pixels' : `${padding.bottom} pixels`}
                                                            </span>
                                                        {/if}
                                                    </button>
                                                </div>
                                            </div>
                                            
                                            <!-- Bottom-Right Corner (Padding) -->
                                            <div class="bg-blue-800/30 relative">
                                                <div style="width: {paddingVisual.right}px; height: {paddingVisual.bottom}px;"></div>
                                            </div>
                                        </div>
                                        
                                        <!-- Right Edge (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.right}px;">
                                                <button
                                                    class="absolute inset-y-0 right-0 w-full flex items-center justify-center overflow-visible"
                                                    style="width: {marginVisual.right}px;"
                                                    on:click={() => setMarginSide("right")}
                                                >
                                                    {#if margin.right > 0}
                                                        <span class="bg-[#1f1f23] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-20
                                                                    {activeMarginSide === 'right' ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                  style="right: -30px; top: 50%; transform: translateY(-50%);">
                                                            {margin.right === 1 ? 'one pixel' : margin.right === 2 ? 'two pixels' : `${margin.right} pixels`}
                                                        </span>
                                                    {/if}
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <!-- Bottom-Left Corner (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.left}px; height: {marginVisual.bottom}px;"></div>
                                        </div>
                                        
                                        <!-- Bottom Edge (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="height: {marginVisual.bottom}px;">
                                                <button
                                                    class="absolute inset-x-0 bottom-0 h-full flex items-center justify-center overflow-visible"
                                                    style="height: {marginVisual.bottom}px;"
                                                    on:click={() => setMarginSide("bottom")}
                                                >
                                                    {#if margin.bottom > 0}
                                                        <span class="bg-[#1f1f23] px-2 py-0.5 text-xs rounded-sm absolute whitespace-nowrap z-20
                                                                    {activeMarginSide === 'bottom' ? 'text-blue-400 border border-blue-400' : 'text-gray-300'}" 
                                                                  style="bottom: -25px; left: 50%; transform: translateX(-50%);">
                                                            {margin.bottom === 1 ? 'one pixel' : margin.bottom === 2 ? 'two pixels' : `${margin.bottom} pixels`}
                                                        </span>
                                                    {/if}
                                                </button>
                                            </div>
                                        </div>
                                        
                                        <!-- Bottom-Right Corner (Margin) -->
                                        <div class="bg-blue-900/30 relative">
                                            <div style="width: {marginVisual.right}px; height: {marginVisual.bottom}px;"></div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Controls Section -->
                                <div class="mt-5 mb-2">
                                    <div
                                        class="flex justify-between text-xs text-gray-400 mb-1.5"
                                    >
                                        <span>
                                            {activeMarginSide
                                                ? `Margin ${activeMarginSide}`
                                                : "All margins"}:
                                            <span class="text-white"
                                                >{activeMarginSide
                                                    ? margin[
                                                          activeMarginSide
                                                      ]
                                                    : margin.top}px</span
                                            >
                                        </span>
                                        <button
                                            class="text-xs bg-[#3f3f46] px-2 py-0.5 rounded"
                                            on:click={() => updateMargin(0)}
                                        >
                                            Reset
                                        </button>
                                    </div>
                                    <input
                                        type="range"
                                        min="0"
                                        max="50"
                                        value={activeMarginSide
                                            ? margin[activeMarginSide]
                                            : margin.top}
                                        class="w-full h-1.5 bg-[#3f3f46] rounded-sm appearance-none"
                                        on:input={(e) => {
                                            if (e.target && e.target instanceof HTMLInputElement)
                                                updateMargin(
                                                    Number(e.target.value),
                                                );
                                        }}
                                    />
                                </div>

                                <div class="mt-3">
                                    <div
                                        class="flex justify-between text-xs text-gray-400 mb-1.5"
                                    >
                                        <span>
                                            {activePaddingSides.length > 0
                                                ? `Padding ${activePaddingSides.join(', ')}`
                                                : "All paddings"}:
                                            <span class="text-white"
                                                >{activePaddingSides.length === 1
                                                    ? padding[
                                                          activePaddingSides[0]
                                                      ]
                                                    : padding.top}px</span
                                            >
                                        </span>
                                        <button
                                            class="text-xs bg-[#3f3f46] px-2 py-0.5 rounded"
                                            on:click={() =>
                                                updatePadding(0)}
                                        >
                                            Reset
                                        </button>
                                    </div>
                                    <input
                                        type="range"
                                        min="0"
                                        max="30"
                                        value={activePaddingSides.length === 1
                                            ? padding[activePaddingSides[0]]
                                            : padding.top}
                                        class="w-full h-1.5 bg-[#3f3f46] rounded-sm appearance-none"
                                        on:input={(e) => {
                                            if (e.target && e.target instanceof HTMLInputElement)
                                                updatePadding(
                                                    Number(e.target.value),
                                                );
                                        }}
                                    />
                                </div>
                            </div>
                        </div>

                        <!-- Size Section -->
                        <div
                            class="mt-4 border-t border-[#27272a] pt-3 overflow-x-auto scrollbar-none"
                        >
                            <div class="min-w-[230px]">
                                <h3 class="text-sm font-medium mb-3">Size</h3>

                                <!-- Width/Height Controls -->
                                <div class="grid grid-cols-2 gap-3 mb-3">
                                    <div>
                                        <div class="text-xs mb-1.5">Width</div>
                                        <div class="flex">
                                            <input
                                                type="text"
                                                value="Auto"
                                                class="bg-[#27272a] border border-gray-600 rounded p-1.5 w-full text-xs"
                                            />
                                            <span class="ml-1.5 p-1.5 text-xs"
                                                >-</span
                                            >
                                        </div>
                                    </div>
                                    <div>
                                        <div class="text-xs mb-1.5">Height</div>
                                        <div class="flex">
                                            <input
                                                type="text"
                                                value="Auto"
                                                class="bg-[#27272a] border border-gray-600 rounded p-1.5 w-full text-xs"
                                            />
                                            <span class="ml-1.5 p-1.5 text-xs"
                                                >-</span
                                            >
                                        </div>
                                    </div>
                                </div>

                                <!-- Min/Max Controls -->
                                <div class="grid grid-cols-2 gap-3 mb-3">
                                    <div>
                                        <div class="text-xs mb-1.5">Min W</div>
                                        <div class="flex">
                                            <input
                                                type="text"
                                                value="0"
                                                class="bg-[#27272a] border border-gray-600 rounded p-1.5 w-full text-xs"
                                            />
                                            <span class="ml-1.5 p-1.5 text-xs"
                                                >px</span
                                            >
                                        </div>
                                    </div>
                                    <div>
                                        <div class="text-xs mb-1.5">Min H</div>
                                        <div class="flex">
                                            <input
                                                type="text"
                                                value="0"
                                                class="bg-[#27272a] border border-gray-600 rounded p-1.5 w-full text-xs"
                                            />
                                            <span class="ml-1.5 p-1.5 text-xs"
                                                >px</span
                                            >
                                        </div>
                                    </div>
                                </div>

                                <!-- Overflow Controls -->
                                <div class="mb-3">
                                    <div class="text-xs mb-1.5">Overflow</div>
                                    <div class="flex space-x-1.5">
                                        <button
                                            class="p-1.5 bg-[#27272a] border border-gray-600 rounded"
                                        >
                                            <svg
                                                xmlns="http://www.w3.org/2000/svg"
                                                width="14"
                                                height="14"
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                stroke-width="2"
                                                stroke-linecap="round"
                                                stroke-linejoin="round"
                                            >
                                                <circle cx="12" cy="12" r="10"
                                                ></circle>
                                                <line
                                                    x1="8"
                                                    y1="12"
                                                    x2="16"
                                                    y2="12"
                                                ></line>
                                                <line
                                                    x1="12"
                                                    y1="8"
                                                    x2="12"
                                                    y2="16"
                                                ></line>
                                            </svg>
                                        </button>
                                        <button
                                            class="p-1.5 bg-[#27272a] border border-gray-600 rounded"
                                        >
                                            <svg
                                                xmlns="http://www.w3.org/2000/svg"
                                                width="14"
                                                height="14"
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                stroke-width="2"
                                                stroke-linecap="round"
                                                stroke-linejoin="round"
                                            >
                                                <circle cx="12" cy="12" r="10"
                                                ></circle>
                                                <line
                                                    x1="8"
                                                    y1="12"
                                                    x2="16"
                                                    y2="12"
                                                ></line>
                                            </svg>
                                        </button>
                                        <button
                                            class="p-1.5 bg-[#27272a] border border-gray-600 rounded"
                                        >
                                            <svg
                                                xmlns="http://www.w3.org/2000/svg"
                                                width="14"
                                                height="14"
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                stroke-width="2"
                                                stroke-linecap="round"
                                                stroke-linejoin="round"
                                            >
                                                <rect
                                                    x="2"
                                                    y="2"
                                                    width="20"
                                                    height="20"
                                                    rx="5"
                                                ></rect>
                                            </svg>
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Position Section -->
                        <div
                            class="mt-4 border-t border-[#27272a] pt-3 mb-5 overflow-x-auto scrollbar-none"
                        >
                            <div class="min-w-[230px]">
                                <h3 class="text-sm font-medium mb-3">
                                    Position
                                </h3>

                                <div class="flex items-center">
                                    <div class="text-xs mr-3 whitespace-nowrap">
                                        Position
                                    </div>
                                    <button
                                        class="flex items-center bg-[#27272a] border border-gray-600 rounded p-1.5 whitespace-nowrap"
                                    >
                                        <svg
                                            xmlns="http://www.w3.org/2000/svg"
                                            width="14"
                                            height="14"
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            stroke-width="2"
                                            stroke-linecap="round"
                                            stroke-linejoin="round"
                                        >
                                            <line x1="18" y1="6" x2="6" y2="18"
                                            ></line>
                                            <line x1="6" y1="6" x2="18" y2="18"
                                            ></line>
                                        </svg>
                                        <span class="ml-1.5 text-xs"
                                            >Static</span
                                        >
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                {/if}

                {#if activeSidebarTab === "Settings"}
                    <div
                        class="p-3"
                        in:fly={{
                            y: 10,
                            duration: 200,
                            delay: 50,
                            easing: cubicOut,
                        }}
                        out:fade={{ duration: 150 }}
                    >
                        <h3 class="text-sm font-medium mb-3">Settings</h3>
                        <p class="text-xs text-gray-400">
                            Element settings would go here
                        </p>
                    </div>
                {/if}

                {#if activeSidebarTab === "Interactions"}
                    <div
                        class="p-3"
                        in:fly={{
                            y: 10,
                            duration: 200,
                            delay: 50,
                            easing: cubicOut,
                        }}
                        out:fade={{ duration: 150 }}
                    >
                        <h3 class="text-sm font-medium mb-3">Interactions</h3>
                        <p class="text-xs text-gray-400">
                            Interactions would go here
                        </p>
                    </div>
                {/if}
            </div>
        </div>
    </aside>
</div>

<style>
    /* Simple styles */
    .virtual-container {
        position: relative;
        display: block;
        transform: translate(var(--camera-x, 0px), var(--camera-y, 0px)) scale(var(--virtual-scale));
        cursor: move;
        touch-action: none;
        will-change: transform;
    }

    .virtual-content {
        position: relative;
        background: white;
        width: var(--virtual-width);
        height: var(--virtual-height);
        cursor: grab;
        box-shadow: 0 0 20px rgba(0, 0, 0, 0.2);
        border-radius: 8px;
        overflow: hidden;
        touch-action: none;
        user-select: none;
        transform: translate(calc(var(--offset-x, 0px)), calc(var(--offset-y, 0px)));
    }
    
    .virtual-content:active {
        cursor: grabbing;
    }

    /* Custom scrollbar styling */
    .scrollbar-none::-webkit-scrollbar {
        display: none;
    }

    .scrollbar-none {
        scrollbar-width: none;
    }

    /* Drag and drop styles */
    
    /* Background pattern */
    #viewport {
        background: #555;
        touch-action: none;
        user-select: none;
    }
    
    /* Global styles to prevent text selection and make dragging smoother */
    :global(body) {
        touch-action: none;
        user-select: none;
        overflow: hidden;
    }

    

    /* Style for snap indicator (placeholder) */
    .snap-indicator {
        position: absolute;
        pointer-events: none;
        z-index: 1000;
    }
    
    .snap-indicator-line {
        position: absolute;
        height: 3px;
        background-color: #3B82F6;
        width: 100%;
        left: 0;
        top: 0;
        border-radius: 1.5px;
    }
    
    .snap-indicator-background {
        position: absolute;
        border: 2px solid #3B82F6;
        border-radius: 4px;
        background-color: rgba(59, 130, 246, 0.1);
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
    }
</style>
