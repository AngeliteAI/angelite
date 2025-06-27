<script>
    import { NewspaperGrid } from 'synthesis-ui';
    import CategoryCard from '$lib/components/forum/CategoryCard.svelte';
    import StatsCard from '$lib/components/forum/StatsCard.svelte';
    import OnlineUsersCard from '$lib/components/forum/OnlineUsersCard.svelte';
    import UserCard from '$lib/components/forum/UserCard.svelte';
    import AnnouncementCard from '$lib/components/forum/AnnouncementCard.svelte';
    import NavigationCard from '$lib/components/forum/NavigationCard.svelte';
    import ThreadCard from '$lib/components/forum/ThreadCard.svelte';
    
    // Forum data
    const forumCategories = [
        {
            component: CategoryCard,
            props: {
                title: "📢 Announcements & News",
                description: "Official announcements, updates, and important information",
                icon: "📢",
                threadCount: 42,
                postCount: 156,
                isSticky: true,
                latestPost: {
                    id: "123",
                    title: "Forum Rules Updated - Please Read",
                    author: "Admin",
                    time: "2 hours ago"
                },
                moderators: ["Admin", "ModeratorX"],
                subcategories: [
                    { name: "Rules & Guidelines", slug: "rules" },
                    { name: "Site News", slug: "news" }
                ]
            },
            size: { cols: 3, rows: 1 },
            priority: 1
        },
        {
            component: CategoryCard,
            props: {
                title: "💬 General Discussion",
                description: "Chat about anything and everything",
                icon: "💬",
                threadCount: 1234,
                postCount: 15678,
                latestPost: {
                    id: "456",
                    title: "What are you playing this weekend?",
                    author: "GamerDude",
                    time: "5 minutes ago"
                },
                moderators: ["CommunityMod", "Helper"]
            },
            size: { cols: 2, rows: 1 },
            priority: 2
        },
        {
            component: CategoryCard,
            props: {
                title: "🎮 Gaming",
                description: "Discuss your favorite games, share tips, and find teammates",
                icon: "🎮",
                threadCount: 892,
                postCount: 9234,
                latestPost: {
                    id: "789",
                    title: "Best RPGs of 2024?",
                    author: "RPGFan",
                    time: "15 minutes ago"
                },
                subcategories: [
                    { name: "PC Gaming", slug: "pc-gaming" },
                    { name: "Console Gaming", slug: "console" },
                    { name: "Mobile Gaming", slug: "mobile" }
                ]
            },
            size: { cols: 2, rows: 1 },
            priority: 2
        },
        {
            component: CategoryCard,
            props: {
                title: "💻 Tech Support",
                description: "Get help with technical issues and troubleshooting",
                icon: "💻",
                threadCount: 567,
                postCount: 4321,
                latestPost: {
                    id: "321",
                    title: "GPU not detected - help!",
                    author: "TechNoob",
                    time: "1 hour ago"
                }
            },
            size: { cols: 1, rows: 1 },
            priority: 3
        },
        {
            component: CategoryCard,
            props: {
                title: "🎨 Creative Corner",
                description: "Share your art, writing, music, and other creative works",
                icon: "🎨",
                threadCount: 345,
                postCount: 2890,
                latestPost: {
                    id: "654",
                    title: "My latest digital painting",
                    author: "ArtistPro",
                    time: "3 hours ago"
                }
            },
            size: { cols: 1, rows: 1 },
            priority: 3
        },
        {
            component: CategoryCard,
            props: {
                title: "🛒 Marketplace",
                description: "Buy, sell, and trade with other members",
                icon: "🛒",
                threadCount: 234,
                postCount: 1567,
                isLocked: false,
                latestPost: {
                    id: "987",
                    title: "[WTS] Gaming Laptop",
                    author: "Seller123",
                    time: "30 minutes ago"
                }
            },
            size: { cols: 1, rows: 1 },
            priority: 3
        },
        {
            component: StatsCard,
            props: {
                totalUsers: 15234,
                totalThreads: 3456,
                totalPosts: 45678,
                onlineUsers: 234,
                newestMember: "NewUser2024",
                mostOnline: { count: 567, date: "Dec 25, 2023" }
            },
            size: { cols: 1, rows: 1 },
            priority: 4
        },
        {
            component: OnlineUsersCard,
            props: {
                users: [
                    { username: "Admin", color: "#ef4444" },
                    { username: "ModeratorX", color: "#8b5cf6" },
                    { username: "VIPUser", color: "#f59e0b" },
                    { username: "User123", color: "#6366f1" },
                    { username: "GamerDude", color: "#6366f1" },
                    { username: "TechGuru", color: "#6366f1" }
                ],
                totalOnline: 234,
                guests: 156,
                bots: ["GoogleBot", "BingBot"]
            },
            size: { cols: 2, rows: 1 },
            priority: 4
        }
    ];
    
    // Recent hot threads
    const hotThreads = [
        {
            component: ThreadCard,
            props: {
                id: "hot1",
                title: "🔥 Major Update Coming Next Week!",
                author: "DevTeam",
                authorRank: "Developer",
                preview: "We're excited to announce a major update coming next week with tons of new features...",
                replyCount: 234,
                viewCount: 5678,
                isHot: true,
                isPinned: true,
                tags: [
                    { name: "Official", color: "#ef4444" },
                    { name: "Update", color: "#6366f1" }
                ],
                lastReply: {
                    author: "ExcitedUser",
                    time: "2 minutes ago"
                },
                createdAt: "3 days ago"
            },
            size: { cols: 2, rows: 1 },
            priority: 2
        },
        {
            component: ThreadCard,
            props: {
                id: "hot2",
                title: "Community Event: Holiday Giveaway!",
                author: "CommunityManager",
                authorRank: "Staff",
                preview: "Join our holiday giveaway event! We're giving away premium memberships, games, and more...",
                replyCount: 567,
                viewCount: 8901,
                isHot: true,
                tags: [
                    { name: "Event", color: "#10b981" },
                    { name: "Giveaway", color: "#f59e0b" }
                ],
                lastReply: {
                    author: "LuckyWinner",
                    time: "15 minutes ago"
                },
                createdAt: "1 week ago"
            },
            size: { cols: 1, rows: 1 },
            priority: 3
        }
    ];
    
    // Top contributors
    const topUsers = [
        {
            component: UserCard,
            props: {
                username: "TechGuru",
                rank: "Elite Member",
                joinDate: "2020",
                postCount: 5432,
                reputation: 1234,
                bio: "Tech enthusiast, gamer, and forum regular",
                isOnline: true,
                badges: [
                    { icon: "🏆", description: "Top Contributor" },
                    { icon: "⭐", description: "5 Year Member" },
                    { icon: "💎", description: "Premium Member" }
                ]
            },
            size: { cols: 1, rows: 1 },
            priority: 4
        },
        {
            component: UserCard,
            props: {
                username: "HelpfulHero",
                rank: "Moderator",
                joinDate: "2019",
                postCount: 8765,
                reputation: 2345,
                bio: "Here to help! Feel free to ask me anything.",
                isOnline: false,
                badges: [
                    { icon: "🛡️", description: "Moderator" },
                    { icon: "🎖️", description: "Helper Badge" },
                    { icon: "📚", description: "Wiki Contributor" }
                ]
            },
            size: { cols: 1, rows: 1 },
            priority: 4
        }
    ];
    
    // Combine all content for the grid
    const gridContent = [
        ...forumCategories,
        ...hotThreads,
        ...topUsers
    ];
</script>

<main class="forum-container">
    <!-- Full-width navigation card -->
    <NavigationCard 
        currentPath={[]}
        quickLinks={[
            { icon: "🔍", name: "Search", url: "/forum/search" },
            { icon: "📋", name: "New Posts", url: "/forum/new" },
            { icon: "👤", name: "Members", url: "/forum/members" },
            { icon: "📊", name: "Statistics", url: "/forum/stats" }
        ]}
    />
    
    <!-- Full-width announcement -->
    <AnnouncementCard
        title="Welcome to Synthesis Forum!"
        content="<p>Welcome to our retro-styled forum! Please take a moment to read our <a href='/forum/rules'>community guidelines</a> and introduce yourself in the <a href='/forum/introductions'>introductions section</a>.</p><p>Happy posting! 🎉</p>"
        author="Admin"
        date="Pinned"
        type="info"
        icon="🎊"
    />
    
    <!-- Main grid content -->
    <div class="grid-wrapper">
        <NewspaperGrid articles={gridContent} />
    </div>
</main>

<style>
    .forum-container {
        min-height: 100vh;
        background: linear-gradient(180deg, 
            rgba(0, 0, 0, 0.9) 0%, 
            rgba(0, 0, 0, 0.95) 50%,
            rgba(0, 0, 0, 0.9) 100%);
        padding: 2rem;
    }
    
    @media (max-width: 768px) {
        .forum-container {
            padding: 1rem;
        }
    }
    
    .grid-wrapper {
        margin-top: 2rem;
    }
    
    :global(body) {
        background: #000;
        color: #fff;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>