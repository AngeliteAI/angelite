<script>
    import { onMount } from "svelte";

    /**
     * GlassPanel component provides an Apple-style frosted glass effect
     *
     * Props:
     * - as: HTML element to render (default: 'div')
     * - class: Additional CSS classes
     * - interactive: Enable hover effects (default: true)
     */
    let {
        as = "div",
        class: classList = "",
        interactive = true,
        ...attrs
    } = $props();

    let isHovered = false;
    let mouseX = 0;
    let mouseY = 0;
    let elementRect = { top: 0, left: 0, width: 0, height: 0 };
    let element;

    function handleMouseMove(event) {
        if (!interactive) return;

        isHovered = true;
        mouseX = event.clientX;
        mouseY = event.clientY;

        // Calculate relative position for highlight effect
        const relativeX = mouseX - elementRect.left;
        const relativeY = mouseY - elementRect.top;

        element.style.setProperty("--x", `${relativeX}px`);
        element.style.setProperty("--y", `${relativeY}px`);
    }

    function handleMouseEnter() {
        if (!interactive) return;
        isHovered = true;
    }

    function handleMouseLeave() {
        if (!interactive) return;
        isHovered = false;
    }

    onMount(() => {
        if (interactive && element) {
            elementRect = element.getBoundingClientRect();
            window.addEventListener("resize", () => {
                elementRect = element.getBoundingClientRect();
            });
        }
    });
</script>

<svelte:element
    this={as}
    class="glass {classList} {isHovered ? 'hovered' : ''}"
    class:interactive
    bind:this={element}
    on:mouseenter={handleMouseEnter}
    on:mouseleave={handleMouseLeave}
    on:mousemove={handleMouseMove}
    {...attrs}
>
    <div class="glass-inner">
        <slot />
    </div>
    {#if interactive}
        <div class="glass-highlight"></div>
    {/if}
</svelte:element>

<style>
    :global(.glass) {
        position: relative;
        background: rgba(255, 255, 255, 0.03);
        backdrop-filter: blur(12px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        box-shadow:
            0 4px 24px -1px rgba(0, 0, 0, 0.2),
            0 0 0 1px rgba(255, 255, 255, 0.1) inset;
        border-radius: 6px;
        transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        overflow: hidden;
    }

    :global(.glass.interactive:hover) {
        transform: translateY(-1px);
        border: 1px solid rgba(255, 255, 255, 0.2);
        box-shadow:
            0 8px 32px -2px rgba(0, 0, 0, 0.25),
            0 0 0 1px rgba(255, 255, 255, 0.15) inset;
    }

    :global(.glass-inner) {
        position: relative;
        z-index: 2;
        height: 100%;
    }

    :global(.glass-highlight) {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        pointer-events: none;
        z-index: 1;
        background: radial-gradient(
            circle 100px at var(--x, 50%) var(--y, 50%),
            rgba(255, 255, 255, 0.08),
            transparent 40%
        );
        opacity: 0;
        transition: opacity 0.3s ease;
    }

    :global(.glass.hovered .glass-highlight) {
        opacity: 1;
    }
</style>
