<script lang="ts">
    import "../app.css";

    import { onMount } from "svelte";
    import Node from "$lib/Node.svelte";
    import Document from "$lib/components/Document.svelte";
    import { cubicOut, quartOut } from "svelte/easing";
    import { tweened } from "svelte/motion";
    import { fade, fly } from "svelte/transition";
    import Viewport from "$lib/components/Viewport.svelte";
    import Tailwind from "$lib/Tailwind.svelte";

    // Camera and viewport state
    let virtualScale = 0.2;
    let offsetX = 0; // Content panning X relative to container
    let offsetY = 0; // Content panning Y relative to container
    let mouseX = 0; // Raw mouse X in viewport
    let mouseY = 0; // Raw mouse Y in viewport
    let cameraX = 0; // Camera translation X
    let cameraY = 0; // Camera translation Y

    // UI state
    let showRightSidebar = true;
    let activeSidebarTab = "Style"; // "Style", "Settings", "Interactions"
    let selectedNodeId = null;
    let showBlueprintMode = false;

    // VDOM structure for our application
    let vdom = {
        rootId: "root",
        nodes: {
            root: {
                id: "root",
                type: "div",
                styles: {
                    position: "relative",
                    width: "100%",
                    height: "100%",
                    padding: "20px",
                },
                children: [],
            },
        },
        getNode(id) {
            return this.nodes[id];
        },
        addNode(node) {
            this.nodes[node.id] = node;
            return node.id;
        },
        updateNode(id, updates) {
            this.nodes[id] = { ...this.nodes[id], ...updates };
            vdom = vdom; // Trigger reactive update
        },
        moveNode(nodeId, targetId, position) {
            const node = this.nodes[nodeId];
            const target = this.nodes[targetId];
            if (!node || !target) return false;

            // Find the current parent of the node
            let oldParentId = null;
            for (const id in this.nodes) {
                if (
                    this.nodes[id].children &&
                    this.nodes[id].children.includes(nodeId)
                ) {
                    oldParentId = id;
                    break;
                }
            }

            if (!oldParentId) return false;

            // Remove from old parent
            this.nodes[oldParentId].children = this.nodes[
                oldParentId
            ].children.filter((id) => id !== nodeId);

            if (position === "inside") {
                // Add as child of final target
                const finalTargetNode = vdom.getNode(finalTargetId);
                if (!finalTargetNode.children) finalTargetNode.children = [];
                finalTargetNode.children.push(nodeId);
            } else {
                // Find target's parent
                let targetParentId = null;
                for (const id in this.nodes) {
                    if (
                        this.nodes[id].children &&
                        this.nodes[id].children.includes(targetId)
                    ) {
                        targetParentId = id;
                        break;
                    }
                }

                if (!targetParentId) return false;

                // Add to target's parent at the right position
                const targetParent = this.nodes[targetParentId];
                const targetIndex = targetParent.children.indexOf(targetId);

                if (position === "before") {
                    targetParent.children.splice(targetIndex, 0, nodeId);
                } else if (position === "after") {
                    targetParent.children.splice(targetIndex + 1, 0, nodeId);
                }
            }

            // Update VDOM to trigger re-render
            vdom = { ...vdom };
            return true;
        },
    };

    // Device settings
    const tweenedWidth = tweened(1179, { duration: 300, easing: quartOut });
    const tweenedHeight = tweened(2556, { duration: 300, easing: quartOut });

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
    let currentVirtualDeviceIndex = 0;
    $: currentVirtualDevice = virtualDevices[currentVirtualDeviceIndex];

    // Update device viewport dimensions
    function updateDeviceViewport() {
        const newWidth = currentVirtualDevice.width;
        const newHeight = currentVirtualDevice.height;

        // Reset camera/pan on device change
        cameraX = 0;
        cameraY = 0;
        offsetX = 0;
        offsetY = 0;
        virtualScale = 0.2;

        document.documentElement.style.setProperty(
            "--virtual-scale",
            virtualScale.toString(),
        );
        document.documentElement.style.setProperty(
            "--camera-x",
            `${cameraX}px`,
        );
        document.documentElement.style.setProperty(
            "--camera-y",
            `${cameraY}px`,
        );
        document.documentElement.style.setProperty(
            "--offset-x",
            `${offsetX}px`,
        );
        document.documentElement.style.setProperty(
            "--offset-y",
            `${offsetY}px`,
        );

        tweenedWidth.set(newWidth);
        tweenedHeight.set(newHeight);
    }

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

    // Initialize demo content
    onMount(() => {
        // Create some sample nodes
        const header = {
            id: "header-1",
            type: "header",
            styles: {
                position: "absolute",
                top: "50px",
                left: "50px",
                background: "#f3f4f6",
                padding: "10px",
                borderRadius: "4px",
                boxShadow: "0 2px 4px rgba(0,0,0,0.1)",
            },
            props: {
                textContent: "Drag me around!",
            },
            children: [],
        };

        const paragraph = {
            id: "paragraph-1",
            type: "p",
            styles: {
                position: "absolute",
                top: "150px",
                left: "50px",
                background: "#e0f2fe",
                padding: "12px",
                borderRadius: "4px",
                maxWidth: "300px",
            },
            props: {
                textContent:
                    "This is a simplified drag and drop builder. Select elements and move them around!",
            },
            children: [],
        };

        const button = {
            id: "button-1",
            type: "button",
            styles: {
                position: "absolute",
                top: "250px",
                left: "35px",
                background: "#4f46e5",
                color: "white",
                padding: "8px 16px",
                border: "none",
                borderRadius: "4px",
                cursor: "pointer",
            },
            props: {
                textContent: "Click Me",
            },
            children: [],
        };

        // Add nodes to VDOM
        vdom.addNode(header);
        vdom.addNode(paragraph);
        vdom.addNode(button);

        // Add them as children of root
        vdom.nodes.root.children = ["header-1", "paragraph-1", "button-1"];

        // Set initial device properties
        updateDeviceViewport();
    });
</script>

<div
    class="bg-black grid grid-cols-[35px_1fr_auto] grid-rows-[35px_1fr] h-screen"
>
    <!-- Header (top bar) -->
    <header
        class="col-span-3 row-start-1 bg-black flex items-center justify-center p-2"
    >
        <select
            class="bg-[#27272a] text-white text-sm rounded px-2 py-1 mr-4"
            bind:value={currentVirtualDeviceIndex}
            on:change={updateDeviceViewport}
        >
            {#each virtualDevices as device, i}
                <option value={i}>{device.name}</option>
            {/each}
        </select>
        <button
            class="ml-4 px-3 py-1 rounded text-xs bg-[#27272a] border border-gray-600 hover:bg-[#3f3f46]"
            on:click={toggleBlueprintMode}
        >
            {showBlueprintMode ? "Show Actual Design" : "Show Blueprint View"}
        </button>
    </header>

    <!-- Left sidebar -->
    <nav class="col-start-1 row-span-3 bg-black flex flex-col items-center">
        d
    </nav>

    <!-- Main content area with viewport -->
    <div class="col-start-2 row-start-2 overflow-hidden">
        <Viewport
            {vdom}
            {selectedNodeId}
            {showBlueprintMode}
            {virtualDevices}
            {virtualScale}
            {mouseX}
            {mouseY}
            dispatch={(event: string, detail: any) =>
                handleNodeEvent(event, detail)}><slot /></Viewport
        >
    </div>

    <!-- Right sidebar -->
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

            <div class="overflow-y-auto h-[calc(100vh-5rem)]">
                {#if activeSidebarTab === "Style"}
                    <div
                        class="p-3"
                        in:fly={{ y: 10, duration: 200, delay: 50 }}
                        out:fade={{ duration: 150 }}
                    >
                        {#if selectedNodeId && vdom.getNode(selectedNodeId)}
                            <div class="mb-4">
                                <h3 class="text-sm font-medium mb-2">
                                    Selected Element
                                </h3>
                                <div class="text-xs text-gray-400">
                                    <p>
                                        Type: {vdom.getNode(selectedNodeId)
                                            .type}
                                    </p>
                                    <p>ID: {selectedNodeId}</p>
                                </div>
                            </div>

                            <div class="mb-4">
                                <h3 class="text-sm font-medium mb-2">
                                    Position
                                </h3>
                                <div class="grid grid-cols-2 gap-2">
                                    <div>
                                        <label class="text-xs text-gray-400"
                                            >Top</label
                                        >
                                        <input
                                            type="text"
                                            class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
                                            value={vdom.getNode(selectedNodeId)
                                                .styles?.top || "0px"}
                                        />
                                    </div>
                                    <div>
                                        <label class="text-xs text-gray-400"
                                            >Left</label
                                        >
                                        <input
                                            type="text"
                                            class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
                                            value={vdom.getNode(selectedNodeId)
                                                .styles?.left || "0px"}
                                        />
                                    </div>
                                </div>
                            </div>

                            <div class="mb-4">
                                <h3 class="text-sm font-medium mb-2">Size</h3>
                                <div class="grid grid-cols-2 gap-2">
                                    <div>
                                        <label class="text-xs text-gray-400"
                                            >Width</label
                                        >
                                        <input
                                            type="text"
                                            class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
                                            value={vdom.getNode(selectedNodeId)
                                                .styles?.width || "auto"}
                                        />
                                    </div>
                                    <div>
                                        <label class="text-xs text-gray-400"
                                            >Height</label
                                        >
                                        <input
                                            type="text"
                                            class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
                                            value={vdom.getNode(selectedNodeId)
                                                .styles?.height || "auto"}
                                        />
                                    </div>
                                </div>
                            </div>
                        {:else}
                            <p class="text-sm text-gray-400">
                                No element selected
                            </p>
                        {/if}
                    </div>
                {:else if activeSidebarTab === "Settings"}
                    <div
                        class="p-3"
                        in:fly={{ y: 10, duration: 200, delay: 50 }}
                        out:fade={{ duration: 150 }}
                    >
                        <h3 class="text-sm font-medium mb-3">Settings</h3>
                        <p class="text-xs text-gray-400">
                            Builder settings would go here.
                        </p>
                    </div>
                {:else if activeSidebarTab === "Interactions"}
                    <div
                        class="p-3"
                        in:fly={{ y: 10, duration: 200, delay: 50 }}
                        out:fade={{ duration: 150 }}
                    >
                        <h3 class="text-sm font-medium mb-3">Interactions</h3>
                        <p class="text-xs text-gray-400">
                            Interaction settings would go here.
                        </p>
                    </div>
                {/if}
            </div>
        </div>
    </aside>
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

    :global(.node.selected) {
        outline: 3px solid #3b82f6 !important;
        box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.3) !important;
        position: relative;
        z-index: 10 !important;
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
