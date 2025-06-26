<script>
    import { onMount } from "svelte";
    
    let {
        as = "div",
        class: classList = "",
        intensity = 1,
        ...attrs
    } = $props();
    
    let element;
    let time = 0;
    let animationFrame;
    
    onMount(() => {
        const animate = () => {
            time += 0.01;
            
            if (element) {
                // Animate iridescent colors
                const hue1 = (Math.sin(time) * 30 + 200) % 360;
                const hue2 = (Math.cos(time * 0.7) * 40 + 280) % 360;
                const hue3 = (Math.sin(time * 1.3) * 50 + 340) % 360;
                
                element.style.setProperty("--hue1", hue1);
                element.style.setProperty("--hue2", hue2);
                element.style.setProperty("--hue3", hue3);
                
                // Animate liquid flow
                const flowX = Math.sin(time * 0.5) * 20;
                const flowY = Math.cos(time * 0.3) * 15;
                element.style.setProperty("--flow-x", `${flowX}px`);
                element.style.setProperty("--flow-y", `${flowY}px`);
            }
            
            animationFrame = requestAnimationFrame(animate);
        };
        
        animate();
        
        return () => {
            if (animationFrame) {
                cancelAnimationFrame(animationFrame);
            }
        };
    });
</script>

<svelte:element
    this={as}
    class="liquid-glass {classList}"
    bind:this={element}
    style="--intensity: {intensity}"
    {...attrs}
>
    <div class="liquid-surface"></div>
    <div class="liquid-content">
        <slot />
    </div>
    <div class="liquid-shimmer"></div>
</svelte:element>

<style>
    :global(.liquid-glass) {
        position: relative;
        background: 
            linear-gradient(
                135deg,
                hsla(var(--hue1, 200), 70%, 60%, calc(0.03 * var(--intensity))) 0%,
                hsla(var(--hue2, 280), 60%, 50%, calc(0.02 * var(--intensity))) 50%,
                hsla(var(--hue3, 340), 80%, 65%, calc(0.03 * var(--intensity))) 100%
            );
        backdrop-filter: 
            blur(calc(20px * var(--intensity))) 
            saturate(calc(1.2 + 0.3 * var(--intensity)))
            brightness(calc(1 + 0.05 * var(--intensity)));
        border: 1px solid hsla(var(--hue1, 200), 50%, 80%, calc(0.2 * var(--intensity)));
        border-radius: 16px;
        overflow: hidden;
        transform-style: preserve-3d;
        box-shadow:
            0 20px 60px -10px hsla(var(--hue1, 200), 50%, 50%, calc(0.2 * var(--intensity))),
            0 0 0 1px hsla(var(--hue2, 280), 60%, 90%, calc(0.1 * var(--intensity))) inset,
            0 0 100px -30px hsla(var(--hue3, 340), 70%, 60%, calc(0.15 * var(--intensity)));
        transition: all 0.8s cubic-bezier(0.23, 1, 0.32, 1);
    }
    
    :global(.liquid-surface) {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: 
            radial-gradient(
                ellipse at calc(50% + var(--flow-x, 0px)) calc(50% + var(--flow-y, 0px)),
                hsla(var(--hue1, 200), 80%, 70%, calc(0.1 * var(--intensity))) 0%,
                transparent 60%
            ),
            radial-gradient(
                ellipse at calc(30% - var(--flow-x, 0px)) calc(70% - var(--flow-y, 0px)),
                hsla(var(--hue2, 280), 70%, 65%, calc(0.08 * var(--intensity))) 0%,
                transparent 50%
            );
        pointer-events: none;
        z-index: 1;
        mix-blend-mode: screen;
    }
    
    :global(.liquid-content) {
        position: relative;
        z-index: 2;
    }
    
    :global(.liquid-shimmer) {
        position: absolute;
        top: -100%;
        left: -100%;
        right: -100%;
        bottom: -100%;
        background: 
            conic-gradient(
                from 0deg at 50% 50%,
                hsla(var(--hue1, 200), 100%, 80%, 0),
                hsla(var(--hue2, 280), 100%, 75%, calc(0.2 * var(--intensity))),
                hsla(var(--hue3, 340), 100%, 85%, 0),
                hsla(var(--hue1, 200), 100%, 80%, calc(0.15 * var(--intensity))),
                hsla(var(--hue1, 200), 100%, 80%, 0)
            );
        animation: shimmerRotate 20s linear infinite;
        pointer-events: none;
        z-index: 3;
        opacity: calc(0.7 * var(--intensity));
        mix-blend-mode: overlay;
    }
    
    @keyframes shimmerRotate {
        0% {
            transform: rotate(0deg) scale(1.5);
        }
        100% {
            transform: rotate(360deg) scale(1.5);
        }
    }
    
    :global(.liquid-glass:hover) {
        transform: translateY(-4px) rotateX(2deg);
        box-shadow:
            0 30px 80px -15px hsla(var(--hue1, 200), 60%, 50%, calc(0.3 * var(--intensity))),
            0 0 0 1px hsla(var(--hue2, 280), 70%, 85%, calc(0.2 * var(--intensity))) inset,
            0 0 150px -30px hsla(var(--hue3, 340), 80%, 65%, calc(0.25 * var(--intensity)));
    }
</style>