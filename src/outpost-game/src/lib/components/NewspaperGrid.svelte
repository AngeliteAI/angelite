<script>
    import { onMount } from "svelte";
    import { browser } from "$app/environment";
    import ArticleCard from "./ArticleCard.svelte";
    import TweetCard from "./TweetCard.svelte";
    import GlassPanel from "./GlassPanel.svelte";
    import NewsletterCTA from "./NewsletterCTA.svelte";

    /**
     * NewspaperGrid component
     * Creates a responsive newspaper-style grid layout
     *
     * Props:
     * - title: Title to display in the header
     * - articles: Array of article objects
     */
    let { items = [], heroSize = { cols: 3, rows: 3 } } = $props();

    // Generate dynamically positioned items
    let generatedItems = [];
    let screenSize = { cols: 6, rows: 6 }; // Default grid size

    // Function to determine actual size based on screen size and article preferred size
    function calculateActualSize(item, availableSpace) {
        // Start with preferred size
        const preferred = item.size;

        // For smaller screens, we may need to reduce sizes
        let actualCols = Math.min(preferred.cols, availableSpace.cols);
        let actualRows = preferred.rows;

        // High priority items should maintain their size when possible
        if (item.priority > 2 && availableSpace.cols < 4) {
            actualCols = Math.min(actualCols, 1);
        }

        return { cols: actualCols, rows: actualRows };
    }

    // Function to detect screen size and adjust grid accordingly
    function adjustToScreenSize() {
        if (!browser) return;

        const width = window.innerWidth;

        // Set columns based on screen width
        if (width < 640) {
            screenSize = { cols: 2, rows: 8 }; // Mobile: 2 columns
        } else if (width < 768) {
            screenSize = { cols: 3, rows: 8 }; // Small tablets: 3 columns
        } else if (width < 1024) {
            screenSize = { cols: 4, rows: 6 }; // Tablets: 4 columns
        } else if (width < 1280) {
            screenSize = { cols: 5, rows: 6 }; // Small desktops: 5 columns
        } else {
            screenSize = { cols: 6, rows: 6 }; // Large desktops: 6 columns
        }

        generateItems();
    }

    // Function to generate items with appropriate sizes
    function generateItems() {
        console.log("Generating items with:", items.length, "items");

        // Create a virtual grid to track filled cells
        const gridWidth = screenSize.cols || 6; // Default to 6 if not set
        const gridHeight = 12; // Max height of our virtual grid
        const grid = Array(gridHeight)
            .fill()
            .map(() => Array(gridWidth).fill(false));

        // Position items in the grid
        const positionedItems = [];

        // Clone and sort items by priority (most important first)
        const sortedItems = [...items]
            .sort((a, b) => a.priority - b.priority)
            .map((item, index) => ({
                ...item,
                id: index + 1,
                actualSize: calculateActualSize(item, screenSize),
                originalSize: { ...item.size }, // Keep original size for reference
            }));

        // Skip if no items
        if (sortedItems.length === 0) {
            generatedItems = [];
            return;
        }

        // Find the hero item (highest priority)
        const heroItem = sortedItems.find(
            (item) => item.priority === 1,
        );

        // Create a working copy of the items, removing the hero
        let workingItems = [...sortedItems];

        // First place the hero item (highest priority) in top left at 3x3
        if (heroItem) {
            const heroIndex = workingItems.findIndex(
                (a) => a.id === heroItem.id,
            );

            if (heroIndex >= 0) {
                // Remove hero from working items
                workingItems.splice(heroIndex, 1);

                // Force hero to be 3x3 in size (or smaller if screen is too small)
                const heroSize = {
                    cols: Math.min(3, gridWidth),
                    rows: 3,
                };

                // Place at position 1,0 (after header)
                const heroPosition = { row: 1, col: 0 };

                // Mark grid cells as filled
                fillGrid(
                    grid,
                    heroPosition.row,
                    heroPosition.col,
                    heroSize.cols,
                    heroSize.rows,
                );

                // Add positioned hero item
                positionedItems.push({
                    ...heroItem,
                    actualSize: heroSize,
                    position: heroPosition,
                });
            }
        }

        // Place medium priority items (priority 2)
        for (const item of workingItems.filter((a) => a.priority === 2)) {
            // Try with original size first
            let position = findPosition(
                grid,
                item.actualSize.cols,
                item.actualSize.rows,
            );

            if (position) {
                // Mark grid cells as filled
                fillGrid(
                    grid,
                    position.row,
                    position.col,
                    item.actualSize.cols,
                    item.actualSize.rows,
                );

                // Add positioned item
                positionedItems.push({
                    ...item,
                    position,
                });
            }
        }

        // Place low priority items (priority 3+), trying different sizes to fit
        for (const item of workingItems.filter((a) => a.priority > 2)) {
            let placed = false;

            // First try expanding to fill gaps
            const gapPositions = findLargestGaps(grid, 3); // Find gaps up to 3 cells wide

            for (const gap of gapPositions) {
                if (placed) break;

                // If the gap is larger than the item's minimum size, use it
                if (gap.width > 1 || gap.height > 1) {
                    // Mark grid cells as filled
                    fillGrid(grid, gap.row, gap.col, gap.width, gap.height);

                    // Add positioned item with expanded size to fill gap
                    positionedItems.push({
                        ...item,
                        actualSize: { cols: gap.width, rows: gap.height },
                        position: { row: gap.row, col: gap.col },
                    });

                    placed = true;
                    break;
                }
            }

            // Try different sizes to fit empty spaces
            if (!placed) {
                for (
                    let cols = Math.min(item.actualSize.cols, 2);
                    cols >= 1;
                    cols--
                ) {
                    if (placed) break;

                    for (
                        let rows = Math.min(item.actualSize.rows, 2);
                        rows >= 1;
                        rows--
                    ) {
                        const position = findPosition(grid, cols, rows);

                        if (position) {
                            // Mark grid cells as filled
                            fillGrid(
                                grid,
                                position.row,
                                position.col,
                                cols,
                                rows,
                            );

                            // Add positioned item with adjusted size
                            positionedItems.push({
                                ...item,
                                actualSize: { cols, rows },
                                position,
                            });

                            placed = true;
                            break;
                        }
                    }
                }
            }

            // If we couldn't place with any size, try one more time with minimal size
            if (!placed) {
                const position = findPosition(grid, 1, 1);

                if (position) {
                    // Mark grid cells as filled
                    fillGrid(grid, position.row, position.col, 1, 1);

                    // Add positioned item with minimal size
                    positionedItems.push({
                        ...item,
                        actualSize: { cols: 1, rows: 1 },
                        position,
                    });
                }
            }
        }

        // Sort by position for proper rendering
        positionedItems.sort((a, b) => {
            if (a.position.row === b.position.row) {
                return a.position.col - b.position.col;
            }
            return a.position.row - b.position.row;
        });

        generatedItems = positionedItems;
    }

    // Helper function to find next available position in the grid
    function findPosition(grid, width, height) {
        const gridWidth = grid[0].length;
        const gridHeight = grid.length;

        for (let row = 1; row < gridHeight - height + 1; row++) {
            for (let col = 0; col < gridWidth - width + 1; col++) {
                // Check if this position is available
                let canFit = true;

                for (let r = 0; r < height; r++) {
                    for (let c = 0; c < width; c++) {
                        if (grid[row + r][col + c]) {
                            canFit = false;
                            break;
                        }
                    }
                    if (!canFit) break;
                }

                if (canFit) {
                    return { row, col };
                }
            }
        }

        return null;
    }

    // Helper function to find gaps in the grid
    function findLargestGaps(grid, maxSize = 3) {
        const gridWidth = grid[0].length;
        const gridHeight = grid.length;
        const gaps = [];

        // Find horizontal gaps (multi-column gaps)
        for (let row = 1; row < gridHeight; row++) {
            let gapStart = -1;

            for (let col = 0; col < gridWidth; col++) {
                if (!grid[row][col]) {
                    // Found an empty cell
                    if (gapStart === -1) {
                        gapStart = col;
                    }
                } else if (gapStart !== -1) {
                    // End of a gap
                    const gapWidth = col - gapStart;

                    if (gapWidth > 1 && gapWidth <= maxSize) {
                        // Check if we can extend vertically
                        let maxHeight = 1;

                        // Try to extend downward
                        for (
                            let r = row + 1;
                            r < gridHeight && maxHeight < maxSize;
                            r++
                        ) {
                            let canExtend = true;

                            for (let c = gapStart; c < col; c++) {
                                if (grid[r][c]) {
                                    canExtend = false;
                                    break;
                                }
                            }

                            if (canExtend) {
                                maxHeight++;
                            } else {
                                break;
                            }
                        }

                        gaps.push({
                            row: row,
                            col: gapStart,
                            width: gapWidth,
                            height: maxHeight,
                            area: gapWidth * maxHeight,
                        });
                    }

                    gapStart = -1;
                }
            }

            // Check for gap at the end of the row
            if (gapStart !== -1) {
                const gapWidth = gridWidth - gapStart;

                if (gapWidth > 1 && gapWidth <= maxSize) {
                    let maxHeight = 1;

                    // Try to extend downward
                    for (
                        let r = row + 1;
                        r < gridHeight && maxHeight < maxSize;
                        r++
                    ) {
                        let canExtend = true;

                        for (let c = gapStart; c < gridWidth; c++) {
                            if (grid[r][c]) {
                                canExtend = false;
                                break;
                            }
                        }

                        if (canExtend) {
                            maxHeight++;
                        } else {
                            break;
                        }
                    }

                    gaps.push({
                        row: row,
                        col: gapStart,
                        width: gapWidth,
                        height: maxHeight,
                        area: gapWidth * maxHeight,
                    });
                }
            }
        }

        // Sort gaps by area (largest first)
        return gaps.sort((a, b) => b.area - a.area);
    }

    // Helper function to mark grid cells as filled
    function fillGrid(grid, startRow, startCol, width, height) {
        for (let r = 0; r < height; r++) {
            for (let c = 0; c < width; c++) {
                if (
                    startRow + r < grid.length &&
                    startCol + c < grid[0].length
                ) {
                    grid[startRow + r][startCol + c] = true;
                }
            }
        }
    }

    // Generate items immediately on component creation
    generateItems();

    onMount(() => {
        // Force immediate item generation on mount
        generateItems();
        adjustToScreenSize();

        // Add resize listener to adjust layout when screen size changes
        window.addEventListener("resize", () => {
            adjustToScreenSize();
        });

        // Clean up event listener on component destroy
        return () => {
            window.removeEventListener("resize", adjustToScreenSize);
        };
    });
</script>

<div
    class="grid grid-cols-3 sm:grid-cols-6 md:grid-cols-6 lg:grid-cols-6 xl:grid-cols-6 gap-4 p-6 w-full min-h-screen auto-rows-min mx-auto"
    style="width: 90%; max-width: 1800px; perspective: 1000px;"
>
    <!-- Three column top row -->
    <GlassPanel
        as="header"
        class="col-span-1 sm:col-span-2 h-16 flex justify-center p-1 font-medium text-xl uppercase relative overflow-hidden transform hover:scale-[1.02] transition-transform"
        interactive={true}
    >
        <div
            class="z-10 relative text-center font-bold tracking-wider text-base"
        >
            OUTPOST: ZERO
        </div> <p class="text-sm font-medium tracking-wider z-10 relative text-center text-xs flex justify-around items-center">
                   <span class="text-indigo-300 pl-4">SURVIVE</span>
                   <span class="mx-2 opacity-60">•</span>
                   <span class="text-purple-300">AUTOMATE</span>
                   <span class="mx-2 opacity-60">•</span>
                   <span class="text-indigo-300 pr-4">THRIVE</span>
               </p>
    </GlassPanel>

    <!-- Game slogan with premium effect -->
    <GlassPanel
        as="div"
        class="col-span-1 sm:col-span-2 h-16 flex justify-center items-center relative overflow-hidden transform hover:scale-[1.02] transition-transform"
        interactive={true}
    >
        <div
            class="absolute inset-0 bg-gradient-to-r from-transparent via-purple-500/20 to-transparent z-0 animate-pulse"
            style="animation-duration: 3s;"
        ></div>

    </GlassPanel>

    <!-- Newsletter CTA -->
    <div
        class="col-span-1 sm:col-span-2 row-span-1 row-start-1 self-center w-full h-full"
    >
        <div
            class="h-full w-full transform hover:scale-[1.01] transition-transform"
        >
            <NewsletterCTA />
        </div>
    </div>

    <!-- Reset grid for article placement -->
    <div class="col-span-full h-4"></div>

    <!-- Mark the start of articles section -->
    <div class="col-span-full" style="height: 0; position: relative;">
        <div
            class="absolute left-0 right-0 h-px bg-gradient-to-r from-transparent via-indigo-500/30 to-transparent"
        ></div>
    </div>

    {#each generatedItems as item}
        {#if item.type === 'tweet'}
            <TweetCard
                tweet={item}
                size={item.actualSize}
                position={item.position}
            />
        {:else}
            <ArticleCard
                article={item}
                size={item.actualSize}
                position={item.position}
            />
        {/if}
    {/each}

    <slot />
</div>
