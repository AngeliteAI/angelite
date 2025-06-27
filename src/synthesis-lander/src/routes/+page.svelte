<script>
  import GradientBackground from '$lib/components/GradientBackground.svelte';
  import EmailSubscribe from '$lib/components/EmailSubscribe.svelte';
  import { onMount } from 'svelte';
  
  let visible = $state(false);
  
  onMount(() => {
    setTimeout(() => {
      visible = true;
    }, 100);
  });
</script>

<GradientBackground />

<main class="landing-container">
  <div class="content" class:visible>
    <div class="hero-section">
      <div class="badge glass">
        <span class="badge-dot"></span>
        <span>Coming Soon</span>
      </div>
      
      <h1 class="hero-title">
        <span class="gradient-text">Synthesis</span>
        <br />
        <span class="subtitle">The Future of Bio-Industrial Gaming</span>
      </h1>
      
      <p class="hero-description">
        Join us as we forge the ultimate factory survival experience. Be the first to know when we launch and get exclusive early access to humanity's last hope.
      </p>
      
      <div class="email-section">
        {#if false}
        <EmailSubscribe />
        {/if}
      </div>
      
      <div class="features">
        <div class="feature glass">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h3>Lightning Fast</h3>
          <h4>Optimized Performance</h4>
          <p>Real-time automation with zero lag, even in massive bio-industrial complexes</p>
        </div>
        
        <div class="feature glass">
          <div class="feature-icon">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <path d="M12 2L2 7v10c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V7l-10-5z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h3>Secure by Design</h3>
          <h4>Protected Progress</h4>
          <p>Your colonies and blueprints saved with military-grade encryption</p>
        </div>
        
        <div class="feature glass">
          <div class="feature-icon">
            <span style="font-size: 24px;">🧬</span>
          </div>
          <h3>Bio-Mechanical Fusion</h3>
          <h4>Advanced Synthesis</h4>
          <p>Combine organic and industrial systems for unprecedented survival strategies</p>
        </div>
      </div>
    </div>
  </div>
</main>

<style>
  .landing-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
    position: relative;
    z-index: 1;
  }
  
  .content {
    max-width: 1200px;
    width: 100%;
    opacity: 0;
    transform: translateY(20px);
    transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
  }
  
  .content.visible {
    opacity: 1;
    transform: translateY(0);
  }
  
  .hero-section {
    text-align: center;
  }
  
  .badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 20px;
    border-radius: 9999px;
    font-size: 14px;
    font-weight: 500;
    margin-bottom: 2rem;
    letter-spacing: -0.01em;
  }
  
  .badge-dot {
    width: 8px;
    height: 8px;
    background: #10b981;
    border-radius: 50%;
    animation: pulse 2s infinite;
  }
  
  @keyframes pulse {
    0%, 100% {
      opacity: 1;
      transform: scale(1);
    }
    50% {
      opacity: 0.5;
      transform: scale(1.2);
    }
  }
  
  .hero-title {
    font-size: clamp(3rem, 8vw, 6rem);
    font-weight: 800;
    line-height: 1.1;
    margin-bottom: 1rem;
    letter-spacing: -0.04em;
  }
  
  .subtitle {
    font-size: clamp(1.5rem, 4vw, 2.5rem);
    color: rgba(255, 255, 255, 0.8);
    font-weight: 400;
  }
  
  .hero-description {
    font-size: clamp(1rem, 2vw, 1.25rem);
    color: rgba(255, 255, 255, 0.6);
    max-width: 600px;
    margin: 0 auto 3rem;
    line-height: 1.6;
  }
  
  .email-section {
    margin-bottom: 5rem;
  }
  
  .features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 2rem;
    max-width: 800px;
    margin: 0 auto;
  }
  
  .feature {
    padding: 2rem;
    border-radius: 16px;
    text-align: center;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  
  .feature:hover {
    transform: translateY(-4px);
    box-shadow: 
      0 20px 40px rgba(0, 0, 0, 0.3),
      0 0 40px rgba(99, 102, 241, 0.1),
      inset 0 1px rgba(255, 255, 255, 0.2);
  }
  
  .feature-icon {
    width: 48px;
    height: 48px;
    margin: 0 auto 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
    border-radius: 12px;
    color: #fff;
  }
  
  .feature h3 {
    font-size: 1.25rem;
    margin-bottom: 0.25rem;
    font-weight: 600;
  }
  
  .feature h4 {
    font-size: 1rem;
    margin-bottom: 0.75rem;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.8);
  }
  
  .feature p {
    color: rgba(255, 255, 255, 0.6);
    font-size: 0.875rem;
    line-height: 1.5;
  }
  
  @media (max-width: 768px) {
    .landing-container {
      padding: 1rem;
    }
    
    .hero-title {
      margin-bottom: 1.5rem;
    }
    
    .features {
      gap: 1rem;
    }
    
    .feature {
      padding: 1.5rem;
    }
  }
</style>
