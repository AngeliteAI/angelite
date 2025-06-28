<script>
	import '../app.css';
    var virtualScale = $state(0.5);
    var offsetX = $state(0);
    var offsetY = $state(0);
	let { children } = $props();
    let currentVirtualDeviceIndex = $state(0);
    let currentVirtualDevice = $derived(virtualDevices[currentVirtualDeviceIndex]);
    let virtualDevices = [
        {
            name: 'iPhone 16',
            width: 1179,
            height: 2556,
            scale: 0.5,
            offsetX: 0,
            offsetY: 0
        },
        {
            name: 'Desktop',
            width: 1920,
            height: 1080,
            scale: 0.5,
            offsetX: 0,
            offsetY: 0
        }
    ]
    

    let isDragging = false;
    let startX = 0;
    let startY = 0;
    let startOffsetX = 0;
    let startOffsetY = 0;

    function handleStart(e) {
        e.preventDefault();
        isDragging = true;
        const point = e.touches ? e.touches[0] : e;
        startX = point.clientX;
        startY = point.clientY;
        startOffsetX = offsetX;
        startOffsetY = offsetY;
    }

    function handleMove(e) {
        if (!isDragging) return;
        e.preventDefault();
        const point = e.touches ? e.touches[0] : e;
        const deltaX = (point.clientX - startX) / virtualScale;
        const deltaY = (point.clientY - startY) / virtualScale;
        offsetX = startOffsetX + deltaX;
        offsetY = startOffsetY + deltaY;
    }

    function handleEnd(e) {
        e.preventDefault();
        isDragging = false;
    }

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
        if (!draggedElementRef) {
            return null;
        }

        // Use actual mouse position for target detection instead of element center
        const dragCenterX = mouseX;
        const dragCenterY = mouseY;
        
        // Find the element directly under the mouse cursor with a data-node-id
        const element = document.elementFromPoint(dragCenterX, dragCenterY);
        if (!element) return null;
        
        // Find the closest parent with data-node-id
        let target = element.closest('[data-node-id]') as HTMLElement;
        if (!target || target === draggedElementRef) return null;
        
        // Get the target information
        const targetId = target.getAttribute('data-node-id');
        const draggedId = draggedElementRef.getAttribute('data-node-id');
        if (!targetId || targetId === draggedId) return null;
        
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
        // Get precise coordinates
        const clientX = 'touches' in event ? event.touches[0].clientX : event.clientX;
        const clientY = 'touches' in event ? event.touches[0].clientY : event.clientY;

        // Update global mouse state immediately
        mouseX = clientX;
        mouseY = clientY;

        if (!isDragging) return;

        const deltaX = clientX - dragStartX;
        const deltaY = clientY - dragStartY;

        if (dragType === 'camera') {
            cameraX = initialCameraX + deltaX;
            cameraY = initialCameraY + deltaY;
            // Update CSS variables directly for better performance
            document.documentElement.style.setProperty('--camera-x', `${cameraX}px`);
            document.documentElement.style.setProperty('--camera-y', `${cameraY}px`);
        } else if (dragType === 'content') {
            offsetX = initialContentOffsetX + deltaX / virtualScale;
            offsetY = initialContentOffsetY + deltaY / virtualScale;
            // Update CSS variables directly for better performance  
            document.documentElement.style.setProperty('--offset-x', `${offsetX}px`);
            document.documentElement.style.setProperty('--offset-y', `${offsetY}px`);
        }
        // Element movement is handled by the animation loop
        
        // Prevent default for camera/content drag to avoid text selection
        if ((dragType === 'camera' || dragType === 'content') && event.cancelable) {
            event.preventDefault();
        }
    }
</script>

<div class="grid h-screen w-full grid-cols-[2rem_1fr_16rem] grid-rows-[2rem_1fr] bg-black">
    <header class="col-span-30"></header>
    <nav class="">

    <button on:click={() => virtualScale *= 2} class="bg-white">+</button>
    <button on:click={() => virtualScale /= 2} class="bg-white">-</button>
    </nav>
    <div class="bg-gray-500 overflow-hidden"
            on:touchstart={handleStart}
            on:touchmove={handleMove}
            on:touchend={handleEnd}
            on:mousedown={handleStart}
            on:mousemove={handleMove}
            on:mouseup={handleEnd}
            on:mouseleave={handleEnd}
    >
        <span 
            class="origin-top-left inline-block" 
            style="--virtual-width: 1920px; --virtual-height: 1080px;--virtual-scale: {virtualScale};--offset-x: {offsetX}px;--offset-y: {offsetY}px"
            
        >
            <main class="bg-white origin-center" style="--virtual-width: {currentVirtualDevice.width}px; --virtual-height: {currentVirtualDevice.height}px;">
                {@render children()}
            </main>
        </span>
    </div>
    <aside class="0"></aside>
</div>

<style>
    span {
        position: relative;
        display: block;
        width: calc(var(--virtual-width));
        height: calc(var(--virtual-height));
        transform: scale(var(--virtual-scale)) translate(var(--offset-x), var(--offset-y));
        touch-action: none; /* Prevents default touch behaviors */
        user-select: none;
        -webkit-user-select: none;
    }
    main {
        position: relative;
        top: 0;
        right: 0;
        min-width: var(--virtual-width);
        min-height: var(--virtual-height);
        margin: 0 auto;
    }
</style>