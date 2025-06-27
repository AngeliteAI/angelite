<script>
    import { onMount } from 'svelte';
    import { fade, fly } from 'svelte/transition';
    
    let videoLoaded = $state(false);
    let mouseX = $state(0);
    let mouseY = $state(0);
    
    function handleMouseMove(e) {
        const rect = e.currentTarget.getBoundingClientRect();
        mouseX = (e.clientX - rect.left) / rect.width;
        mouseY = (e.clientY - rect.top) / rect.height;
    }
    
    onMount(() => {
        videoLoaded = true;
    });
</script>

<section class="hero-section" on:mousemove={handleMouseMove}>
    <div class="hero-background">
        <div 
            class="parallax-layer" 
            style="transform: translate({mouseX * 20}px, {mouseY * 20}px)"
        ></div>
        <div 
            class="parallax-layer-2" 
            style="transform: translate({mouseX * -10}px, {mouseY * -10}px)"
        ></div>
    </div>
    
    <div class="hero-content">
        <div class="hero-badge" in:fly={{ y: -20, duration: 800, delay: 200 }}>
            <span class="badge-icon">🚀</span>
            <span>Now on Kickstarter</span>
        </div>
        
        <h1 class="hero-title" in:fade={{ duration: 1000, delay: 400 }}>
            Build Your Legacy
            <span class="title-gradient">Among the Stars</span>
        </h1>
        
        <p class="hero-subtitle" in:fade={{ duration: 1000, delay: 600 }}>
            Forge alliances, construct outposts, and shape the destiny of humanity 
            in the most ambitious space exploration game ever created.
        </p>
        
        <div class="hero-cta-group" in:fly={{ y: 20, duration: 800, delay: 800 }}>
            <button class="btn-primary btn-large">
                <span>Back This Project</span>
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                    <path d="M7 10H13M13 10L10 7M13 10L10 13" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
            <button class="btn-secondary">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                    <path d="M10 2L12.09 7.26L18 8.27L14 12.14L14.81 18L10 15.77L5.19 18L6 12.14L2 8.27L7.91 7.26L10 2Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span>Watch Trailer</span>
            </button>
        </div>
        
        <div class="trust-indicators" in:fade={{ duration: 1000, delay: 1000 }}>
            <div class="trust-item">
                <span class="trust-icon">✓</span>
                <span>Fully Funded in 24 Hours</span>
            </div>
            <div class="trust-item">
                <span class="trust-icon">✓</span>
                <span>5,000+ Backers</span>
            </div>
            <div class="trust-item">
                <span class="trust-icon">✓</span>
                <span>Stretch Goals Unlocked</span>
            </div>
        </div>
    </div>
    
    <div class="hero-visual" in:fade={{ duration: 1200, delay: 200 }}>
        {#if videoLoaded}
            <div class="video-container">
                <video 
                    autoplay 
                    muted 
                    loop 
                    playsinline
                    poster="/assets/hero-poster.jpg"
                >
                    <source src="/assets/hero-video.mp4" type="video/mp4">
                </video>
                <div class="video-overlay"></div>
            </div>
        {/if}
        <img 
            src="/assets/hero-ship.png" 
            alt="Outpost Spaceship" 
            class="hero-ship animate-float"
            style="transform: translate({mouseX * 30}px, {mouseY * 30}px)"
        />
    </div>
</section>

<style>
    .hero-section {
        position: relative;
        min-height: 100vh;
        display: flex;
        align-items: center;
        padding: 2rem;
        overflow: hidden;
    }
    
    .hero-background {
        position: absolute;
        inset: 0;
        z-index: 0;
    }
    
    .parallax-layer {
        position: absolute;
        width: 120%;
        height: 120%;
        top: -10%;
        left: -10%;
        background: radial-gradient(circle at 30% 50%, rgba(99, 102, 241, 0.3) 0%, transparent 50%);
        filter: blur(100px);
        transition: transform 0.3s ease-out;
    }
    
    .parallax-layer-2 {
        position: absolute;
        width: 120%;
        height: 120%;
        top: -10%;
        left: -10%;
        background: radial-gradient(circle at 70% 50%, rgba(236, 72, 153, 0.2) 0%, transparent 50%);
        filter: blur(80px);
        transition: transform 0.3s ease-out;
    }
    
    .hero-content {
        position: relative;
        z-index: 2;
        max-width: 800px;
        margin: 0 auto;
        text-align: center;
        padding: 4rem 0;
    }
    
    .hero-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        background: rgba(99, 102, 241, 0.1);
        border: 1px solid rgba(99, 102, 241, 0.3);
        padding: 0.75rem 1.5rem;
        border-radius: 999px;
        font-size: 0.875rem;
        font-weight: 600;
        color: #a5b4fc;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        margin-bottom: 2rem;
    }
    
    .badge-icon {
        font-size: 1.25rem;
        animation: bounce 2s ease-in-out infinite;
    }
    
    @keyframes bounce {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(-4px); }
    }
    
    .hero-title {
        font-size: clamp(3rem, 7vw, 6rem);
        font-weight: 800;
        line-height: 1.05;
        letter-spacing: -0.04em;
        margin-bottom: 1.5rem;
        color: white;
    }
    
    .title-gradient {
        display: block;
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #ec4899 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        animation: gradient-shift 5s ease-in-out infinite;
    }
    
    @keyframes gradient-shift {
        0%, 100% { background-position: 0% 50%; }
        50% { background-position: 100% 50%; }
    }
    
    .hero-subtitle {
        font-size: clamp(1.25rem, 2vw, 1.75rem);
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.8);
        margin-bottom: 3rem;
        max-width: 600px;
        margin-left: auto;
        margin-right: auto;
        font-weight: 400;
    }
    
    .hero-cta-group {
        display: flex;
        gap: 1.5rem;
        justify-content: center;
        flex-wrap: wrap;
        margin-bottom: 3rem;
    }
    
    .btn-primary.btn-large {
        padding: 1.25rem 3rem;
        font-size: 1.25rem;
        gap: 1rem;
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }
    
    .btn-primary.btn-large:hover {
        transform: translateY(-3px);
        box-shadow: 0 12px 30px rgba(99, 102, 241, 0.5);
    }
    
    .btn-secondary {
        background: rgba(255, 255, 255, 0.05);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        color: white;
        padding: 1.25rem 3rem;
        border-radius: 999px;
        font-weight: 600;
        font-size: 1.125rem;
        letter-spacing: -0.02em;
        transition: all 0.3s ease;
        display: inline-flex;
        align-items: center;
        gap: 0.75rem;
        cursor: pointer;
    }
    
    .btn-secondary:hover {
        background: rgba(255, 255, 255, 0.1);
        transform: translateY(-2px);
    }
    
    .trust-indicators {
        display: flex;
        gap: 2rem;
        justify-content: center;
        flex-wrap: wrap;
    }
    
    .trust-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.7);
    }
    
    .trust-icon {
        color: #10b981;
        font-weight: 600;
    }
    
    .hero-visual {
        position: absolute;
        inset: 0;
        z-index: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        pointer-events: none;
    }
    
    .video-container {
        position: absolute;
        inset: 0;
        overflow: hidden;
    }
    
    .video-container video {
        width: 100%;
        height: 100%;
        object-fit: cover;
        opacity: 0.3;
    }
    
    .video-overlay {
        position: absolute;
        inset: 0;
        background: radial-gradient(ellipse at center, transparent 0%, rgba(0, 0, 0, 0.8) 100%);
    }
    
    .hero-ship {
        position: relative;
        max-width: 600px;
        width: 100%;
        height: auto;
        opacity: 0.8;
        filter: drop-shadow(0 20px 40px rgba(0, 0, 0, 0.5));
        transition: transform 0.3s ease-out;
    }
    
    @media (max-width: 768px) {
        .hero-section {
            padding: 1rem;
        }
        
        .hero-content {
            padding: 2rem 0;
        }
        
        .hero-cta-group {
            flex-direction: column;
            width: 100%;
        }
        
        .btn-primary.btn-large,
        .btn-secondary {
            width: 100%;
            justify-content: center;
        }
        
        .trust-indicators {
            flex-direction: column;
            align-items: center;
            gap: 1rem;
        }
    }
</style>