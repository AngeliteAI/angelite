<script>
    import { onMount } from "svelte";

    /**
     * GradientBackground component
     * Creates an animated background gradient effect that fills the viewport
     *
     * Props:
     * - fixed: Whether the background should be fixed (default: true)
     * - intensity: Opacity of the gradients (0-1, default: 0.5)
     */
    let { fixed = true, intensity = 0.5 } = $props();

    const position = fixed ? "fixed" : "absolute";
    const opacityValue = Math.max(0, Math.min(1, intensity));

    // Parallax effect state
    let offsetX = 0;
    let offsetY = 0;

    onMount(() => {
        // Add subtle animation to gradient position
        let lastScrollY = window.scrollY;

        const handleScroll = () => {
            const scrollDelta = window.scrollY - lastScrollY;
            lastScrollY = window.scrollY;

            // Subtle parallax effect on scroll
            offsetY += scrollDelta * 0.05;

            document.documentElement.style.setProperty(
                "--bg-offset-y",
                `${offsetY * 0.02}px`,
            );
        };

        // Add subtle mouse movement effect
        const handleMouseMove = (e) => {
            const mouseX = e.clientX / window.innerWidth;
            const mouseY = e.clientY / window.innerHeight;

            // Subtle movement based on mouse position
            document.documentElement.style.setProperty(
                "--bg-offset-x",
                `${mouseX * 20 - 10}px`,
            );
            document.documentElement.style.setProperty(
                "--bg-offset-y",
                `${mouseY * 20 - 10}px`,
            );
        };

        window.addEventListener("scroll", handleScroll);
        window.addEventListener("mousemove", handleMouseMove);

        return () => {
            window.removeEventListener("scroll", handleScroll);
            window.removeEventListener("mousemove", handleMouseMove);
        };
    });
</script>

<div
    class="gradient-bg"
    style="position: {position}; --opacity: {opacityValue};"
>
    <div class="noise-overlay"></div>
    <div class="gradient-orb gradient-orb-1"></div>
    <div class="gradient-orb gradient-orb-2"></div>
    <div class="gradient-orb gradient-orb-3"></div>
</div>

<style>
    .gradient-bg {
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background:
            radial-gradient(
                circle at calc(30% + var(--bg-offset-x, 0))
                    calc(20% + var(--bg-offset-y, 0)),
                rgba(99, 102, 241, var(--opacity)) 0%,
                transparent 50%
            ),
            radial-gradient(
                circle at calc(85% + var(--bg-offset-x, 0))
                    calc(30% + var(--bg-offset-y, 0)),
                rgba(236, 72, 153, calc(var(--opacity) * 0.7)) 0%,
                transparent 45%
            ),
            radial-gradient(
                circle at calc(15% + var(--bg-offset-x, 0))
                    calc(85% + var(--bg-offset-y, 0)),
                rgba(34, 211, 238, calc(var(--opacity) * 0.8)) 0%,
                transparent 45%
            ),
            radial-gradient(
                circle at calc(70% + var(--bg-offset-x, 0))
                    calc(90% + var(--bg-offset-y, 0)),
                rgba(74, 47, 189, calc(var(--opacity) * 0.6)) 0%,
                transparent 40%
            );
        background-color: #0f1118;
        z-index: -2;
        pointer-events: none;
        overflow: hidden;
    }

    /* Texture overlay */
    .noise-overlay {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E");
        opacity: 0.03;
        z-index: 1;
        mix-blend-mode: overlay;
    }

    /* Floating orbs for depth */
    .gradient-orb {
        position: absolute;
        border-radius: 50%;
        filter: blur(50px);
        opacity: 0.15;
        z-index: -1;
        animation: float 20s infinite alternate ease-in-out;
    }

    .gradient-orb-1 {
        width: 400px;
        height: 400px;
        background: radial-gradient(
            circle,
            rgba(99, 102, 241, 0.8) 0%,
            rgba(99, 102, 241, 0) 70%
        );
        top: 10%;
        left: 20%;
        animation-delay: 0s;
    }

    .gradient-orb-2 {
        width: 300px;
        height: 300px;
        background: radial-gradient(
            circle,
            rgba(236, 72, 153, 0.8) 0%,
            rgba(236, 72, 153, 0) 70%
        );
        bottom: 20%;
        right: 15%;
        animation-delay: -5s;
    }

    .gradient-orb-3 {
        width: 200px;
        height: 200px;
        background: radial-gradient(
            circle,
            rgba(34, 211, 238, 0.8) 0%,
            rgba(34, 211, 238, 0) 70%
        );
        bottom: 30%;
        left: 25%;
        animation-delay: -10s;
    }

    @keyframes float {
        0% {
            transform: translate(0, 0);
        }
        50% {
            transform: translate(30px, 20px);
        }
        100% {
            transform: translate(-20px, 10px);
        }
    }
</style>
