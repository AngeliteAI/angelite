<script>
    import { onMount } from "svelte";
    /** @type {boolean} */
    export let sent = false;

    const BUBBLE_WIDTH = 450;
    const BUBBLE_HEIGHT = 100;
    const NUM_POINTS = 50;
    const DOT_SIZE = 12; // Increased dot size
    const MIN_DISTANCE = 32;
    const CORNER_RADIUS = 25;
    const WAVE_RADIUS = 20;
    const WAVE_STRENGTH = 3;

    // Spring constants
    const SPRING_CONSTANT = 0.01;
    const DAMPING = 0.8;

    // Collision constants
    const COLLISION_STEPS = 5;

    /** @type {Array<{x: number, y: number, originalX: number, originalY: number, targetX: number, targetY: number, vx: number, vy: number, size: number}>} */
    let points = [];
    let targetPoint = null;
    let mouseX = 0;
    let mouseY = 0;
    let isHovering = false;

    function generatePoints() {
        points = [];
        const grid = [];
        const cellSize = MIN_DISTANCE / Math.sqrt(2);

        // Create grid
        for (let x = 0; x < BUBBLE_WIDTH; x += cellSize) {
            for (let y = 0; y < BUBBLE_HEIGHT; y += cellSize) {
                const jitterX = (Math.random() - 0.5) * cellSize;
                const jitterY = (Math.random() - 0.5) * cellSize;
                grid.push({
                    x: x + jitterX,
                    y: y + jitterY,
                });
            }
        }

        // Shuffle grid
        for (let i = grid.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [grid[i], grid[j]] = [grid[j], grid[i]];
        }

        function isInRoundedRectangle(px, py) {
            // Check corners except message corner
            const corners = [
                { x: CORNER_RADIUS, y: CORNER_RADIUS },
                { x: BUBBLE_WIDTH - CORNER_RADIUS, y: CORNER_RADIUS },
                { x: CORNER_RADIUS, y: BUBBLE_HEIGHT - CORNER_RADIUS },
                {
                    x: BUBBLE_WIDTH - CORNER_RADIUS,
                    y: BUBBLE_HEIGHT - CORNER_RADIUS,
                },
            ];

            if (sent) {
                corners.splice(3, 1);
            } else {
                corners.splice(2, 1);
            }

            for (const corner of corners) {
                const dx = px - corner.x;
                const dy = py - corner.y;
                if (
                    Math.sqrt(dx * dx + dy * dy) < CORNER_RADIUS &&
                    ((px < corner.x && py < corner.y) ||
                        (px > corner.x && py < corner.y) ||
                        (px < corner.x && py > corner.y) ||
                        (px > corner.x && py > corner.y))
                ) {
                    return false;
                }
            }

            return (
                px >= 0 && px <= BUBBLE_WIDTH && py >= 0 && py <= BUBBLE_HEIGHT
            );
        }

        function isValidPoint(px, py) {
            if (!isInRoundedRectangle(px, py)) return false;

            return !points.some((point) => {
                const dx = px - point.originalX;
                const dy = py - point.originalY;
                return Math.sqrt(dx * dx + dy * dy) < MIN_DISTANCE;
            });
        }

        // Add message corner point
        const cornerPoint = sent
            ? {
                  x: BUBBLE_WIDTH - CORNER_RADIUS / 2,
                  y: BUBBLE_HEIGHT - CORNER_RADIUS / 2,
              }
            : { x: CORNER_RADIUS / 2, y: BUBBLE_HEIGHT / 2 };

        points.push({
            x: cornerPoint.x,
            y: cornerPoint.y,
            originalX: cornerPoint.x,
            originalY: cornerPoint.y,
            targetX: cornerPoint.x,
            targetY: cornerPoint.y,
            vx: 0,
            vy: 0,
            size: DOT_SIZE,
        });

        // Add remaining points
        for (const point of grid) {
            if (points.length < NUM_POINTS && isValidPoint(point.x, point.y)) {
                points.push({
                    x: point.x,
                    y: point.y,
                    originalX: point.x,
                    originalY: point.y,
                    targetX: point.x,
                    targetY: point.y,
                    vx: (Math.random() - 0.5) * 2,
                    vy: (Math.random() - 0.5) * 2,
                    size: DOT_SIZE,
                });
            }
        }

        return points;
    }

    function clampToBubble(p) {
        if (p.x < 0) p.x = 0;
        if (p.x > BUBBLE_WIDTH) p.x = BUBBLE_WIDTH;
        if (p.y < 0) p.y = 0;
        if (p.y > BUBBLE_HEIGHT) p.y = BUBBLE_HEIGHT;
    }

    function resolveCollisions() {
        for (let step = 0; step < COLLISION_STEPS; step++) {
            for (let i = 0; i < points.length; i++) {
                for (let j = i + 1; j < points.length; j++) {
                    const p1 = points[i];
                    const p2 = points[j];
                    const dx = p2.x - p1.x;
                    const dy = p2.y - p1.y;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    const minDist = (p1.size + p2.size) / 2;

                    if (dist < minDist) {
                        const overlap = minDist - dist;
                        const ux = dx / dist;
                        const uy = dy / dist;

                        p1.x -= (ux * overlap) / 2;
                        p1.y -= (uy * overlap) / 2;
                        p2.x += (ux * overlap) / 2;
                        p2.y += (uy * overlap) / 2;
                    }
                }
            }
        }
    }

    function animate() {
        // Update target positions based on mouse proximity
        points = points.map((point) => {
            const dx = point.originalX - mouseX;
            const dy = point.originalY - mouseY;
            const distance = Math.sqrt(dx * dx + dy * dy);

            if (distance < WAVE_RADIUS) {
                point.targetX = mouseX;
                point.targetY = mouseY;
            } else {
                point.targetX = point.originalX;
                point.targetY = point.originalY;
            }

            return point;
        });

        // Apply spring forces towards target positions
        points = points.map((point) => {
            const dx = point.targetX - point.x;
            const dy = point.targetY - point.y;
            point.vx += SPRING_CONSTANT * dx;
            point.vy += SPRING_CONSTANT * dy;

            // Apply damping
            point.vx *= DAMPING;
            point.vy *= DAMPING;

            // Update positions
            point.x += point.vx;
            point.y += point.vy;

            // Clamp to bubble
            clampToBubble(point);

            return point;
        });

        // Resolve collisions
        resolveCollisions();

        // Find the closest point to the mouse and make it 2x the size
        let closestPoint = null;
        let closestDistance = Infinity;
        points.forEach((point) => {
            const dx = point.x - mouseX;
            const dy = point.y - mouseY;
            const distance = Math.sqrt(dx * dx + dy * dy);
            if (distance < closestDistance) {
                closestDistance = distance;
                closestPoint = point;
            }
            // Reset size to normal for all points
            point.size = DOT_SIZE;
        });

        if (closestPoint && closestDistance < WAVE_RADIUS) {
            targetPoint = closestPoint;
        }
        if (targetPoint) {
            var dx = targetPoint.originalX - targetPoint.x;
            var dy = targetPoint.originalY - targetPoint.y;
            if (Math.sqrt(dx * dx + dy * dy) > WAVE_RADIUS / 2) {
                targetPoint.size = DOT_SIZE;
                targetPoint.targetX = targetPoint.originalX;
                targetPoint.targetY = targetPoint.originalY;
                targetPoint = null;
            }
        }

        if (targetPoint) {
            targetPoint.size = DOT_SIZE * 2;
            targetPoint.x = mouseX;
            targetPoint.y = mouseY;
        }

        // Ensure Svelte reactivity
        points = points.map((p) => ({ ...p }));

        requestAnimationFrame(animate);
    }

    function handleMouseMove(event) {
        const rect = event.currentTarget.getBoundingClientRect();
        mouseX = event.clientX - rect.left;
        mouseY = event.clientY - rect.top;
    }

    onMount(() => {
        points = generatePoints();
        animate();
        return () => {
            isHovering = false;
        };
    });
</script>

<div
    class="relative {sent ? 'ml-auto' : 'mr-auto'}
           {sent ? 'rounded-br-sm' : 'rounded-bl-sm'}
           rounded-2xl overflow-hidden"
    style="width: {BUBBLE_WIDTH}px; height: {BUBBLE_HEIGHT}px;"
    on:mousemove={handleMouseMove}
    on:mouseenter={() => (isHovering = true)}
    on:mouseleave={() => (isHovering = false)}
>
    {#each points as point}
        <div
            class="absolute rounded-full"
            style="
                @apply bg-{sent ? 'black' : 'blue'};
                left: {point.x}px;
                top: {point.y}px;
                width: {point.size}px;
                height: {point.size}px;
                opacity: 0.2;
                transform: translate(-50%, -50%);
                transition: transform 75ms ease-out;
                will-change: transform;
            "
        />
    {/each}
</div>
