<script>
    import { onMount } from "svelte";
    import { browser } from "$app/environment";
    import ArticleCard from "./ArticleCard.svelte";
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
    let { articles = [], heroSize = { cols: 3, rows: 3 } } = $props();

    // Generate dynamically positioned articles
    let generatedArticles = [];
    let screenSize = { cols: 6, rows: 6 }; // Default grid size

    // Function to determine actual size based on screen size and article preferred size
    function calculateActualSize(article, availableSpace) {
        // Start with preferred size
        const preferred = article.size;

        // For smaller screens, we may need to reduce sizes
        let actualCols = Math.min(preferred.cols, availableSpace.cols);
        let actualRows = preferred.rows;

        // High priority articles should maintain their size when possible
        if (article.priority > 2 && availableSpace.cols < 4) {
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

        generateArticles();
    }

    // Function to generate articles with appropriate sizes
    function generateArticles() {
        console.log("Generating articles with:", articles.length, "items");

        // Create a virtual grid to track filled cells
        const gridWidth = screenSize.cols || 6; // Default to 6 if not set
        const gridHeight = 12; // Max height of our virtual grid
        const grid = Array(gridHeight)
            .fill()
            .map(() => Array(gridWidth).fill(false));

        // Position articles in the grid
        const positionedArticles = [];

        // Clone and sort articles by priority (most important first)
        const sortedArticles = [...articles]
            .sort((a, b) => a.priority - b.priority)
            .map((article, index) => ({
                ...article,
                id: index + 1,
                actualSize: calculateActualSize(article, screenSize),
                originalSize: { ...article.size }, // Keep original size for reference
            }));

        // Skip if no articles
        if (sortedArticles.length === 0) {
            generatedArticles = [];
            return;
        }

        // Find the hero article (highest priority)
        const heroArticle = sortedArticles.find(
            (article) => article.priority === 1,
        );

        // Create a working copy of the articles, removing the hero
        let workingArticles = [...sortedArticles];

        // First place the hero article (highest priority) in top left at 3x3
        if (heroArticle) {
            const heroIndex = workingArticles.findIndex(
                (a) => a.id === heroArticle.id,
            );

            if (heroIndex >= 0) {
                // Remove hero from working articles
                workingArticles.splice(heroIndex, 1);

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

                // Add positioned hero article
                positionedArticles.push({
                    ...heroArticle,
                    actualSize: heroSize,
                    position: heroPosition,
                });
            }
        }

        // Place medium priority articles (priority 2)
        for (const article of workingArticles.filter((a) => a.priority === 2)) {
            // Try with original size first
            let position = findPosition(
                grid,
                article.actualSize.cols,
                article.actualSize.rows,
            );

            if (position) {
                // Mark grid cells as filled
                fillGrid(
                    grid,
                    position.row,
                    position.col,
                    article.actualSize.cols,
                    article.actualSize.rows,
                );

                // Add positioned article
                positionedArticles.push({
                    ...article,
                    position,
                });
            }
        }

        // Place low priority articles (priority 3+), trying different sizes to fit
        for (const article of workingArticles.filter((a) => a.priority > 2)) {
            let placed = false;

            // First try expanding to fill gaps
            const gapPositions = findLargestGaps(grid, 3); // Find gaps up to 3 cells wide

            for (const gap of gapPositions) {
                if (placed) break;

                // If the gap is larger than the article's minimum size, use it
                if (gap.width > 1 || gap.height > 1) {
                    // Mark grid cells as filled
                    fillGrid(grid, gap.row, gap.col, gap.width, gap.height);

                    // Add positioned article with expanded size to fill gap
                    positionedArticles.push({
                        ...article,
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
                    let cols = Math.min(article.actualSize.cols, 2);
                    cols >= 1;
                    cols--
                ) {
                    if (placed) break;

                    for (
                        let rows = Math.min(article.actualSize.rows, 2);
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

                            // Add positioned article with adjusted size
                            positionedArticles.push({
                                ...article,
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

                    // Add positioned article with minimal size
                    positionedArticles.push({
                        ...article,
                        actualSize: { cols: 1, rows: 1 },
                        position,
                    });
                }
            }
        }

        // Sort by position for proper rendering
        positionedArticles.sort((a, b) => {
            if (a.position.row === b.position.row) {
                return a.position.col - b.position.col;
            }
            return a.position.row - b.position.row;
        });

        generatedArticles = positionedArticles;
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
    class="grid grid-cols-3 sm:grid-cols-6 md:grid-cols-6 lg:grid-cols-6 xl:grid-cols-6 gap-4 p-6 w-full min-h-screen auto-rows-min mx-auto"
    style="width: 90%; max-width: 1800px; perspective: 1000px;"
>
    <!-- Three column top row -->
    <GlassPanel
        as="header"
        class="col-span-1 sm:col-span-2 h-16 flex justify-center items-center font-medium text-xl uppercase relative overflow-hidden transform hover:scale-[1.02] transition-transform"
        interactive={true}
    >
        <div
            class="z-10 relative bg-gradient-to-r from-indigo-500 to-purple-500 bg-clip-text text-transparent font-bold tracking-wider"
        >
            OUTPOST: ZERO
        </div>
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
        <p class="text-sm font-medium tracking-wider z-10 relative text-center">
            <span class="text-indigo-300">SURVIVE</span>
            <span class="mx-2 opacity-60">•</span>
            <span class="text-purple-300">AUTOMATE</span>
            <span class="mx-2 opacity-60">•</span>
            <span class="text-indigo-300">THRIVE</span>
        </p>
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

    {#each generatedArticles as article}
        <ArticleCard
            {article}
            size={article.actualSize}
            position={article.position}
        />
    {/each}

    <slot />
</div>
