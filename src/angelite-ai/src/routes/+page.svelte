<script>
  import { onMount, tick } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  
  let emailValue = '';
  let isEmailVisible = false;
  let emailInputElement;
  let formElement;
  let showConfirmation = false;
  let subscribedEmail = '';
  let randomPhrase = '';
  
  // Array of short company-related phrases
  const phrases = [
    "GPU-accelerated",
    "Voxel Platform",
    "Spatial Computing",
    "Multiplayer Gaming",
    "Enterprise Ready",
    "Cross-platform",
    "Massive Datasets",
    "Visual Revolution",
    "Future Experiences",
    "Technical Innovation",
    "Creative Engine",
    "Performance Focused",
    "Distributed Systems",
    "Cutting-edge Tech",
    "Industry Solutions",
    "Data Visualized",
    "Seamless Performance",
    "Digital Frontier",
    "Immersive Worlds",
    "Next Generation"
  ];
  
  // Select random phrase on load
  function getRandomPhrase() {
    const randomIndex = Math.floor(Math.random() * phrases.length);
    return phrases[randomIndex];
  }
  
  // Fix toggle function to ensure it's working properly
  function toggleEmailVisibility(event) {
    // Prevent event bubbling
    event.stopPropagation();
    event.preventDefault();
    
    // Toggle state
    isEmailVisible = !isEmailVisible;
    
    // Focus input when visible
    if (isEmailVisible) {
      setTimeout(() => {
        if (emailInputElement) {
          emailInputElement.focus();
        }
      }, 10);
    }
    
    // For debugging
    console.log("Email visibility toggled:", isEmailVisible);
  }
  
  function handleSubmit() {
    if (emailValue.trim()) {
      subscribedEmail = emailValue;
      emailValue = '';
      isEmailVisible = false;
      showConfirmation = true;
      
      // Auto-hide confirmation after 8 seconds
      setTimeout(() => {
        showConfirmation = false;
      }, 8000);
    }
  }
  
  function redirectToBlog() {
    // You can change this to the actual blog URL
    window.location.href = '/blog';
  }
  
  function handleClickOutside(event) {
    if (isEmailVisible && formElement && !formElement.contains(event.target)) {
      isEmailVisible = false;
    }
  }
  
  onMount(() => {
    document.addEventListener('click', handleClickOutside);
    // Set random phrase on page load
    randomPhrase = getRandomPhrase();
    
    return () => {
      document.removeEventListener('click', handleClickOutside);
    };
  });
</script>

<!-- Restore the blob gradient background -->
<div class="fixed inset-0 -z-10 bg-gradient-to-b from-gray-50 to-gray-100 overflow-hidden">
  <!-- Large soft blob gradients -->
  <div class="blob blob-blue"></div>
  <div class="blob blob-purple"></div>
  <div class="blob blob-teal"></div>
  
  <!-- Subtle dot matrix pattern -->
  <div class="dot-matrix"></div>
</div>

<div class="min-h-screen font-sans antialiased text-gray-900 relative">
  <div id="hero" class="container mx-auto px-6 py-24 max-w-5xl relative z-10">
    <div class="hero-content">
        <span class="tag-text absolute -top-1 -translate-x-12 md:right-20 text-xs md:text-sm">({randomPhrase})</span>
      <h1 class="text-5xl md:text-7xl font-bold tracking-tight mb-6 text-gray-900 leading-tight relative">
        <!-- Simplified tag text -->
        
        Spatial computing <span class="block md:inline">redefined</span>
      </h1>
      
      <p class="text-xl md:text-2xl text-gray-700 mb-16 max-w-2xl font-light leading-relaxed">
        Experience the future of technology with our innovative approach to spatial computing.
      </p>
    </div>
    
    <!-- Fixed width container to prevent layout shifts -->
    <div class="relative w-[300px] z-20 shadow-2xl" bind:this={formElement}>
      <!-- Fix close button positioning with absolute positioning -->
      {#if isEmailVisible}
        <button
          on:click={toggleEmailVisibility}
          class="absolute top-0 right-0 -translate-y-1/2 translate-x-1/2 bg-white text-indigo-800 rounded-full w-7 h-7 flex items-center justify-center shadow-lg hover:bg-gray-100 transition-all duration-300 transform hover:scale-105 border border-indigo-100 z-50"
          aria-label="Close"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      {/if}
      
      <div class="relative bg-gradient-to-r from-blue-600 to-indigo-800 rounded-xl shadow-lg hover:shadow-xl transition-shadow duration-300 backdrop-blur-sm">
        <div class="py-4 px-6 relative overflow-hidden">
          <!-- Blog view - improve clickability -->
          <div 
            class="flex items-center justify-between transition-all duration-300 ease-out"
            class:opacity-100={!isEmailVisible} 
            class:opacity-0={isEmailVisible}
            class:translate-y-0={!isEmailVisible}
            class:translate-y-[-10px]={isEmailVisible}
            class:pointer-events-none={isEmailVisible}
            style="height: 40px; transform-origin: center;" 
          >
            <span class="text-2xl font-medium text-white whitespace-nowrap">Blog</span>
            <!-- Fix email button to ensure it's actually clickable -->
            <button 
              type="button"
              class="w-6 h-6 flex items-center justify-center rounded-full bg-white bg-opacity-20 hover:bg-opacity-30 transition-all duration-300 relative z-30 cursor-pointer"
              on:click={toggleEmailVisibility}
              aria-label="Subscribe"
            >
              <img src="/email.svg" alt="email" class="w-3 h-3 opacity-90 pointer-events-none" />
            </button>
          </div>
  
          <!-- Email form - with improved animation -->
          <div 
            class="transition-all duration-300 ease-out absolute inset-0 flex items-center justify-center"
            class:opacity-0={!isEmailVisible}
            class:opacity-100={isEmailVisible}
            class:translate-y-[10px]={!isEmailVisible}
            class:translate-y-0={isEmailVisible}
            class:pointer-events-none={!isEmailVisible}
            style="padding: 1rem; transform-origin: center;"
          >
            <form 
              on:submit|preventDefault={handleSubmit}
              class="w-full flex items-center"
            >
              <div class="relative flex-grow">
                <input
                  type="email"
                  id="email"
                  bind:value={emailValue}
                  bind:this={emailInputElement}
                  class="w-full bg-transparent border-b-2 border-white/30 focus:border-white/70 outline-none text-white py-2 px-1 text-base transition-all duration-300"
                  placeholder=" "
                  required
                />
                <label
                  for="email"
                  class="absolute left-1 text-white/70 transition-all duration-200 pointer-events-none"
                  class:top-2={!emailValue}
                  class:text-base={!emailValue}
                  class:top-[-0.5rem]={emailValue}
                  class:text-xs={emailValue}
                >
                  Email
                </label>
              </div>
              
              <button
                type="submit"
                class="ml-2 p-1 rounded-full bg-white/20 hover:bg-white/30 transition-all duration-300"
                aria-label="Submit"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                </svg>
              </button>
            </form>
          </div>
        </div>
      </div>
      
    </div>
    
    <!-- Confirmation Modal -->
    {#if showConfirmation}
      <div class="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50" 
           transition:fade={{ duration: 200 }}
           on:click={() => showConfirmation = false}>
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden" 
             transition:fly={{ y: 20, duration: 300 }}
             on:click|stopPropagation>
          <div class="p-6">
            <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h3 class="text-xl font-semibold text-center mb-2">Thank You!</h3>
            <p class="text-gray-600 text-center mb-6">
              We've sent a confirmation to <span class="font-medium text-gray-800">{subscribedEmail}</span>. 
              You'll be notified when we publish new content.
            </p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <button 
                class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-300 font-medium"
                on:click={redirectToBlog}>
                Visit Blog
              </button>
              <button 
                class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors duration-300"
                on:click={() => showConfirmation = false}>
                Close
              </button>
            </div>
          </div>
          <div class="h-1 bg-gradient-to-r from-blue-600 to-green-400"></div>
        </div>
      </div>
    {/if}
    
    <div class="mt-32">
      <p class="text-sm text-gray-500">
        © 2025 Angelite AI. All rights reserved.
      </p>
    </div>
  </div>
</div>

<style>
  /* Apple-like smooth focus transitions */
  input::placeholder {
    color: transparent;
  }
  
  input:focus + label, 
  input:not(:placeholder-shown) + label {
    top: -0.5rem !important;
    font-size: 0.75rem !important;
  }
  
  /* Enhanced dot matrix pattern */
  .dot-matrix {
    position: absolute;
    inset: 0;
    background-image: radial-gradient(circle, rgba(0,0,0,0.1) 1px, transparent 1px);
    background-size: 40px 40px; /* Larger spacing between dots */
    opacity: 0.15; /* Reduced opacity */
    pointer-events: none;
    animation: subtle-drift 60s linear infinite;
  }
  
  @keyframes subtle-drift {
    0% {
      background-position: 0 0;
    }
    100% {
      background-position: 30px 30px;
    }
  }
  
  /* Enhanced content animations */
  .hero-content {
    animation: fade-up 1s ease-out forwards;
  }
  
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

  /* Refined tag text - same font family, subtle float */
  .tag-text {
    font-family: inherit;
    color: #4a5568;
    transform: rotate(8deg);
    display: inline-block;
    font-weight: 500;
    letter-spacing: 0.5px;
    animation: subtle-float 3s ease-in-out infinite;
    opacity: 0.8;
    font-size: 0.85em;
    text-shadow: 0 1px 2px rgba(0,0,0,0.05);
  }
  
  @keyframes subtle-float {
    0%, 100% {
      transform: translateY(0) rotate(8deg);
    }
    50% {
      transform: translateY(-2px) rotate(8deg); /* Reduced movement */
    }
  }

  /* Restore enhanced blob properties */
  .blob {
    position: absolute;
    border-radius: 50%;
    filter: blur(60px); /* Less blur */
    opacity: 0.1; /* Reduced opacity */
    transform-origin: center;
    animation: blob-pulse 25s ease-in-out infinite alternate;
    mix-blend-mode: overlay;
  }
  
  .blob-blue {
    width: 40vw; /* Smaller size */
    height: 40vw;
    background: radial-gradient(circle, rgba(37,99,235,1) 0%, rgba(59,130,246,0.3) 70%);
    top: -10%;
    right: -5%;
    animation-delay: 0s;
  }
  
  .blob-purple {
    width: 30vw; /* Smaller size */
    height: 30vw;
    background: radial-gradient(circle, rgba(109,40,217,1) 0%, rgba(139,92,246,0.3) 70%);
    bottom: 10%;
    left: -15%;
    animation-delay: -5s;
  }
  
  .blob-teal {
    width: 35vw; /* Smaller size */
    height: 35vw;
    background: radial-gradient(circle, rgba(20,184,166,1) 0%, rgba(45,212,191,0.3) 70%);
    top: 40%;
    left: 20%;
    animation-delay: -12s;
  }
  
  @keyframes blob-pulse {
    0% {
      transform: scale(1) translate(0, 0);
    }
    33% {
      transform: scale(1.05) translate(1%, 1%); /* Reduced movement */
    }
    66% {
      transform: scale(0.95) translate(-1%, -0.5%); /* Reduced movement */
    }
    100% {
      transform: scale(1.02) translate(0.5%, -1%); /* Reduced movement */
    }
  }

  /* Ensure proper interaction between elements */
  .relative {
    isolation: isolate;
  }
</style>