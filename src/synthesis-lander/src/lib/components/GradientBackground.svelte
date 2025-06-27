<script>
  import { onMount } from 'svelte';
  
  let mounted = $state(false);
  let time = $state(0);
  
  onMount(() => {
    mounted = true;
    const interval = setInterval(() => {
      time += 0.01;
    }, 50);
    
    return () => clearInterval(interval);
  });
  
  const gradientX = $derived(50 + Math.sin(time) * 20);
  const gradientY = $derived(50 + Math.cos(time * 0.7) * 20);
</script>

<div class="gradient-background">
  <div 
    class="gradient-orb gradient-orb-1"
    style="transform: translate({gradientX}%, {gradientY}%)"
  ></div>
  <div 
    class="gradient-orb gradient-orb-2"
    style="transform: translate({-gradientX}%, {-gradientY}%)"
  ></div>
  <div 
    class="gradient-orb gradient-orb-3"
    style="transform: translate({gradientY}%, {-gradientX}%)"
  ></div>
</div>

<style>
  .gradient-background {
    position: fixed;
    inset: 0;
    overflow: hidden;
    z-index: -1;
    background: #000;
  }
  
  .gradient-orb {
    position: absolute;
    border-radius: 50%;
    filter: blur(100px);
    opacity: 0.6;
    animation: float 20s infinite ease-in-out;
  }
  
  .gradient-orb-1 {
    width: 800px;
    height: 800px;
    background: radial-gradient(circle, #6366f1 0%, transparent 70%);
    top: -20%;
    left: -10%;
  }
  
  .gradient-orb-2 {
    width: 600px;
    height: 600px;
    background: radial-gradient(circle, #8b5cf6 0%, transparent 70%);
    bottom: -20%;
    right: -10%;
    animation-delay: -5s;
  }
  
  .gradient-orb-3 {
    width: 700px;
    height: 700px;
    background: radial-gradient(circle, #ec4899 0%, transparent 70%);
    top: 50%;
    left: 50%;
    transform-origin: center;
    animation-delay: -10s;
  }
  
  @keyframes float {
    0%, 100% {
      transform: translateY(0) scale(1);
    }
    50% {
      transform: translateY(-50px) scale(1.1);
    }
  }
</style>