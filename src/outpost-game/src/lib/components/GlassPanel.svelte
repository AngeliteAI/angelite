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
    let distortionX = 0;
    let distortionY = 0;
    let lastTime = Date.now();

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
        
        // Add liquid distortion based on movement speed
        const currentTime = Date.now();
        const deltaTime = currentTime - lastTime;
        lastTime = currentTime;
        
        const speed = Math.sqrt(
            Math.pow(mouseX - distortionX, 2) + 
            Math.pow(mouseY - distortionY, 2)
        ) / deltaTime;
        
        distortionX = mouseX;
        distortionY = mouseY;
        
        element.style.setProperty("--distortion", Math.min(speed * 50, 20));
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
    <div class="glass-inner w-full h-full">
        <slot />
    </div>
    {#if interactive}
        <div class="glass-highlight"></div>
        <div class="glass-ripple"></div>
    {/if}
    <!-- SVG filters for liquid effects -->
    <svg style="position: absolute; width: 0; height: 0;">
        <defs>
            <filter id="liquid-distortion">
                <feTurbulence 
                    type="fractalNoise" 
                    baseFrequency="0.015" 
                    numOctaves="2" 
                    result="turbulence" 
                    seed="2"
                />
                <feDisplacementMap 
                    in="SourceGraphic" 
                    in2="turbulence" 
                    scale="{isHovered ? 'var(--distortion, 0)' : '0'}" 
                    xChannelSelector="R" 
                    yChannelSelector="G"
                />
                <feGaussianBlur stdDeviation="0.5" />
            </filter>
            <filter id="chromatic-aberration">
                <feOffset in="SourceGraphic" dx="-1" dy="0" result="r" />
                <feOffset in="SourceGraphic" dx="1" dy="0" result="b" />
                <feBlend mode="screen" in="r" in2="SourceGraphic" result="rb" />
                <feBlend mode="screen" in="rb" in2="b" />
            </filter>
        </defs>
    </svg>
</svelte:element>

<style>
    :global(.glass) {
        position: relative;
        background: 
            linear-gradient(
                105deg,
                rgba(255, 255, 255, 0.04) 0%,
                rgba(255, 255, 255, 0.02) 40%,
                rgba(255, 255, 255, 0.06) 100%
            ),
            rgba(255, 255, 255, 0.01);
        backdrop-filter: blur(12px) saturate(1.5);
        border: 1px solid rgba(255, 255, 255, 0.1);
        box-shadow:
            0 8px 32px -8px rgba(0, 0, 0, 0.3),
            0 0 0 1px rgba(255, 255, 255, 0.1) inset,
            0 0 80px -20px rgba(120, 119, 198, 0.15);
        border-radius: 12px;
        transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
        overflow: hidden;
        transform-style: preserve-3d;
        --distortion: 0;
    }

    :global(.glass.interactive:hover) {
        transform: translateY(-2px) translateZ(0);
        border: 1px solid rgba(255, 255, 255, 0.15);
        box-shadow:
            0 12px 48px -4px rgba(0, 0, 0, 0.4),
            0 0 0 1px rgba(255, 255, 255, 0.2) inset,
            0 0 120px -20px rgba(120, 119, 198, 0.25);
        background: 
            linear-gradient(
                105deg,
                rgba(255, 255, 255, 0.08) 0%,
                rgba(255, 255, 255, 0.03) 40%,
                rgba(255, 255, 255, 0.1) 100%
            ),
            rgba(255, 255, 255, 0.02);
        filter: url(#liquid-distortion);
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
        background: 
            radial-gradient(
                circle 120px at var(--x, 50%) var(--y, 50%),
                rgba(255, 255, 255, 0.15),
                rgba(120, 119, 198, 0.1) 30%,
                transparent 70%
            ),
            radial-gradient(
                circle 200px at var(--x, 50%) var(--y, 50%),
                rgba(120, 119, 198, 0.05),
                transparent 50%
            );
        opacity: 0;
        transition: opacity 0.5s cubic-bezier(0.16, 1, 0.3, 1);
        mix-blend-mode: screen;
    }

    :global(.glass.hovered .glass-highlight) {
        opacity: 1;
    }
    
    /* Ripple effect */
    :global(.glass-ripple) {
        position: absolute;
        top: var(--y, 50%);
        left: var(--x, 50%);
        width: 100px;
        height: 100px;
        border-radius: 50%;
        background: radial-gradient(
            circle,
            rgba(255, 255, 255, 0.2) 0%,
            rgba(255, 255, 255, 0.1) 40%,
            transparent 70%
        );
        transform: translate(-50%, -50%) scale(0);
        opacity: 0;
        pointer-events: none;
        z-index: 2;
    }
    
    :global(.glass.interactive:active .glass-ripple) {
        animation: ripple 0.8s cubic-bezier(0.16, 1, 0.3, 1);
    }
    
    @keyframes ripple {
        0% {
            transform: translate(-50%, -50%) scale(0);
            opacity: 1;
        }
        100% {
            transform: translate(-50%, -50%) scale(4);
            opacity: 0;
        }
    }
    
    /* Iridescent shimmer */
    :global(.glass::before) {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: linear-gradient(
            45deg,
            transparent 30%,
            rgba(255, 255, 255, 0.1) 50%,
            transparent 70%
        );
        transform: rotate(45deg) translateY(200%);
        transition: transform 1.5s cubic-bezier(0.16, 1, 0.3, 1);
        pointer-events: none;
        z-index: 3;
    }
    
    :global(.glass.hovered::before) {
        transform: rotate(45deg) translateY(-200%);
    }
</style>
