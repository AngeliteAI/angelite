<script>
    import {
        HeroSection,
        KickstarterProgress,
        CountdownTimer,
        RewardTier,
        NewspaperGrid,
        HeroFeatureCard,
        StoryCard,
        MultiplayerCard,
        ExplorationCard,
        BuildingCard,
        TweetCard
    } from "synthesis-ui";
    
    // Kickstarter campaign data
    const campaignData = {
        currentAmount: 487650,
        goalAmount: 50000,
        backerCount: 6234,
        daysLeft: 18,
        endDate: new Date('2025-02-14T00:00:00Z')
    };
    
    // Reward tiers
    const rewardTiers = [
        {
            tier: "Digital Pioneer",
            price: 29,
            description: "Begin your synthesis journey with the digital edition and exclusive early access.",
            rewards: [
                "Full Digital Game",
                "Beta Access (March 2025)",
                "Exclusive Founder's Badge",
                "Digital Soundtrack",
                "Development Updates"
            ],
            backers: 2841,
            earlyBird: true
        },
        {
            tier: "Synthesis Creator",
            price: 49,
            description: "The complete package for dedicated world builders.",
            rewards: [
                "Everything in Digital Pioneer",
                "Name in Credits",
                "Exclusive Building Skins Pack",
                "Digital Art Book (PDF)",
                "Alpha Access (January 2025)"
            ],
            backers: 2176,
            featured: true
        },
        {
            tier: "Architect Elite",
            price: 99,
            description: "Shape worlds with exclusive content and physical rewards.",
            rewards: [
                "Everything in Synthesis Creator",
                "Physical Collector's Box",
                "Limited Edition Art Print",
                "Custom Structure Naming Rights",
                "Exclusive Developer Q&A Access"
            ],
            backers: 943,
            limited: true,
            remaining: 57
        },
        {
            tier: "Universal Designer",
            price: 249,
            description: "Become a co-creator with unprecedented creative control.",
            rewards: [
                "Everything in Architect Elite",
                "Design a Unique Biome",
                "1-on-1 Developer Session",
                "Signed Concept Art Portfolio",
                "Executive Producer Credit",
                "Lifetime Season Pass"
            ],
            backers: 189,
            limited: true,
            remaining: 11
        }
    ];

    // Game content articles
    const articles = [
        {
            type: "hero",
            component: HeroFeatureCard,
            props: {
                title: "SYNTHESIS",
                subtitle: "Create. Combine. Evolve.",
                description:
                    "Shape matter itself in this revolutionary sandbox where every element can be combined, transformed, and brought to life. Build impossible structures, craft new materials, and watch your creations evolve.",
                image: "https://images.unsplash.com/photo-1634017839464-5c339ebe3cb4?w=1600&h=900&fit=crop",
                features: [
                    "Molecular Crafting",
                    "Living Worlds",
                    "Emergent Systems",
                    "Infinite Possibilities",
                ],
                cta: {
                    text: "Start Creating",
                    link: "#play",
                },
            },
            size: { cols: 3, rows: 3 },
            priority: 1,
        },
        {
            type: "story",
            component: StoryCard,
            props: {
                title: "The Synthesis Protocol",
                subtitle: "Chapter One: First Contact",
                description:
                    "In a universe where matter responds to thought, you are the first to unlock the ancient synthesis technology. Transform raw elements into living, breathing worlds.",
                image: "https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&h=600&fit=crop",
                duration: "Endless possibilities",
                chapters: [
                    "Discovery",
                    "First Synthesis",
                    "Living Matter",
                    "The Network",
                    "Transcendence",
                ],
            },
            size: { cols: 2, rows: 2 },
            priority: 2,
        },
        {
            type: "building",
            component: BuildingCard,
            props: {
                title: "Molecular Architecture",
                subtitle: "Building System",
                description:
                    "Combine elements at the atomic level to create structures that defy physics. Watch as your creations adapt and evolve.",
                image: "https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&h=600&fit=crop",
                totalBuildings: 89,
                powerUsage: { used: 1250, total: 2000 },
                buildQueue: [
                    {
                        name: "Quantum Reactor",
                        progress: 85,
                        timeLeft: "1:12",
                    },
                    { name: "Neural Network Hub", progress: 45, timeLeft: "4:33" },
                ],
                structures: [
                    {
                        name: "Synthesis Chamber",
                        built: 7,
                        max: 10,
                        cost: "500 Energy",
                    },
                    {
                        name: "Matter Converter",
                        built: 4,
                        max: 5,
                        cost: "1000 Energy",
                    },
                    {
                        name: "Evolution Lab",
                        built: 2,
                        max: 3,
                        cost: "2500 Energy",
                    },
                ],
                resources: {
                    Energy: 5420,
                    Matter: 3850,
                    Consciousness: 256,
                },
            },
            size: { cols: 1, rows: 2 },
            priority: 2,
        },
        {
            type: "article",
            title: "Developer Update: Living Worlds",
            content:
                "We're excited to share our latest breakthrough:\n\n**Dynamic Ecosystems** - Your creations now form complex relationships\n**Emergent Behavior** - Watch societies develop naturally\n**Matter Programming** - Code reality itself\n\nNext milestone: Multiplayer synthesis chambers!",
            image: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&h=400&fit=crop",
            size: { cols: 1, rows: 1 },
            priority: 3,
        },
        {
            type: "multiplayer",
            component: MultiplayerCard,
            props: {
                title: "Synthesize Together",
                subtitle: "Collaborative Creation",
                description:
                    "Connect synthesis chambers across dimensions. Share discoveries, trade exotic matter, or compete in creation challenges.",
                image: "https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=800&h=600&fit=crop",
                playerCount: 24847,
                features: [
                    {
                        icon: "🧬",
                        title: "Shared Worlds",
                        description: "Build universes together",
                    },
                    {
                        icon: "⚡",
                        title: "Energy Trading",
                        description: "Exchange rare elements",
                    },
                    {
                        icon: "🌟",
                        title: "Creation Contests",
                        description: "Showcase your designs",
                    },
                ],
            },
            size: { cols: 2, rows: 1 },
            priority: 2,
        },
        {
            type: "exploration",
            component: ExplorationCard,
            props: {
                title: "Infinite Discovery",
                subtitle: "Research System",
                description:
                    "Every synthesis unlocks new possibilities. Discover hidden properties of matter and unlock the secrets of creation.",
                image: "https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=800&h=600&fit=crop",
                planetsExplored: 312,
                discoveries: [
                    {
                        name: "Quantum Materials",
                        description: "Bend space-time",
                    },
                    {
                        name: "Living Crystals",
                        description: "Self-organizing structures",
                    },
                    {
                        name: "Thought Matter",
                        description: "Consciousness made real",
                    },
                ],
                resources: {
                    "Dark Energy": 534,
                    "Exotic Matter": 189,
                    "Pure Consciousness": 42,
                },
            },
            size: { cols: 2, rows: 1 },
            priority: 2,
        },
        {
            type: "tweet",
            component: TweetCard,
            props: {
                content:
                    "Just synthesized my first living city! 🏙️✨ The buildings grow and adapt based on inhabitant needs. This game is literally letting us play god! @SynthesisGame #Synthesis",
                author: "@CreatorPrime",
                timestamp: "2h ago",
                likes: 3823,
                retweets: 821,
                replies: 189,
            },
            size: { cols: 1, rows: 1 },
            priority: 3,
        },
        {
            type: "article",
            title: "Getting Started with Synthesis",
            content:
                "Welcome to a universe where you control the fundamental forces:\n\n1. **Master the Basics** - Learn elemental combination\n2. **Experiment Freely** - No combination is wrong\n3. **Observe Evolution** - Your creations will surprise you\n4. **Share Discoveries** - The community thrives on innovation\n\nRemember: In Synthesis, imagination is your only limit!",
            image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=400&fit=crop",
            size: { cols: 1, rows: 1 },
            priority: 3,
        },
        {
            type: "tweet",
            component: TweetCard,
            props: {
                content:
                    "🔬 Update 3.0 is HERE!\n\n✅ Neural synthesis networks\n✅ Time manipulation mechanics\n✅ Cross-dimensional trading\n✅ 100+ new material combinations\n\nFull notes: synthesis-game.com/update",
                author: "@SynthesisGame",
                timestamp: "30m ago",
                likes: 5892,
                retweets: 1234,
            },
            size: { cols: 1, rows: 1 },
            priority: 3,
        },
        {
            type: "article",
            title: "Community Showcase",
            content:
                "This week's most innovative creations:\n\n**The Breathing Forest** by @NatureSynth\n**Fractal City** by @GeometryMaster\n**Living Symphony** by @SoundArchitect\n\nEach winner receives 10,000 synthesis credits!",
            image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=400&fit=crop",
            size: { cols: 1, rows: 1 },
            priority: 3,
        },
    ];
    
    function selectReward(tier) {
        console.log(`Selected: ${tier.tier}`);
    }
</script>

<main class="seamless-container">
    <!-- Hero Section with seamless transition -->
    <div class="hero-wrapper">
        <HeroSection />
        <div class="hero-gradient-transition"></div>
    </div>
    
    <!-- Kickstarter Campaign Section -->
    <section class="campaign-section">
        <div class="container">
            <div class="campaign-header">
                <h2 class="campaign-title">Support Synthesis</h2>
                <p class="campaign-subtitle">
                    Join thousands of creators in bringing the ultimate sandbox experience to life. 
                    Every pledge helps us expand the boundaries of what's possible.
                </p>
            </div>
            
            <div class="campaign-grid">
                <!-- Progress Column -->
                <div class="progress-column">
                    <KickstarterProgress {...campaignData} />
                    <CountdownTimer endDate={campaignData.endDate} />
                    
                    <!-- Press Quotes -->
                    <div class="press-quotes">
                        <blockquote>
                            "A revolutionary approach to creation games."
                            <cite>— PC Gamer</cite>
                        </blockquote>
                        <blockquote>
                            "Synthesis redefines what's possible in gaming."
                            <cite>— IGN</cite>
                        </blockquote>
                    </div>
                </div>
                
                <!-- Reward Tiers -->
                <div class="rewards-column">
                    <div class="rewards-grid">
                        {#each rewardTiers as tier}
                            <RewardTier 
                                {...tier} 
                                onClick={() => selectReward(tier)}
                            />
                        {/each}
                    </div>
                </div>
            </div>
        </div>
    </section>
    
    <!-- Game Features with seamless background -->
    <section class="features-section">
        <div class="features-container">
            <h2 class="section-title">Explore the Infinite</h2>
            <p class="section-subtitle">
                Every element, every creation, every world - yours to shape
            </p>
            <NewspaperGrid {articles} />
        </div>
    </section>
    
    <!-- Final CTA -->
    <section class="final-cta">
        <div class="cta-content">
            <h2 class="cta-title">Ready to Create Your Universe?</h2>
            <p class="cta-subtitle">
                Limited early bird rewards available. Join the synthesis revolution today.
            </p>
            <button class="btn-primary btn-hero">
                Back This Project
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M5 12H19M19 12L12 5M19 12L12 19" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
        </div>
    </section>
</main>

<style>
    /* Global container for seamless transitions */
    .seamless-container {
        position: relative;
        background: #000;
        overflow-x: hidden;
    }
    
    /* Hero wrapper with transition */
    .hero-wrapper {
        position: relative;
    }
    
    .hero-gradient-transition {
        position: absolute;
        bottom: -1px;
        left: 0;
        right: 0;
        height: 100px;
        background: linear-gradient(to bottom, transparent, rgba(99, 102, 241, 0.02));
        pointer-events: none;
        z-index: 1;
    }
    
    /* Campaign Section */
    .campaign-section {
        position: relative;
        padding: 2rem 2rem 6rem;
        margin-top: -50px;
        background: linear-gradient(180deg, 
            rgba(99, 102, 241, 0.02) 0%, 
            rgba(99, 102, 241, 0.05) 50%,
            rgba(99, 102, 241, 0.02) 100%);
    }
    
    .container {
        max-width: 1400px;
        margin: 0 auto;
    }
    
    .campaign-header {
        text-align: center;
        margin-bottom: 4rem;
    }
    
    .campaign-title {
        font-size: clamp(3rem, 5vw, 4rem);
        font-weight: 800;
        margin-bottom: 1rem;
        background: linear-gradient(135deg, #fff 0%, rgba(255, 255, 255, 0.8) 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }
    
    .campaign-subtitle {
        font-size: 1.5rem;
        color: rgba(255, 255, 255, 0.7);
        max-width: 700px;
        margin: 0 auto;
        line-height: 1.6;
    }
    
    .campaign-grid {
        display: grid;
        grid-template-columns: 380px 1fr;
        gap: 4rem;
        align-items: start;
    }
    
    .progress-column {
        position: sticky;
        top: 2rem;
        display: flex;
        flex-direction: column;
        gap: 2rem;
    }
    
    .press-quotes {
        margin-top: 3rem;
        padding: 2rem;
        background: rgba(255, 255, 255, 0.02);
        border-radius: 16px;
        border: 1px solid rgba(255, 255, 255, 0.05);
    }
    
    .press-quotes blockquote {
        font-size: 1.125rem;
        font-style: italic;
        color: rgba(255, 255, 255, 0.8);
        margin: 0 0 1rem 0;
        line-height: 1.5;
    }
    
    .press-quotes cite {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
        font-style: normal;
        display: block;
        margin-bottom: 1.5rem;
    }
    
    .press-quotes blockquote:last-of-type {
        margin-bottom: 0;
    }
    
    .press-quotes cite:last-of-type {
        margin-bottom: 0;
    }
    
    .rewards-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
        gap: 2rem;
    }
    
    /* Features Section with seamless background */
    .features-section {
        position: relative;
        padding: 6rem 2rem;
        background: linear-gradient(180deg,
            rgba(99, 102, 241, 0.02) 0%,
            rgba(0, 0, 0, 0.95) 20%,
            rgba(0, 0, 0, 0.95) 80%,
            rgba(99, 102, 241, 0.03) 100%);
    }
    
    .features-section::before {
        content: '';
        position: absolute;
        top: -50px;
        left: 0;
        right: 0;
        height: 50px;
        background: linear-gradient(to bottom, transparent, rgba(0, 0, 0, 0.5));
        pointer-events: none;
    }
    
    .features-container {
        position: relative;
        z-index: 1;
    }
    
    .section-title {
        font-size: clamp(2.5rem, 4vw, 3.5rem);
        font-weight: 800;
        text-align: center;
        margin-bottom: 1rem;
        letter-spacing: -0.02em;
    }
    
    .section-subtitle {
        font-size: 1.375rem;
        color: rgba(255, 255, 255, 0.6);
        text-align: center;
        margin-bottom: 4rem;
    }
    
    /* Final CTA */
    .final-cta {
        position: relative;
        padding: 8rem 2rem;
        background: radial-gradient(ellipse at center, rgba(99, 102, 241, 0.15) 0%, transparent 60%);
        text-align: center;
    }
    
    .cta-content {
        max-width: 800px;
        margin: 0 auto;
    }
    
    .cta-title {
        font-size: clamp(3rem, 5vw, 4rem);
        font-weight: 800;
        margin-bottom: 1.5rem;
        background: linear-gradient(135deg, 
            rgba(99, 102, 241, 1) 0%, 
            rgba(255, 255, 255, 1) 50%,
            rgba(99, 102, 241, 1) 100%);
        background-size: 200% 200%;
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        animation: gradient-shift 3s ease infinite;
    }
    
    @keyframes gradient-shift {
        0% { background-position: 0% 50%; }
        50% { background-position: 100% 50%; }
        100% { background-position: 0% 50%; }
    }
    
    .cta-subtitle {
        font-size: 1.5rem;
        color: rgba(255, 255, 255, 0.7);
        margin-bottom: 3rem;
    }
    
    .btn-hero {
        padding: 1.5rem 3rem;
        font-size: 1.25rem;
        gap: 1rem;
        transform: scale(1);
        transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    
    .btn-hero:hover {
        transform: scale(1.05);
        box-shadow: 0 10px 40px rgba(99, 102, 241, 0.4);
    }
    
    /* Responsive */
    @media (max-width: 1024px) {
        .campaign-grid {
            grid-template-columns: 1fr;
            gap: 3rem;
        }
        
        .progress-column {
            position: static;
            max-width: 500px;
            margin: 0 auto;
        }
    }
    
    @media (max-width: 768px) {
        .campaign-section,
        .features-section,
        .final-cta {
            padding: 3rem 1rem;
        }
        
        .rewards-grid {
            grid-template-columns: 1fr;
        }
    }
</style>