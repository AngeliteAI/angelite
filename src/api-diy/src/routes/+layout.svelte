<script lang="ts">
    import "../app.css";

    import { onMount } from "svelte";
    import Document from "$lib/components/Document.svelte";
    import { cubicOut, quartOut } from "svelte/easing";
    import { tweened } from "svelte/motion";
    import { fade, fly } from "svelte/transition";
    import Viewport from "$lib/components/Viewport.svelte";
    import Tailwind from "$lib/Tailwind.svelte";
    import { virtualScale, activeDocuments, selectedNodeId } from "$lib/store";
    import VDom from "$lib/VDom.svelte";
    import Sidebar from "$lib/components/Sidebar.svelte";
    import Inspector from "$lib/components/inspector/Inspector.svelte";

    // Camera and viewport state
    let vdomInstance = $state(null);
    let activeVDom = $derived($activeDocuments[0]?.activeVDom);
    let localVirtualScale = $state(0.2);
    let offsetX = 0; // Content panning X relative to container
    let offsetY = 0; // Content panning Y relative to container
    let mouseX = 0; // Raw mouse X in viewport
    let mouseY = 0; // Raw mouse Y in viewport
    let cameraX = 0; // Camera translation X
    let cameraY = 0; // Camera translation Y

    // UI state
    let showRightSidebar = true;
    let activeSidebarTab = "styles"; // "styles", "properties", "events"
    let showBlueprintMode = false;
    let showInspector = true;

    // Device settings
    const tweenedWidth = tweened(1179, { duration: 300, easing: quartOut });
    const tweenedHeight = tweened(2556, { duration: 300, easing: quartOut });

    onMount(() => {
        if (activeDocuments.length > 0 && activeDocuments[0].activeVDom) {
            populate(activeDocuments[0].activeVDom);
        }
    });

    let virtualDevices = [
        {
            name: "iPhone 16",
            width: 1179,
            height: 2556,
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

    $effect(() => {
        $activeDocuments[0].width = currentVirtualDevice.width;
        $activeDocuments[0].height = currentVirtualDevice.height;
    });

    // Sidebar state
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

    function setActiveTab(tab) {
        activeSidebarTab = tab;
    }

    // Drag state
    let isDragging = false;
    let dragType = "none"; // "camera", "content", "element"
    let dragStartX = 0;
    let dragStartY = 0;
    let initialCameraX = 0;
    let initialCameraY = 0;
    let initialContentOffsetX = 0;
    let initialContentOffsetY = 0;

    // Element drag state
    let currentDragX = 0;
    let currentDragY = 0;
    let velocityX = 0;
    let velocityY = 0;
    let isSnapping = false;
    let snapTargetId = null;
    let snapPosition = null;
    let snapIndicatorPosition = null;

    // Handle blueprint mode toggle
    function toggleBlueprintMode() {
        showBlueprintMode = !showBlueprintMode;
    }

    function populate(activeVDom) {
        if (!activeVDom) {
            console.error("Cannot populate: activeVDom is null");
            return;
        }

        if (
            typeof activeVDom.rootNodeId === "undefined" ||
            !activeVDom.addNode ||
            !activeVDom.getNode
        ) {
            console.error(
                "Cannot populate: activeVDom is missing required methods or properties",
            );
            return;
        }

        let rootId = activeVDom.rootNodeId;
        console.log("Root node for population:", rootId);

        // Add h1 heading
        const h1Id = activeVDom.addNode("h1", rootId);
        console.log("Created h1 with id:", h1Id);
        const h1Node = activeVDom.getNode(h1Id);
        if (h1Node) {
            console.log("Setting h1 properties");
            h1Node.setProperty(
                "textContent",
                "Virtual DOM Test from +page.svelte",
            );
            h1Node.setStyle("color", "blue");
            h1Node.setStyle("textAlign", "center");
            h1Node.setStyle("marginTop", "20px");
        } else {
            console.error("Failed to get h1Node");
        }

        // Add paragraph
        const pId = activeVDom.addNode("p", rootId);
        console.log("Created p with id:", pId);
        const pNode = activeVDom.getNode(pId);
        if (pNode) {
            console.log("Setting p properties");
            pNode.setProperty(
                "textContent",
                "Hello, Youtube! This is draggable content.",
            );
            pNode.setStyle("margin", "20px");
            pNode.setStyle("fontFamily", "Arial, sans-serif");
        } else {
            console.error("Failed to get pNode");
        }

        // Add button
        const btnId = activeVDom.addNode("button", rootId);
        console.log("Created button with id:", btnId);
        const btnNode = activeVDom.getNode(btnId);
        if (btnNode) {
            console.log("Setting button properties");
            btnNode.setProperty("textContent", "Click Me");
            btnNode.setStyle("padding", "10px 20px");
            btnNode.setStyle("backgroundColor", "#4CAF50");
            btnNode.setStyle("color", "white");
            btnNode.setStyle("border", "none");
            btnNode.setStyle("borderRadius", "4px");
            btnNode.setStyle("cursor", "pointer");
            btnNode.setStyle("margin", "20px");
            btnNode.setProperty("onClick", () => alert("Button clicked!"));
        } else {
            console.error("Failed to get btnNode");
        }

        // Add list
        const ulId = activeVDom.addNode("ul", rootId);
        console.log("Created ul with id:", ulId);
        const ulNode = activeVDom.getNode(ulId);
        if (ulNode) {
            console.log("Setting ul properties");
            ulNode.setStyle("listStyleType", "disc");
            ulNode.setStyle("margin", "20px");
            ulNode.setStyle("backgroundColor", "#ffaaaa");
            ulNode.setStyle("padding", "15px");
            ulNode.setStyle("borderRadius", "8px");
            ulNode.setStyle("borderLeft", "5px solid #ff5555");

            // Add list items
            for (let i = 1; i <= 3; i++) {
                const liId = activeVDom.addNode("li", ulId);
                console.log(`Created li ${i} with id:`, liId);
                const liNode = activeVDom.getNode(liId);
                if (liNode) {
                    console.log(`Setting li ${i} properties`);
                    liNode.setProperty("textContent", `List item ${i}`);
                    liNode.setStyle("padding", "5px");
                    liNode.setStyle("margin", "8px 0");
                    liNode.setStyle("color", "#aa0000");
                    liNode.setStyle("fontWeight", "bold");
                } else {
                    console.error(`Failed to get liNode ${i}`);
                }
            }
        } else {
            console.error("Failed to get ulNode");
        }

        // Helper to convert VNode and its children to the PageContentNode structure
    }

    let isInitialized = $state(false);

    // Debug selected node changes
</script>

<div class="bg-black h-screen">
    <!-- Header (top bar) -->
    <header
        class="absolute top-0 left-0 w-full h-[50px] flex justify-center items-center p-2"
    >
        <span class="z-1000 relative h-full shadow-xl flex justify-center">
            <div class="w-[20vw] rounded-l-md bg-white">
                <div
                    class="w-full h-full rounded-l-md border-[1px]
                border-[#E7E7E7] border-r-[0] flex justify-around p-1"
                >
                    quick settings
                </div>
            </div>
            <div class="z-1000 w-[50vw] bg-white">
                <div
                    class="w-full h-full border-[1px] border-[#E7E7E7] border-l-[0] border-r-[0] flex justify-around p-1"
                >
                    <img src="hand.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="cursor.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="pencil.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="shapes.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="text.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="document.svg" alt="Pencil Icon" class="w-6 h-6" />
                    <img src="code.svg" alt="Screen Icon" class="w-6 h-6" />
                    <img src="servers.svg" alt="Screen Icon" class="w-6 h-6" />
                    <img src="database.svg" alt="Screen Icon" class="w-6 h-6" />
                    <img src="network.svg" alt="Screen Icon" class="w-6 h-6" />
                </div>
            </div>
            <div class="z-1000 w-[20vw] rounded-r-md bg-white">
                <div
                    class="w-full h-full rounded-r-md border-[1px]
                border-[#E7E7E7] border-l-[0] flex justify-around p-1"
                >
                    Profile
                </div>
            </div></span
        >
    </header>

    <aside
        class="absolute top-0 left-0 w-[320px] h-full flex justify-center items-center"
    >
        <div class="z-1000 h-[80vh] w-[300px] shadow-xl rounded-md bg-white">
            <div
                class="w-full h-full rounded-md border-[1px] border-[#E7E7E7]"
            ></div>
        </div>
    </aside>

    <!-- Main content area with viewport -->
    <div class="absolute top-0 left-0 w-full h-full overflow-hidden">
        <Viewport>
            <slot />
        </Viewport>
    </div>
</div>

<style>
    /* Custom scrollbar styling */
    :global(.scrollbar-none::-webkit-scrollbar) {
        display: none;
    }

    :global(.scrollbar-none) {
        scrollbar-width: none;
    }

    /* Blueprint mode styling */
    :global(.blueprint-mode) {
        border: 1px dashed #3b82f6 !important;
        background-color: rgba(59, 130, 246, 0.05) !important;
        color: #3b82f6 !important;
    }

    :global(.blueprint-mode *) {
        border-color: rgba(59, 130, 246, 0.3) !important;
        color: #3b82f6 !important;
    }

    :global(.dragging) {
        outline: 1px dashed #3b82f6;
        background-color: rgba(59, 130, 246, 0.1);
    }

    /* Selected node styling handled by Selectable component */

    :global(.node-moved) {
        animation: highlight-node 0.5s ease-out;
    }

    @keyframes highlight-node {
        0% {
            background-color: rgba(59, 130, 246, 0.2);
        }
        100% {
            background-color: transparent;
        }
    }

    :global(.drop-indicator) {
        position: fixed;
        pointer-events: none;
        z-index: 9999;
        background-color: rgba(59, 130, 246, 0.2);
        border: 2px dashed rgba(59, 130, 246, 0.5);
        border-radius: 3px;
        transition: all 0.1s ease-out;
    }

    :global(.node.snapped) {
        outline: 2px solid #3b82f6 !important;
        box-shadow: 0 0 8px rgba(59, 130, 246, 0.5) !important;
        transition:
            transform 0.2s cubic-bezier(0.2, 0.8, 0.2, 1),
            box-shadow 0.2s ease-out,
            outline 0.2s ease-out !important;
    }

    :global(.node-moved) {
        animation: highlight-node 0.5s ease-out;
    }

    @keyframes highlight-node {
        0% {
            background-color: rgba(59, 130, 246, 0.2);
        }
        100% {
            background-color: transparent;
        }
    }

    :global(.drag-placeholder) {
        border: 2px dashed #4299e1;
        background-color: rgba(66, 153, 225, 0.1);
        border-radius: 4px;
        margin: 2px 0;
        min-height: 20px;
    }

    :global(.drop-indicator) {
        position: fixed;
        z-index: 9999;
        background-color: #4299e1;
        pointer-events: none;
    }
</style>
