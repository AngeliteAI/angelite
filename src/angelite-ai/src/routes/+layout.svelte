<script>
	import '../app.css';
	import { page } from '$app/stores';
	import { fade, fly } from 'svelte/transition';
	import { onMount } from 'svelte';
	
	let { children } = $props();
	let isMenuOpen = false;
	let scrollY = 0;
	let isPageLoaded = false;
	
	// Determine active route
	let currentPath = $derived( $page => {
		return $page.url.pathname;
	});
	
	function toggleMenu() {
		isMenuOpen = !isMenuOpen;
	}
	
	onMount(() => {
		setTimeout(() => {
			isPageLoaded = true;
		}, 100);
	});
</script>

<svelte:window bind:scrollY />

<!-- Premium 3D-style background with enhanced gradients -->
<div class="fixed inset-0 -z-10 bg-[#080a1f] overflow-hidden">
  <!-- Modern dynamic gradient background -->
  <div class="absolute inset-0 bg-gradient-to-b from-indigo-900/20 via-transparent to-black/30"></div>
  
  <!-- Premium 3D gradient blobs -->
  <div class="premium-blob premium-blob-blue"></div>
  <div class="premium-blob premium-blob-purple"></div>
  <div class="premium-blob premium-blob-teal"></div>
  
  <!-- Advanced dot matrix pattern -->
  <div class="premium-dots"></div>
  
  <!-- Light noise texture overlay -->
  <div class="noise-overlay"></div>
</div>

<!-- Premium navigation -->
<nav class="sticky top-0 z-50 backdrop-blur-md bg-[#080a1f]/70 border-b border-white/10">
  <div class="container mx-auto px-6 py-4 max-w-7xl flex items-center justify-between">
    <a href="/" class="flex items-center space-x-2 text-white">
      <div class="w-9 h-9 bg-gradient-to-br from-indigo-600 to-indigo-400 rounded-lg flex items-center justify-center shadow-lg">
        <span class="text-white font-bold text-xl">A</span>
      </div>
      <span class="font-semibold text-lg">Angelite</span>
    </a>
    
    <!-- Desktop Navigation -->
    <div class="hidden md:flex items-center space-x-8">
      <a href="/" class="text-white/70 hover:text-white transition-all duration-300 relative" class:after:absolute={currentPath === '/'} class:after:bottom-0={currentPath === '/'} class:after:left-0={currentPath === '/'} class:after:h-0.5={currentPath === '/'} class:after:w-full={currentPath === '/'} class:after:bg-indigo-500={currentPath === '/'} class:text-white={currentPath === '/'}>Home</a>
      <a href="/blog" class="text-white/70 hover:text-white transition-all duration-300 relative" class:after:absolute={currentPath === '/blog'} class:after:bottom-0={currentPath === '/blog'} class:after:left-0={currentPath === '/blog'} class:after:h-0.5={currentPath === '/blog'} class:after:w-full={currentPath === '/blog'} class:after:bg-indigo-500={currentPath === '/blog'} class:text-white={currentPath === '/blog'}>Blog</a>
      <a href="/products" class="text-white/70 hover:text-white transition-all duration-300">Products</a>
      <a href="/about" class="text-white/70 hover:text-white transition-all duration-300">About</a>
    </div>
    
    <div class="hidden md:block">
      <a href="/contact" class="px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-lg transition-all duration-300">Contact</a>
    </div>
    
    <!-- Mobile menu button -->
    <button class="md:hidden text-white" on:click={toggleMenu}>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
      </svg>
    </button>
  </div>
  
  <!-- Mobile Navigation Menu -->
  {#if isMenuOpen}
    <div class="md:hidden bg-[#080a1f]/95 backdrop-blur-md absolute w-full border-b border-white/10 shadow-lg"
         transition:fly={{ y: -20, duration: 300 }}>
      <div class="container mx-auto px-6 py-4">
        <div class="flex flex-col space-y-4">
          <a href="/" class="text-white/70 hover:text-white py-2 transition-all duration-300" class:text-white={currentPath === '/'}>Home</a>
          <a href="/blog" class="text-white/70 hover:text-white py-2 transition-all duration-300" class:text-white={currentPath === '/blog'}>Blog</a>
          <a href="/products" class="text-white/70 hover:text-white py-2 transition-all duration-300">Products</a>
          <a href="/about" class="text-white/70 hover:text-white py-2 transition-all duration-300">About</a>
          <a href="/contact" class="text-white/70 hover:text-white py-2 transition-all duration-300">Contact</a>
        </div>
      </div>
    </div>
  {/if}
</nav>

<!-- Main content -->
<div class="min-h-screen font-sans antialiased text-slate-50 relative selection:bg-indigo-500/30 selection:text-white">
  {@render children()}
</div>

<!-- Premium Footer -->
<footer class="relative bg-[#050714]/80 border-t border-white/5 backdrop-blur-sm">
  <div class="container mx-auto px-6 py-16 max-w-7xl">
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12">
      <!-- Brand column -->
      <div class="md:col-span-2 lg:col-span-1">
        <div class="flex items-center space-x-2 text-white mb-6">
          <div class="w-10 h-10 bg-gradient-to-br from-indigo-600 to-indigo-400 rounded-lg flex items-center justify-center shadow-lg">
            <span class="text-white font-bold text-xl">A</span>
          </div>
          <span class="font-semibold text-xl">Angelite</span>
        </div>
        <p class="text-indigo-100/60 mb-8 max-w-xs">
          Pioneering the future of spatial computing through advanced voxel rendering and immersive technologies.
        </p>
        <div class="flex space-x-4">
          <a href="#" class="w-9 h-9 rounded-full bg-white/5 hover:bg-white/10 flex items-center justify-center transition-all duration-300 text-white">
            <svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"></path></svg>
          </a>
          <a href="#" class="w-9 h-9 rounded-full bg-white/5 hover:bg-white/10 flex items-center justify-center transition-all duration-300 text-white">
            <svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"></path></svg>
          </a>
          <a href="#" class="w-9 h-9 rounded-full bg-white/5 hover:bg-white/10 flex items-center justify-center transition-all duration-300 text-white">
            <svg class="w-4 h-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M19 0h-14c-2.761 0-5 2.239-5 5v14c0 2.761 2.239 5 5 5h14c2.762 0 5-2.239 5-5v-14c0-2.761-2.238-5-5-5zm-11 19h-3v-11h3v11zm-1.5-12.268c-.966 0-1.75-.79-1.75-1.764s.784-1.764 1.75-1.764 1.75.79 1.75 1.764-.783 1.764-1.75 1.764zm13.5 12.268h-3v-5.604c0-3.368-4-3.113-4 0v5.604h-3v-11h3v1.765c1.396-2.586 7-2.777 7 2.476v6.759z"></path></svg>
          </a>
        </div>
      </div>
      
      <!-- Quick links -->
      <div>
        <h4 class="text-white font-semibold text-lg mb-6">Quick Links</h4>
        <ul class="space-y-4">
          <li><a href="/" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Home</a></li>
          <li><a href="/blog" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Blog</a></li>
          <li><a href="/products" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Products</a></li>
          <li><a href="/about" class="text-indigo-100/70 hover:text-white transition-colors duration-300">About Us</a></li>
          <li><a href="/contact" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Contact</a></li>
        </ul>
      </div>
      
      <!-- Resources -->
      <div>
        <h4 class="text-white font-semibold text-lg mb-6">Resources</h4>
        <ul class="space-y-4">
          <li><a href="#" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Documentation</a></li>
          <li><a href="#" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Developer API</a></li>
          <li><a href="#" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Community Forum</a></li>
          <li><a href="#" class="text-indigo-100/70 hover:text-white transition-colors duration-300">Resource Hub</a></li>
        </ul>
      </div>
      
      <!-- Contact -->
      <div>
        <h4 class="text-white font-semibold text-lg mb-6">Contact</h4>
        <ul class="space-y-4">
          <li class="flex items-start">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-indigo-400 mt-0.5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            <span class="text-indigo-100/70">contact@angelite.ai</span>
          </li>
          <li class="flex items-start">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-indigo-400 mt-0.5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <span class="text-indigo-100/70">San Francisco, CA</span>
          </li>
        </ul>
      </div>
    </div>
    
    <div class="mt-12 pt-8 border-t border-white/5 flex flex-col md:flex-row justify-between items-center">
      <p class="text-indigo-100/50 text-sm mb-4 md:mb-0">
        © 2025 Angelite AI. All rights reserved.
      </p>
      <div class="flex space-x-6 text-sm">
        <a href="#" class="text-indigo-100/50 hover:text-white transition-colors duration-300">Privacy Policy</a>
        <a href="#" class="text-indigo-100/50 hover:text-white transition-colors duration-300">Terms of Service</a>
      </div>
    </div>
  </div>
</footer>

<style>
  /* Premium animation utilities */
  .animate-pulse-slow {
    animation: pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }
  
  @keyframes pulse {
    0%, 100% {
      opacity: 0.3;
    }
    50% {
      opacity: 0.1;
    }
  }
  
  /* Premium dot pattern */
  .premium-dots {
    position: absolute;
    inset: 0;
    background-image: 
      radial-gradient(rgba(99, 102, 241, 0.15) 1px, transparent 1px),
      radial-gradient(rgba(139, 92, 246, 0.15) 1px, transparent 1px);
    background-size: 40px 40px, 30px 30px;
    background-position: 0 0, 20px 20px;
    opacity: 0.2;
    pointer-events: none;
    animation: premium-drift 60s linear infinite;
  }
  
  @keyframes premium-drift {
    0% {
      background-position: 0 0, 20px 20px;
    }
    100% {
      background-position: 40px 40px, 60px 60px;
    }
  }
  
  /* Light noise texture overlay */
  .noise-overlay {
    position: absolute;
    inset: 0;
    opacity: 0.03;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E");
    pointer-events: none;
  }
  
  /* Premium 3D blob properties */
  .premium-blob {
    position: absolute;
    border-radius: 50%;
    filter: blur(80px);
    opacity: 0.08;
    transform-origin: center;
    animation: premium-blob-pulse 25s ease-in-out infinite alternate;
    mix-blend-mode: screen;
  }
  
  .premium-blob-blue {
    width: 50vw;
    height: 50vw;
    background: radial-gradient(circle, rgba(79, 70, 229, 1) 0%, rgba(99, 102, 241, 0.3) 70%);
    top: -15%;
    right: -5%;
    animation-delay: 0s;
  }
  
  .premium-blob-purple {
    width: 40vw;
    height: 40vw;
    background: radial-gradient(circle, rgba(139, 92, 246, 1) 0%, rgba(167, 139, 250, 0.3) 70%);
    bottom: 10%;
    left: -15%;
    animation-delay: -5s;
  }
  
  .premium-blob-teal {
    width: 45vw;
    height: 45vw;
    background: radial-gradient(circle, rgba(20, 184, 166, 1) 0%, rgba(45, 212, 191, 0.3) 70%);
    top: 40%;
    left: 20%;
    animation-delay: -12s;
  }
  
  @keyframes premium-blob-pulse {
    0% {
      transform: scale(1) translate(0, 0) rotate(0deg);
    }
    33% {
      transform: scale(1.05) translate(1%, 1%) rotate(5deg);
    }
    66% {
      transform: scale(0.95) translate(-1%, -0.5%) rotate(-5deg);
    }
    100% {
      transform: scale(1.02) translate(0.5%, -1%) rotate(0deg);
    }
  }
  
  /* Text effect and animations shared across pages */
  .glowing-text {
    text-shadow: 0 0 20px rgba(99, 102, 241, 0.2);
  }
  
  .premium-card {
    transition: all 0.3s ease;
  }
  
  .premium-glow {
    box-shadow: 0 0 30px rgba(99, 102, 241, 0.2);
  }
  
  /* Input styling consistency */
  input::placeholder {
    color: transparent;
  }
  
  input:focus + label, 
  input:not(:placeholder-shown) + label {
    top: -0.5rem !important;
    font-size: 0.75rem !important;
    color: rgba(167, 139, 250, 1) !important;
  }
  
  /* Line clamp utilities */
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  .line-clamp-3 {
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  /* Standard animations */
  @keyframes fade-up {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  :global(*) {
    font-family: 'Inter', sans-serif;
  }
</style>