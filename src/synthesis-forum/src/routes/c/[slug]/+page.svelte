<script>
    import { page } from '$app/stores';
    import NavigationCard from '$lib/components/forum/NavigationCard.svelte';
    import AnnouncementCard from '$lib/components/forum/AnnouncementCard.svelte';
    import CategoryCard from '$lib/components/forum/CategoryCard.svelte';
    import ThreadListCard from '$lib/components/forum/ThreadListCard.svelte';
    import PaginationCard from '$lib/components/forum/PaginationCard.svelte';
    
    // Get category from URL
    $: categorySlug = $page.params.slug;
    
    // Mock category data (would come from database)
    const categoryData = {
        title: "💬 General Discussion",
        description: "Chat about anything and everything",
        icon: "💬",
        threadCount: 1234,
        postCount: 15678,
        moderators: ["CommunityMod", "Helper"],
        subcategories: [
            { name: "Introductions", slug: "introductions" },
            { name: "Off-Topic", slug: "off-topic" },
            { name: "Random", slug: "random" }
        ]
    };
    
    // Mock thread data
    const threads = [
        {
            id: "thread1",
            title: "Welcome to the General Discussion forum!",
            author: "Admin",
            authorRank: "Administrator",
            content: "This is your space to discuss anything and everything. Please be respectful and follow our community guidelines. Let's have great conversations!",
            isPinned: true,
            isLocked: false,
            isHot: true,
            tags: [
                { name: "Pinned", color: "#ef4444" },
                { name: "Rules", color: "#6366f1" }
            ],
            stats: {
                replies: 234,
                views: 5678,
                likes: 123
            },
            createdAt: "Dec 1, 2023",
            lastReply: {
                author: "NewUser",
                content: "Thanks for the welcome! Excited to be here.",
                time: "2 hours ago"
            }
        },
        {
            id: "thread2",
            title: "What are you playing this weekend?",
            author: "GamerDude",
            authorRank: "Elite Member",
            content: "Hey everyone! The weekend is coming up and I'm looking for some game recommendations. What are you all planning to play? I just finished Baldur's Gate 3 and need something new...",
            isPinned: false,
            isLocked: false,
            isHot: true,
            tags: [
                { name: "Gaming", color: "#10b981" },
                { name: "Discussion", color: "#6366f1" }
            ],
            stats: {
                replies: 89,
                views: 1234,
                likes: 45
            },
            createdAt: "Today at 2:30 PM",
            lastReply: {
                author: "RPGFan",
                content: "You should definitely try Divinity Original Sin 2!",
                time: "5 minutes ago"
            }
        },
        {
            id: "thread3",
            title: "The official 'Post your setup' thread",
            author: "TechGuru",
            authorRank: "Moderator",
            content: "Show off your gaming/work setup! Post pictures of your battlestation, specs, and any cool peripherals you're using. I'll start with mine...",
            isPinned: false,
            isLocked: false,
            isHot: false,
            tags: [
                { name: "Showcase", color: "#f59e0b" },
                { name: "Hardware", color: "#8b5cf6" }
            ],
            stats: {
                replies: 156,
                views: 3456,
                likes: 89
            },
            createdAt: "Yesterday at 5:45 PM",
            lastReply: {
                author: "RGBMaster",
                content: "Nice setup! Here's mine with custom lighting...",
                time: "1 hour ago"
            }
        },
        {
            id: "thread4",
            title: "Anyone else excited for the new season?",
            author: "TVFanatic",
            authorRank: "Member",
            content: "The new season of my favorite show is starting next week! Who else is hyped? No spoilers from the books please!",
            isPinned: false,
            isLocked: false,
            isHot: false,
            tags: [
                { name: "TV Shows", color: "#ec4899" },
                { name: "Entertainment", color: "#6366f1" }
            ],
            stats: {
                replies: 34,
                views: 678,
                likes: 12
            },
            createdAt: "2 days ago",
            lastReply: {
                author: "BingeWatcher",
                content: "Can't wait! I've been rewatching the previous seasons.",
                time: "3 hours ago"
            }
        },
        {
            id: "thread5",
            title: "Daily random discussion thread",
            author: "AutoModerator",
            authorRank: "Bot",
            content: "This is your daily thread for random discussions, quick questions, and casual chat. What's on your mind today?",
            isPinned: false,
            isLocked: false,
            isHot: false,
            tags: [
                { name: "Daily", color: "#06b6d4" },
                { name: "Automated", color: "#6b7280" }
            ],
            stats: {
                replies: 67,
                views: 890,
                likes: 23
            },
            createdAt: "Today at 12:00 AM",
            lastReply: {
                author: "EarlyBird",
                content: "Good morning everyone! Coffee time ☕",
                time: "30 minutes ago"
            }
        }
    ];
    
    // Breadcrumb navigation
    const breadcrumb = [
        { name: categoryData.title, url: `/c/${categorySlug}` }
    ];
</script>

<main class="category-container">
    <!-- Navigation -->
    <NavigationCard 
        currentPath={breadcrumb}
        quickLinks={[
            { icon: "➕", name: "New Thread", url: `/c/${categorySlug}/new` },
            { icon: "🔍", name: "Search", url: `/c/${categorySlug}/search` },
            { icon: "📊", name: "Stats", url: `/c/${categorySlug}/stats` }
        ]}
    />
    
    <!-- Category Header -->
    <div class="category-header-wrapper">
        <CategoryCard
            title={categoryData.title}
            description={categoryData.description}
            icon={categoryData.icon}
            threadCount={categoryData.threadCount}
            postCount={categoryData.postCount}
            moderators={categoryData.moderators}
            subcategories={categoryData.subcategories}
            isExpanded={true}
        />
    </div>
    
    <!-- Pinned Announcement -->
    <AnnouncementCard
        title="Category Guidelines"
        content="<p>Welcome to General Discussion! This is a place for friendly conversation about any topic. Please keep discussions civil and follow our <a href='/rules'>community guidelines</a>.</p>"
        author="CommunityMod"
        date="Pinned"
        type="info"
        icon="📌"
    />
    
    <!-- Thread List -->
    <div class="threads-container">
        {#each threads as thread}
            <ThreadListCard {...thread} />
        {/each}
    </div>
    
    <!-- Pagination -->
    <PaginationCard
        currentPage={1}
        totalPages={25}
        totalItems={1234}
        itemsPerPage={50}
        baseUrl={`/c/${categorySlug}`}
    />
</main>

<style>
    .category-container {
        min-height: 100vh;
        background: linear-gradient(180deg, 
            rgba(0, 0, 0, 0.9) 0%, 
            rgba(0, 0, 0, 0.95) 50%,
            rgba(0, 0, 0, 0.9) 100%);
        padding: 2rem;
        max-width: 1200px;
        margin: 0 auto;
    }
    
    @media (max-width: 768px) {
        .category-container {
            padding: 1rem;
        }
    }
    
    .category-header-wrapper {
        margin-bottom: 1.5rem;
    }
    
    .threads-container {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        margin-bottom: 2rem;
    }
    
    :global(body) {
        background: #000;
        color: #fff;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>