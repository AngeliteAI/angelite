<script>
    import { onMount } from "svelte";
    import { browser } from "$app/environment";
    import ArticleCard from "./ArticleCard.svelte";
    import GlassPanel from "./GlassPanel.svelte";

    /**
     * NewspaperGrid component
     * Creates a responsive newspaper-style grid layout
     *
     * Props:
     * - title: Title to display in the header
     * - articles: Array of article objects
     */
    let { articles = [], heroSize = { cols: 4, rows: 3 } } = $props();

    // Generate dynamically positioned articles
    let generatedArticles = [];
    let screenSize = { cols: 3, rows: 8 }; // Default grid size

    // Removed - size calculation is now inline in generateArticles

    // Function to detect screen size and adjust grid accordingly
    function adjustToScreenSize() {
        if (!browser) return;

        const width = window.innerWidth;

        // Responsive columns based on screen width
        if (width < 640) {
            screenSize = { cols: 1, rows: 12 }; // Mobile: 1 column
        } else if (width < 1024) {
            screenSize = { cols: 2, rows: 10 }; // Tablet: 2 columns
        } else {
            screenSize = { cols: 3, rows: 8 }; // Desktop: 3 columns
        }

        generateArticles();
    }

    // Function to generate articles with appropriate sizes
    function generateArticles() {
        console.log("Generating articles with:", articles.length, "items");

        // Create a virtual grid to track filled cells
        const gridWidth = screenSize.cols || 3;
        const gridHeight = 20;
        const grid = Array(gridHeight)
            .fill()
            .map(() => Array(gridWidth).fill(false));

        // Define responsive sizes based on available columns
        const sizeOptions = {
            hero: gridWidth === 1 ? [
                { cols: 1, rows: 2 }   // Mobile hero
            ] : gridWidth === 2 ? [
                { cols: 2, rows: 2 }   // Tablet hero
            ] : [
                { cols: 3, rows: 3 },  // Desktop hero - massive
                { cols: 3, rows: 2 }   // Desktop hero - large
            ],
            medium: gridWidth === 1 ? [
                { cols: 1, rows: 1 }   // Mobile medium
            ] : gridWidth === 2 ? [
                { cols: 2, rows: 1 },  // Tablet wide
                { cols: 1, rows: 1 }   // Tablet square
            ] : [
                { cols: 2, rows: 2 },  // Desktop large square
                { cols: 2, rows: 1 },  // Desktop wide
            ],
            small: [
                { cols: 1, rows: 1 }   // Always 1x1 for small
            ]
        };

        // Clone and prepare articles
        const preparedArticles = [...articles].map((article, index) => {
            let sizes;
            if (article.priority === 1) {
                sizes = sizeOptions.hero;
            } else if (article.priority === 2) {
                sizes = sizeOptions.medium;
            } else {
                sizes = sizeOptions.small;
            }
            
            // Pick the first size that fits
            let chosenSize = sizes[0];
            for (const size of sizes) {
                if (size.cols <= gridWidth) {
                    chosenSize = size;
                    break;
                }
            }
            
            return {
                ...article,
                id: index + 1,
                actualSize: { ...chosenSize },
                originalSize: { ...article.size },
            };
        });

        if (preparedArticles.length === 0) {
            generatedArticles = [];
            return;
        }

        const positionedArticles = [];

        // Sort by priority then by size
        const sortedArticles = [...preparedArticles].sort((a, b) => {
            if (a.priority !== b.priority) return a.priority - b.priority;
            const aArea = a.actualSize.cols * a.actualSize.rows;
            const bArea = b.actualSize.cols * b.actualSize.rows;
            return bArea - aArea;
        });

        // Simple bin packing with staggered preference
        for (let i = 0; i < sortedArticles.length; i++) {
            const article = sortedArticles[i];
            let placed = false;
            
            // Try to place in a staggered pattern - start from row 0
            for (let row = 0; row < gridHeight - article.actualSize.rows + 1 && !placed; row++) {
                // Calculate preferred columns for staggering
                const preferredCols = [];
                if (row % 2 === 0) {
                    // Even rows: prefer even columns
                    for (let col = 0; col <= gridWidth - article.actualSize.cols; col += 2) {
                        preferredCols.push(col);
                    }
                    // Then try odd columns
                    for (let col = 1; col <= gridWidth - article.actualSize.cols; col += 2) {
                        preferredCols.push(col);
                    }
                } else {
                    // Odd rows: prefer odd columns
                    for (let col = 1; col <= gridWidth - article.actualSize.cols; col += 2) {
                        preferredCols.push(col);
                    }
                    // Then try even columns
                    for (let col = 0; col <= gridWidth - article.actualSize.cols; col += 2) {
                        preferredCols.push(col);
                    }
                }
                
                // Try each preferred column
                for (const col of preferredCols) {
                    if (canPlaceAt(grid, row, col, article.actualSize.cols, article.actualSize.rows)) {
                        // Place the article
                        for (let r = 0; r < article.actualSize.rows; r++) {
                            for (let c = 0; c < article.actualSize.cols; c++) {
                                grid[row + r][col + c] = true;
                            }
                        }
                        
                        positionedArticles.push({
                            ...article,
                            position: { row, col }
                        });
                        
                        placed = true;
                        break;
                    }
                }
            }
        }

        // Fill remaining gaps with small articles
        fillRemainingGaps(grid, positionedArticles, gridWidth, gridHeight);

        generatedArticles = positionedArticles;
    }

    // Fill gaps with appropriately sized articles
    function fillRemainingGaps(grid, articles, gridWidth, gridHeight) {
        // Find the last row with content
        let lastRow = 1;
        for (let row = gridHeight - 1; row >= 1; row--) {
            for (let col = 0; col < gridWidth; col++) {
                if (grid[row][col]) {
                    lastRow = row;
                    break;
                }
            }
            if (lastRow > 1) break;
        }
        
        // Only fill gaps up to the last content row
        const maxFillRow = Math.min(lastRow + 2, gridHeight - 1);
        
        // Look for gaps and fill with appropriate sizes
        for (let row = 0; row < maxFillRow; row++) {
            for (let col = 0; col < gridWidth; col++) {
                if (!grid[row][col]) {
                    // Try to fill with 2x1 first
                    if (col + 1 < gridWidth && !grid[row][col + 1]) {
                        const fillerArticle = {
                            id: `filler-${articles.length + 1}`,
                            title: "Filler",
                            component: null,
                            props: {
                                title: "Latest News",
                                type: "filler",
                                content: "Stay updated with the latest developments.",
                                image: null,
                            },
                            priority: 999,
                            actualSize: { cols: 2, rows: 1 },
                            position: { row, col },
                        };
                        
                        articles.push(fillerArticle);
                        grid[row][col] = true;
                        grid[row][col + 1] = true;
                        col++; // Skip next column
                    } else {
                        // Fill with 1x1
                        const fillerArticle = {
                            id: `filler-${articles.length + 1}`,
                            title: "Filler",
                            component: null,
                            props: {
                                title: "Quick Update",
                                type: "filler",
                                content: "Brief update.",
                                image: null,
                            },
                            priority: 999,
                            actualSize: { cols: 1, rows: 1 },
                            position: { row, col },
                        };
                        
                        articles.push(fillerArticle);
                        grid[row][col] = true;
                    }
                }
            }
        }
    }

    // Removed gap filling functions - bin packing handles layout

    function maxRowToFill(grid, col, width) {
        const gridHeight = grid.length;
        let maxRow = 0;

        for (let row = 0; row < gridHeight; row++) {
            if (!canPlaceAt(grid, row, col, width, 1)) {
                break;
            }
            maxRow = row;
        }

        return maxRow;
    }

    // Check if we can place an item at a position
    function canPlaceAt(grid, row, col, width, height) {
        const gridWidth = grid[0].length;
        const gridHeight = grid.length;

        if (row + height > gridHeight || col + width > gridWidth) {
            return false;
        }

        for (let r = 0; r < height; r++) {
            for (let c = 0; c < width; c++) {
                if (grid[row + r][col + c]) {
                    return false;
                }
            }
        }

        return true;
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

    // New function to find all gaps, including single cells
    function findAllGaps(grid) {
        const gridWidth = grid[0].length;
        const gridHeight = grid.length;
        const gaps = [];

        // Start from row 1 to skip the header row
        for (let row = 1; row < gridHeight; row++) {
            for (let col = 0; col < gridWidth; col++) {
                if (!grid[row][col]) {
                    // Found an empty cell, now find the maximum rectangle
                    let maxWidth = 1;
                    let maxHeight = 1;

                    // Find maximum width
                    for (let c = col + 1; c < gridWidth && !grid[row][c]; c++) {
                        maxWidth++;
                    }

                    // Find maximum height for this width
                    outer: for (let r = row + 1; r < gridHeight; r++) {
                        for (let c = col; c < col + maxWidth; c++) {
                            if (grid[r][c]) {
                                break outer;
                            }
                        }
                        maxHeight++;
                    }

                    gaps.push({
                        row: row,
                        col: col,
                        width: maxWidth,
                        height: maxHeight,
                        area: maxWidth * maxHeight,
                    });

                    // Mark this gap as processed to avoid duplicates
                    for (
                        let r = row;
                        r < row + maxHeight && r < gridHeight;
                        r++
                    ) {
                        for (
                            let c = col;
                            c < col + maxWidth && c < gridWidth;
                            c++
                        ) {
                            grid[r][c] = true;
                        }
                    }
                }
            }
        }

        // Restore the grid
        for (const gap of gaps) {
            for (let r = gap.row; r < gap.row + gap.height; r++) {
                for (let c = gap.col; c < gap.col + gap.width; c++) {
                    grid[r][c] = false;
                }
            }
        }

        // Sort gaps by position (top to bottom, left to right)
        return gaps.sort((a, b) => {
            if (a.row !== b.row) return a.row - b.row;
            return a.col - b.col;
        });
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

    // Generate articles immediately on component creation
    generateArticles();

    onMount(() => {
        // Force immediate article generation on mount
        generateArticles();
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
    class="grid gap-4 p-6 w-full min-h-screen"
    style="display: grid; grid-template-columns: repeat({screenSize.cols}, minmax(0, 1fr)); max-width: 100%; perspective: 1000px; grid-auto-rows: minmax(300px, auto);"
>

    {#each generatedArticles as article}
        <div
            style="grid-column: {article.position.col + 1} / span {article
                .actualSize.cols};
                   grid-row: {article.position.row + 1} / span {article
                .actualSize.rows};"
            class="h-full w-full"
        >
            {#if article.component}
                <svelte:component this={article.component} {...article.props} />
            {:else}
                <ArticleCard
                    article={{ ...article, content: article.content || "" }}
                    size={article.actualSize}
                    position={article.position}
                />
            {/if}
        </div>
    {/each}

    <slot />
</div>

<style>
    .filler-article {
        opacity: 0.85;
        background-color: rgba(var(--color-bg-1), 0.7);
        border: 1px dashed rgba(var(--color-border), 0.5);
    }
</style>
