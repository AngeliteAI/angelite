<script>
  import { onMount, tick } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { cubicOut, backOut, elasticOut } from 'svelte/easing';
  
  let emailValue = '';
  let isEmailVisible = false;
  let emailInputElement;
  let formElement;
  let showConfirmation = false;
  let subscribedEmail = '';
  let randomPhrase = '';
  let isPageLoaded = false;
  let scrollY;
  let videoPlaying = false;
  let videoElement;
  let activeTab = 'architects';
  
  // Enhanced array of premium phrases about the company
  const phrases = [
    "Neural Voxels",
    "AI-Powered Rendering",
    "Spatial Intelligence",
    "Collective Dreams",
    "Metaverse Architecture",
    "Reality Infrastructure",
    "Distributed Imagination",
    "Hyperreal Simulations",
    "Quantum Visualization",
    "Neural Networks",
    "Mindful Computing",
    "Emotional Intelligence",
    "Conscious Design",
    "Next-Gen Gaming",
    "Sensory Architecture",
    "Living Worlds",
    "Digital Consciousness",
    "Synthetic Realities",
    "Fractal Design",
    "Cognitive Spaces"
  ];
  
  // Recent blog posts to showcase on homepage
  const recentPosts = [
    {
      id: 1,
      title: "Breakthrough: 10x Voxel Rendering Performance",
      excerpt: "Our new parallel processing algorithms have shattered previous performance barriers, enabling unprecedented detail in spatial environments.",
      date: "May 15, 2025",
      author: "Alex Chen",
      role: "Principal Engineer",
      category: "Technical",
      image: "https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90",
      readTime: "6 min read"
    },
    {
      id: 2,
      title: "Enterprise Revolution Through Spatial Computing",
      excerpt: "Fortune 500 companies are transforming workflows with our spatial computing platform, reducing design cycles by 78% and training costs by 65%.",
      date: "May 10, 2025",
      author: "Sarah Johnson",
      role: "VP of Enterprise Solutions",
      category: "Business",
      image: "https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90",
      readTime: "8 min read"
    },
    {
      id: 3,
      title: "The Future of Shared Persistent Voxel Worlds",
      excerpt: "Our research team's breakthroughs in distributed persistence technology enables seamless real-time collaboration across unlimited participants.",
      date: "May 5, 2025",
      author: "Marcus Wu",
      role: "Director of Research",
      category: "Research",
      image: "https://images.unsplash.com/photo-1614728894747-a83421789f10?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90",
      readTime: "11 min read"
    }
  ];
  
  // Showcase case studies
  const caseStudies = {
    architects: {
      title: "Spatial Design Studios",
      description: "Architects are visualizing complex 3D spaces in real-time, collaborating with clients directly in their digital models.",
      stats: [
        { value: "87%", label: "Faster client approvals" },
        { value: "3.2×", label: "Project iteration speed" }
      ],
      image: "https://images.unsplash.com/photo-1503387837-b154d5074bd2?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90"
    },
    gamedevs: {
      title: "Indie Game Developers",
      description: "Small teams are building massive interactive worlds in weeks rather than months with our volumetric tools.",
      stats: [
        { value: "65%", label: "Reduced production time" },
        { value: "10×", label: "Larger environments" }
      ],
      image: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90"
    },
    education: {
      title: "Educational Institutions",
      description: "Schools are creating interactive spatial learning environments that improve student engagement and concept retention.",
      stats: [
        { value: "42%", label: "Higher engagement" },
        { value: "2.7×", label: "Better knowledge retention" }
      ],
      image: "https://images.unsplash.com/photo-1509062522246-3755977927d7?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=90"
    }
  };
  
  const teamMembers = [
    {
      name: "Julia Chen",
      role: "Co-founder & CEO",
      quote: "We're not just building technology, we're building new ways to think about and interact with digital space.",
      image: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=400&q=80"
    },
    {
      name: "Raj Patel",
      role: "Co-founder & CTO",
      quote: "Our breakthrough was realizing we could render voxels at scale by fundamentally rethinking the traditional approach.",
      image: "https://images.unsplash.com/photo-1560250097-0b93528c311a?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=400&q=80"
    }
  ];
  
  // Top clients showcase
  const clients = [
    { name: "Tesla", logo: "/logos/tesla.svg", opacity: 0.7 },
    { name: "NVIDIA", logo: "/logos/nvidia.svg", opacity: 0.8 },
    { name: "Microsoft", logo: "/logos/microsoft.svg", opacity: 0.7 },
    { name: "Meta", logo: "/logos/meta.svg", opacity: 0.7 },
    { name: "Amazon", logo: "/logos/amazon.svg", opacity: 0.7 }
  ];
  
  // Select random phrase on load
  function getRandomPhrase() {
    const randomIndex = Math.floor(Math.random() * phrases.length);
    return phrases[randomIndex];
  }
  
  function toggleEmailVisibility(event) {
    event.stopPropagation();
    event.preventDefault();
    
    isEmailVisible = !isEmailVisible;
    
    if (isEmailVisible) {
      setTimeout(() => {
        if (emailInputElement) {
          emailInputElement.focus();
        }
      }, 10);
    }
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
    window.location.href = '/blog';
  }
  
  function handleClickOutside(event) {
    if (isEmailVisible && formElement && !formElement.contains(event.target)) {
      isEmailVisible = false;
    }
  }
  
  function toggleVideo() {
    if (videoElement) {
      if (videoPlaying) {
        videoElement.pause();
      } else {
        videoElement.play();
      }
      videoPlaying = !videoPlaying;
    }
  }
  
  function setActiveTab(tab) {
    activeTab = tab;
  }
  
  // Scroll-based animations and effects
  $: parallaxOffset = scrollY ? scrollY * 0.15 : 0;
  
  onMount(() => {
    document.addEventListener('click', handleClickOutside);
    // Set random phrase on page load
    randomPhrase = getRandomPhrase();
    
    // Set page as loaded for animations
    setTimeout(() => {
      isPageLoaded = true;
    }, 100);
    
    return () => {
      document.removeEventListener('click', handleClickOutside);
    };
  });
</script>

<svelte:window bind:scrollY />

<main>
  <!-- Premium Hero Section with Video -->
  <section class="relative overflow-hidden py-16 md:py-24">
    <div class="container mx-auto px-6 max-w-7xl relative z-10">
      <!-- Animated decorator elements with custom gradient borders -->
      <div class="absolute top-10 right-10 w-32 h-32 border border-gradient-to-r from-[#8B5CF6]/20 to-[#EC4899]/10 rounded-full animate-pulse-slow opacity-30"></div>
      <div class="absolute top-40 right-20 w-16 h-16 border border-gradient-to-r from-[#8B5CF6]/20 to-[#6366F1]/10 rounded-full animate-pulse-slow opacity-30" style="animation-delay: 1s;"></div>
      
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        <div class="hero-content max-w-xl relative" style="transform: translateY({isPageLoaded ? (-parallaxOffset * 0.5) + 'px' : '0px'})">
          <div class="mb-4 opacity-80">
            <div class="inline-flex items-center space-x-1 px-3 py-1 bg-[#8B5CF6]/10 rounded-full border border-[#8B5CF6]/20 text-indigo-300 text-sm">
              <span class="inline-block w-2 h-2 bg-[#8B5CF6] rounded-full"></span>
              <span>{randomPhrase}</span>
            </div>
          </div>
          
          <h1 class="text-5xl md:text-6xl font-bold tracking-tight mb-6 text-white leading-tight glowing-text font-spaceGrotesk">
            Redefining <span class="text-transparent bg-clip-text bg-gradient-to-r from-[#8B5CF6] to-[#EC4899]">spatial</span> computing
          </h1>
          
          <p class="text-xl text-indigo-100/90 mb-10 max-w-3xl font-light leading-relaxed font-outfit">
            An innovative platform that transforms how we create, share, and experience spatial computing through advanced voxel technology.
          </p>
          
          <!-- CTA buttons -->
          <div class="flex flex-col sm:flex-row gap-4 mb-12">
            <a href="/products" class="inline-flex items-center justify-center px-8 py-4 bg-gradient-to-r from-[#8B5CF6] to-[#6366F1] rounded-xl text-white font-medium shadow-lg shadow-[#8B5CF6]/20 hover:shadow-[#8B5CF6]/40 transition-all duration-300 group/btn text-center btn-hover-fx">
              Get Early Access
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ml-2 transition-transform duration-300 group-hover/btn:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </a>
            <a href="#case-studies" class="inline-flex items-center justify-center px-8 py-4 bg-white/5 border border-white/10 rounded-xl text-white hover:bg-white/10 transition-all duration-300 text-center">
              See It In Action
            </a>
          </div>
          
          <!-- Email subscription floating element with custom 3D effect -->
          <div class="relative z-20" bind:this={formElement} 
               in:fly={{ y: 30, duration: 800, delay: 300 }}>
            <div class="premium-card">
              <div class="bg-gradient-to-b from-white/[0.07] to-white/[0.03] backdrop-blur-md rounded-xl py-5 px-6 shadow-2xl border border-white/10 relative overflow-hidden">
                <!-- Glowing light effect -->
                <div class="absolute -top-10 -right-10 w-20 h-20 bg-indigo-500 rounded-full opacity-10 blur-3xl"></div>
                
                {#if isEmailVisible}
                  <button
                    on:click={toggleEmailVisibility}
                    class="absolute top-0 right-0 -translate-y-1/2 translate-x-1/2 bg-white text-indigo-900 rounded-full w-7 h-7 flex items-center justify-center shadow-lg hover:scale-105 transition-all duration-300 transform border border-indigo-200 z-50"
                    aria-label="Close"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                {/if}
                
                <!-- Toggle button or subscribe form based on state -->
                <div 
                  class="flex items-center justify-between transition-all duration-300 ease-out"
                  class:opacity-100={!isEmailVisible} 
                  class:opacity-0={isEmailVisible}
                  class:translate-y-0={!isEmailVisible}
                  class:translate-y-[-10px]={isEmailVisible}
                  class:pointer-events-none={isEmailVisible}
                  style="height: 38px; transform-origin: center;"
                >
                  <span class="text-white font-medium whitespace-nowrap">Subscribe to updates</span>
                  <button 
                    type="button"
                    class="w-9 h-9 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 transition-all duration-300"
                    on:click={toggleEmailVisibility}
                    aria-label="Subscribe"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  </button>
                </div>
                
                <!-- Email form with premium styling -->
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
                        class="w-full bg-transparent border-b-2 border-white/30 focus:border-indigo-400 outline-none text-white py-2 px-1 text-base transition-all duration-300"
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
                      class="ml-2 p-2 rounded-full bg-indigo-500 hover:bg-indigo-600 transition-all duration-300 shadow-lg shadow-indigo-500/30"
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
        </div>
        
        <!-- Video showcase with premium design -->
        <div class="relative max-w-xl mx-auto lg:mx-0" in:fade={{ duration: 800, delay: 200 }}>
          <div class="aspect-video bg-gradient-to-tr from-[#1a103c]/70 to-[#42265e]/70 rounded-2xl overflow-hidden group border border-white/10 shadow-2xl">
            <video 
              bind:this={videoElement}
              class="w-full h-full object-cover opacity-90 mix-blend-lighten"
              poster="https://images.unsplash.com/photo-1534972195531-d756b9bfa9f2?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1200&q=80"
              muted
              loop
              playsinline
            >
              <source src="https://assets.mixkit.co/videos/preview/mixkit-digital-animation-of-a-city-growing-12498-large.mp4" type="video/mp4" />
              Your browser does not support the video tag.
            </video>
            
            <!-- Overlay and play button -->
            <div class="absolute inset-0 flex items-center justify-center bg-gradient-to-b from-black/20 to-black/60">
              <button 
                on:click={toggleVideo}
                class="w-16 h-16 rounded-full bg-white/10 backdrop-blur-sm flex items-center justify-center transition-all duration-300 group-hover:scale-110 border border-white/20"
              >
                {#if !videoPlaying}
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-white" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
                  </svg>
                {:else}
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                {/if}
              </button>
            </div>
          </div>
          
          <!-- Caption with designer style -->
          <div class="mt-4 text-center px-4">
            <p class="text-indigo-300/80 text-sm font-outfit">Experience how Angelite transforms spatial computing across industries</p>
          </div>
        </div>
      </div>
    </div>
  </section>
  
  <!-- Feature callout with custom premium glass card design -->
  <section class="relative py-16">
    <div class="container mx-auto px-6 max-w-7xl">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        {#each [
          {
            title: "10× Faster Rendering",
            description: "Our patented algorithms render massive voxel environments at unprecedented speeds.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>`
          },
          {
            title: "Truly Collaborative",
            description: "Real-time synchronization allows multiple users to create together simultaneously.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>`
          },
          {
            title: "Developer-First",
            description: "Intuitive APIs and SDKs that make spatial computing accessible to every developer.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" /></svg>`
          }
        ] as feature, i}
          <div 
            class="bg-gradient-to-b from-white/[0.07] to-white/[0.03] backdrop-blur-md rounded-xl p-6 transition-all duration-500 hover:translate-y-[-4px] border border-white/10 group hover:shadow-lg"
            in:fade={{ duration: 600, delay: 200 + (i * 100) }}
          >
            <div class="bg-[#8B5CF6]/10 rounded-lg w-12 h-12 flex items-center justify-center mb-4 text-[#8B5CF6] group-hover:bg-[#8B5CF6]/20 transition-all duration-300">
              {@html feature.icon}
            </div>
            <h3 class="text-lg font-bold text-white mb-2 font-spaceGrotesk">{feature.title}</h3>
            <p class="text-indigo-100/70 text-sm font-outfit">{feature.description}</p>
          </div>
        {/each}
      </div>
    </div>
  </section>
  
  <!-- Case Studies Section with customized tabbed interface -->
  <section id="case-studies" class="relative py-20 md:py-28 overflow-hidden">
    <div class="absolute top-1/4 left-10 w-64 h-64 rounded-full bg-gradient-to-r from-purple-500/5 to-indigo-500/5 blur-3xl pointer-events-none"></div>
    <div class="absolute bottom-1/4 right-10 w-80 h-80 rounded-full bg-gradient-to-r from-teal-500/5 to-blue-500/5 blur-3xl pointer-events-none"></div>
    
    <div class="container mx-auto px-6 max-w-7xl">
      <div class="text-center mb-16">
        <h2 class="text-3xl md:text-4xl font-bold text-white mb-4 glowing-text font-spaceGrotesk">Who's using Angelite</h2>
        <p class="text-xl text-indigo-100/80 max-w-3xl mx-auto font-outfit">Our technology is empowering creators across industries to build incredible spatial experiences.</p>
      </div>
      
      <!-- Premium tab controls (customized style) -->
      <div class="flex justify-center mb-12">
        <div class="inline-flex p-1 bg-white/5 backdrop-blur-sm rounded-lg border border-white/10">
          {#each Object.keys(caseStudies) as tab}
            <button 
              class="px-5 py-2 rounded-md text-sm font-medium transition-all duration-300 relative font-outfit"
              class:text-white={activeTab === tab}
              class:text-indigo-200={activeTab !== tab}
              class:hover:text-white={activeTab !== tab}
              on:click={() => setActiveTab(tab)}
            >
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
              
              {#if activeTab === tab}
                <div class="absolute inset-0 bg-[#8B5CF6]/20 rounded-md -z-10" 
                     transition:scale={{ duration: 200, easing: cubicOut }}>
                </div>
              {/if}
            </button>
          {/each}
        </div>
      </div>
      
      <!-- Case study content with custom styling -->
      {#each Object.entries(caseStudies) as [key, study]}
        {#if activeTab === key}
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-10 items-center"
               in:fade={{ duration: 400, delay: 100 }}>
            <div class="order-2 lg:order-1">
              <h3 class="text-2xl md:text-3xl font-bold text-white mb-4 font-spaceGrotesk">{study.title}</h3>
              <p class="text-indigo-100/80 mb-8 text-lg font-outfit">{study.description}</p>
              
              <div class="grid grid-cols-2 gap-6 mb-8">
                {#each study.stats as stat}
                  <div class="bg-white/5 backdrop-blur-sm rounded-lg p-4 border border-white/10">
                    <div class="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[#8B5CF6] to-[#EC4899] mb-1 font-spaceGrotesk">{stat.value}</div>
                    <div class="text-indigo-200/80 text-sm font-outfit">{stat.label}</div>
                  </div>
                {/each}
              </div>
              
              <a href="#" class="inline-flex items-center text-[#8B5CF6] hover:text-[#a78bfa] transition-colors duration-300 group text-sm font-outfit">
                Read the full case study
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 ml-1 transition-transform duration-300 group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                </svg>
              </a>
            </div>
            
            <div class="order-1 lg:order-2">
              <div class="rounded-xl overflow-hidden aspect-[4/3] border border-white/10 shadow-2xl relative group">
                <div class="absolute inset-0 bg-gradient-to-tr from-indigo-900/50 to-purple-900/30 mix-blend-overlay z-10 group-hover:opacity-75 transition-opacity duration-300"></div>
                <img 
                  src={study.image} 
                  alt={study.title}
                  class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                />
              </div>
            </div>
          </div>
        {/if}
      {/each}
    </div>
  </section>
  
  <!-- Founder spotlight (Apple-like minimalist design) -->
  <section class="relative py-20 bg-gradient-to-b from-[#0a0c20] to-[#080a1f] border-y border-white/5">
    <div class="container mx-auto px-6 max-w-5xl">
      <div class="text-center mb-16">
        <div class="inline-flex items-center justify-center mb-4">
          <div class="w-px h-8 bg-indigo-500/30 mx-4"></div>
          <h2 class="text-2xl font-medium text-white">Our Vision</h2>
          <div class="w-px h-8 bg-indigo-500/30 mx-4"></div>
        </div>
        <p class="text-3xl md:text-4xl text-indigo-100/90 max-w-4xl mx-auto font-light leading-relaxed italic">
          "We're building tools that give creators superpowers, enabling anyone to shape the spatial computing revolution."
        </p>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mt-16">
        {#each teamMembers as member, i}
          <div 
            class="bg-gradient-to-b from-white/[0.05] to-white/[0.02] backdrop-blur-sm border border-white/10 rounded-xl overflow-hidden flex flex-col md:flex-row"
            in:fade={{ duration: 600, delay: 200 + (i * 100) }}
          >
            <div class="w-full md:w-1/3 aspect-square md:aspect-auto">
              <img src={member.image} alt={member.name} class="w-full h-full object-cover" />
            </div>
            <div class="p-6 flex flex-col justify-center flex-1">
              <h3 class="text-xl font-bold text-white mb-1">{member.name}</h3>
              <p class="text-indigo-300/80 text-sm mb-4">{member.role}</p>
              <p class="text-indigo-100/80 text-sm italic">"{member.quote}"</p>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </section>
  
  <!-- Features Section with enhanced design (more Apple-like) -->
  <section class="relative py-20 md:py-28 overflow-hidden">
    <div class="container mx-auto px-6 max-w-7xl">
      <div class="text-center mb-16">
        <h2 class="text-3xl md:text-4xl font-bold text-white mb-4 glowing-text">Built for creators</h2>
        <p class="text-xl text-indigo-100/80 max-w-3xl mx-auto">Our platform brings together innovative technology and intuitive design to transform spatial computing experiences.</p>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {#each [
          {
            title: "Lightning Fast Performance",
            description: "Our innovative engine delivers rendering performance that's 10x faster than traditional solutions, enabling real-time interaction with massive datasets.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>`
          },
          {
            title: "Collaborative by Design",
            description: "Real-time multiplayer experiences with seamless synchronization enable teams to work together across any distance.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>`
          },
          {
            title: "Multiplatform",
            description: "Deploy your spatial applications across VR, AR, mobile, and desktop with a single codebase, ensuring consistent experiences everywhere.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>`
          },
          {
            title: "Developer Friendly",
            description: "Our intuitive APIs and comprehensive documentation make it easy to build sophisticated spatial applications with minimal learning curve.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" /></svg>`
          },
          {
            title: "Voxel-first Design",
            description: "Purpose-built voxel tools that deliver the perfect balance of performance and visual quality for next-generation spatial applications.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10l-2 1m0 0l-2-1m2 1v2.5M20 7l-2 1m2-1l-2-1m2 1v2.5M14 4l-2-1-2 1M4 7l2-1M4 7l2 1M4 7v2.5M12 21l-2-1m2 1l2-1m-2 1v-2.5M6 18l-2-1v-2.5M18 18l2-1v-2.5" /></svg>`
          },
          {
            title: "Cutting-edge Research",
            description: "Access to the latest breakthroughs in spatial computing through our continuous R&D and academic partnerships.",
            icon: `<svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" /></svg>`
          }
        ] as feature, i}
          <div 
            class="bg-gradient-to-b from-white/5 to-white/[0.02] border border-white/10 backdrop-blur-sm rounded-xl p-8 transition-all duration-500 hover:scale-[1.02] hover:shadow-xl group"
            in:fade={{ duration: 600, delay: 200 + (i * 100) }}
          >
            <div class="bg-indigo-500/10 rounded-lg w-14 h-14 flex items-center justify-center mb-6 text-indigo-400 transition-all duration-300 group-hover:scale-110 group-hover:bg-gradient-to-br group-hover:from-indigo-500/20 group-hover:to-purple-500/20">
              {@html feature.icon}
            </div>
            <h3 class="text-xl font-bold text-white mb-3 group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-indigo-300 group-hover:to-indigo-100 transition-all duration-300">{feature.title}</h3>
            <p class="text-indigo-100/70">{feature.description}</p>
          </div>
        {/each}
      </div>
    </div>
  </section>
  
  <!-- From The Blog Section with enhanced Apple-like design -->
  <section class="relative py-20 md:py-28 overflow-hidden">
    <div class="container mx-auto px-6 max-w-7xl">
      <div class="flex flex-col md:flex-row md:items-end justify-between mb-16">
        <div>
          <h2 class="text-3xl md:text-4xl font-bold text-white mb-4 glowing-text">From Our Journal</h2>
          <p class="text-xl text-indigo-100/80 max-w-2xl">Latest insights and perspectives on spatial computing and voxel rendering.</p>
        </div>
        <a href="/blog" class="inline-flex items-center text-indigo-400 hover:text-indigo-300 transition-colors duration-300 mt-4 md:mt-0 group">
          Explore our blog
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 ml-1 transition-transform duration-300 group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
          </svg>
        </a>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
        {#each recentPosts as post, i}
          <div 
            class="premium-card"
            in:fade={{ duration: 600, delay: 300 + (i * 150) }}
          >
            <div class="h-full rounded-2xl overflow-hidden bg-gradient-to-b from-white/5 to-white/[0.02] border border-white/10 backdrop-blur-sm transition-all duration-500 flex flex-col group hover:scale-[1.02] hover:shadow-xl hover:premium-glow">
              <!-- Image container with overlay gradient -->
              <div class="aspect-[16/9] overflow-hidden relative">
                <!-- Category label -->
                <div class="absolute top-4 left-4 z-20">
                  <span class="px-3 py-1 text-xs font-medium rounded-md bg-white/10 backdrop-blur-md text-white/90">{post.category}</span>
                </div>
                
                <!-- Image gradient overlay -->
                <div class="absolute inset-0 bg-gradient-to-t from-[#0c1033] to-transparent z-10 opacity-70"></div>
                
                <img 
                  src={post.image} 
                  alt={post.title}
                  class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                />
              </div>
              
              <!-- Content -->
              <div class="p-6 md:p-8 flex flex-col flex-1 relative z-10">
                <h3 class="text-xl font-bold mb-4 leading-tight text-white">{post.title}</h3>
                <p class="text-indigo-100/70 mb-6 line-clamp-3 text-base flex-1">{post.excerpt}</p>
                
                <div class="mt-auto">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <div class="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-600 to-purple-500 flex items-center justify-center text-white font-medium">
                        {post.author.charAt(0)}
                      </div>
                      <div class="ml-2 text-sm">
                        <div class="text-white/90">{post.author}</div>
                        <div class="text-indigo-300/70 text-xs">{post.role}</div>
                      </div>
                    </div>
                    
                    <div class="text-xs text-indigo-300/70">{post.readTime}</div>
                  </div>
                </div>
                
                <!-- Hidden arrow that appears on hover -->
                <div class="absolute bottom-6 right-6 w-10 h-10 flex items-center justify-center bg-indigo-500 rounded-full shadow-lg shadow-indigo-500/30 opacity-0 translate-y-2 group-hover:opacity-100 group-hover:translate-y-0 transition-all duration-300">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                </div>
              </div>
              <a href={`/blog/${post.id}`} class="absolute inset-0" aria-label={post.title}></a>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </section>
  
  <!-- Enhanced premium CTA Section -->
  <section class="relative py-20 md:py-28 overflow-hidden">
    <div class="absolute inset-0 bg-gradient-to-b from-[#06071B] to-[#1a103c]/30"></div>
    
    <!-- 3D decorative elements with brand colors -->
    <div class="absolute w-1/3 h-1/3 top-0 right-0 
                bg-gradient-to-br from-[#8B5CF6]/20 to-[#EC4899]/5 
                blur-3xl rounded-full transform -translate-y-1/2 translate-x-1/4"></div>
    <div class="absolute w-1/4 h-1/4 bottom-0 left-0 
                bg-gradient-to-tr from-[#6366F1]/10 to-[#8B5CF6]/5 
                blur-3xl rounded-full transform translate-y-1/2 -translate-x-1/4"></div>
    
    <div class="container mx-auto px-6 max-w-7xl relative z-10">
      <div class="max-w-3xl mx-auto">
        <div class="premium-card">
          <div class="bg-gradient-to-b from-white/[0.07] to-white/[0.03] backdrop-blur-md rounded-2xl p-8 md:p-12 shadow-2xl border border-white/10 relative overflow-hidden">
            <!-- Glowing light effect with brand colors -->
            <div class="absolute -top-20 -right-20 w-40 h-40 bg-[#8B5CF6] rounded-full opacity-10 blur-3xl"></div>
            <div class="absolute -bottom-20 -left-20 w-40 h-40 bg-[#EC4899] rounded-full opacity-10 blur-3xl"></div>
            
            <div class="text-center mb-12">
              <div class="inline-block rounded-full p-1 bg-gradient-to-r from-[#8B5CF6] to-[#EC4899] mb-6">
                <div class="bg-[#06071B] p-2 rounded-full">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-[#a78bfa]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
              </div>
              
              <h3 class="text-3xl md:text-4xl font-bold text-white mb-4 font-spaceGrotesk">Join the Spatial Revolution</h3>
              <p class="text-indigo-100/80 text-lg mb-10 max-w-2xl mx-auto leading-relaxed font-outfit">
                Be among the first to experience our groundbreaking platform and help shape the future of spatial computing.
              </p>
              
              <div class="flex flex-col sm:flex-row gap-4 justify-center">
                <a href="/early-access" class="px-8 py-4 bg-gradient-to-r from-[#8B5CF6] to-[#6366F1] rounded-lg text-white font-medium shadow-lg shadow-[#8B5CF6]/20 hover:shadow-[#8B5CF6]/40 transition-all duration-300 btn-hover-fx font-outfit">
                  Request Early Access
                </a>
                <a href="https://github.com/angelite" target="_blank" class="px-8 py-4 bg-white/5 border border-white/10 hover:bg-white/10 rounded-lg text-white transition-all duration-300 inline-flex items-center justify-center font-outfit">
                  <svg class="w-5 h-5 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                  See on GitHub
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</main>

<!-- Premium confirmation modal with customized styling -->
{#if showConfirmation}
  <div class="fixed inset-0 bg-black/50 backdrop-blur-md flex items-center justify-center z-50" 
       transition:fade={{ duration: 300 }}
       on:click={() => showConfirmation = false}>
    <div class="bg-gradient-to-b from-white/[0.07] to-white/[0.03] backdrop-blur-md rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden border border-white/10 premium-card" 
         transition:fly={{ y: 20, duration: 400, easing: elasticOut }}
         on:click|stopPropagation>
      <div class="p-8">
        <div class="w-20 h-20 bg-gradient-to-br from-green-400 to-emerald-600 rounded-full flex items-center justify-center mx-auto mb-6 shadow-lg shadow-green-500/20">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
        </div>
        <h3 class="text-2xl font-bold text-white text-center mb-3 font-spaceGrotesk">Thank You!</h3>
        <p class="text-indigo-100/80 text-center mb-8 font-outfit">
          We've sent a confirmation to <span class="font-medium text-indigo-200">{subscribedEmail}</span>. 
          You'll be the first to receive our insights and updates.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <button 
            class="px-6 py-3 bg-gradient-to-r from-[#8B5CF6] to-[#6366F1] text-white rounded-lg hover:shadow-lg hover:shadow-[#8B5CF6]/20 transition-all duration-300 font-medium btn-hover-fx font-outfit"
            on:click={redirectToBlog}>
            Explore Blog
          </button>
          <button 
            class="px-6 py-3 bg-white/5 border border-white/10 text-white rounded-lg hover:bg-white/10 transition-all duration-300 font-outfit"
            on:click={() => showConfirmation = false}>
            Close
          </button>
        </div>
      </div>
      <div class="h-1 bg-gradient-to-r from-[#8B5CF6] via-[#EC4899] to-[#8B5CF6]"></div>
    </div>
  </div>
{/if}

<style>
  /* Premium text effect with subtle gradient */
  .glowing-text {
    text-shadow: 0 0 20px rgba(99, 102, 241, 0.2);
    background: linear-gradient(90deg, rgba(255, 255, 255, 1) 0%, rgba(237, 233, 254, 1) 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  
  /* Premium glow effect for cards with improved gradient edge */
  .premium-card {
    transition: all 0.3s ease;
    position: relative;
  }
  
  .premium-card::after {
    content: '';
    position: absolute;
    inset: -1px;
    border-radius: inherit;
    padding: 1px;
    background: linear-gradient(215deg, rgba(99, 102, 241, 0.4), rgba(167, 139, 250, 0.1) 40%, rgba(99, 102, 241, 0) 80%);
    -webkit-mask: 
      linear-gradient(#fff 0 0) content-box, 
      linear-gradient(#fff 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    opacity: 0;
    transition: opacity 0.4s ease;
  }
  
  .premium-card:hover::after {
    opacity: 1;
  }
  
  .premium-glow {
    box-shadow: 0 0 30px rgba(99, 102, 241, 0.2);
  }
  
  /* Enhanced Apple-like smooth focus transitions with gradient */
  input::placeholder {
    color: transparent;
  }
  
  input:focus + label, 
  input:not(:placeholder-shown) + label {
    top: -0.5rem !important;
    font-size: 0.75rem !important;
    background: linear-gradient(90deg, rgba(129, 140, 248, 1), rgba(167, 139, 250, 1));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  
  /* Line clamp utilities with improved styling */
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
  
  /* Enhanced content animations with subtle gradients */
  .hero-content {
    animation: fade-up 1s ease-out forwards;
  }
  
  /* Gradient borders utility */
  .border-gradient-to-r {
    border-image-slice: 1;
    border-image-source: linear-gradient(to right, var(--tw-gradient-from), var(--tw-gradient-to));
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
</style>