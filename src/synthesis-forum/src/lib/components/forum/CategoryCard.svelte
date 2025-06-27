<script>
    let {
        title = "General Discussion",
        description = "Talk about anything and everything",
        icon = "💬",
        threadCount = 0,
        postCount = 0,
        latestPost = null,
        moderators = [],
        isLocked = false,
        isSticky = false,
        isExpanded = false,
        subcategories = []
    } = $props();
</script>

<div class="category-card" class:expanded={isExpanded}>
    <div class="category-header">
        <div class="category-icon">{icon}</div>
        <div class="category-info">
            <h3 class="category-title">
                {#if isSticky}
                    <span class="sticky-badge">📌</span>
                {/if}
                {#if isLocked}
                    <span class="locked-badge">🔒</span>
                {/if}
                {title}
            </h3>
            <p class="category-description">{description}</p>
            
            {#if subcategories.length > 0}
                <div class="subcategories">
                    <span class="sub-label">Sub-forums:</span>
                    {#each subcategories as sub}
                        <a href="/forum/{sub.slug}" class="subcategory-link">{sub.name}</a>
                    {/each}
                </div>
            {/if}
        </div>
    </div>
    
    <div class="category-stats">
        <div class="stat">
            <span class="stat-value">{threadCount.toLocaleString()}</span>
            <span class="stat-label">Threads</span>
        </div>
        <div class="stat">
            <span class="stat-value">{postCount.toLocaleString()}</span>
            <span class="stat-label">Posts</span>
        </div>
    </div>
    
    {#if latestPost}
        <div class="latest-post">
            <div class="latest-label">Latest Post:</div>
            <a href="/forum/thread/{latestPost.id}" class="latest-thread">{latestPost.title}</a>
            <div class="latest-meta">
                by <a href="/user/{latestPost.author}" class="author-link">{latestPost.author}</a>
                <span class="post-time">{latestPost.time}</span>
            </div>
        </div>
    {/if}
    
    {#if moderators.length > 0}
        <div class="moderators">
            <span class="mod-label">Moderated by:</span>
            {#each moderators as mod}
                <a href="/user/{mod}" class="mod-link">{mod}</a>
            {/each}
        </div>
    {/if}
</div>

<style>
    .category-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        transition: all 0.3s ease;
        height: 100%;
        display: flex;
        flex-direction: column;
        gap: 1rem;
        backdrop-filter: blur(10px);
    }
    
    .category-card.expanded {
        background: linear-gradient(135deg, rgba(99, 102, 241, 0.1), rgba(139, 92, 246, 0.05));
        border-color: rgba(99, 102, 241, 0.3);
    }
    
    .category-card:hover {
        border-color: rgba(99, 102, 241, 0.3);
        box-shadow: 0 8px 32px rgba(99, 102, 241, 0.1);
        transform: translateY(-2px);
    }
    
    .category-header {
        display: flex;
        gap: 1rem;
        align-items: start;
    }
    
    .category-icon {
        font-size: 2.5rem;
        line-height: 1;
        filter: grayscale(20%);
    }
    
    .category-info {
        flex: 1;
    }
    
    .category-title {
        font-size: 1.25rem;
        font-weight: 700;
        margin: 0 0 0.5rem 0;
        color: rgba(255, 255, 255, 0.95);
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .sticky-badge, .locked-badge {
        font-size: 1rem;
        opacity: 0.8;
    }
    
    .category-description {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.7);
        margin: 0;
        line-height: 1.5;
    }
    
    .subcategories {
        margin-top: 0.75rem;
        font-size: 0.8125rem;
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
        align-items: center;
    }
    
    .sub-label {
        color: rgba(255, 255, 255, 0.5);
        margin-right: 0.25rem;
    }
    
    .subcategory-link {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        transition: color 0.2s;
    }
    
    .subcategory-link:hover {
        color: rgba(99, 102, 241, 1);
        text-decoration: underline;
    }
    
    .subcategory-link:not(:last-child)::after {
        content: "•";
        margin: 0 0.25rem;
        color: rgba(255, 255, 255, 0.3);
    }
    
    .category-stats {
        display: flex;
        gap: 2rem;
        padding: 1rem;
        background: rgba(0, 0, 0, 0.2);
        border-radius: 8px;
    }
    
    .stat {
        display: flex;
        flex-direction: column;
        align-items: center;
    }
    
    .stat-value {
        font-size: 1.5rem;
        font-weight: 700;
        color: rgba(99, 102, 241, 0.9);
    }
    
    .stat-label {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .latest-post {
        padding: 1rem;
        background: rgba(99, 102, 241, 0.05);
        border-radius: 8px;
        border: 1px solid rgba(99, 102, 241, 0.1);
    }
    
    .latest-label {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.5);
        margin-bottom: 0.25rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .latest-thread {
        color: rgba(255, 255, 255, 0.9);
        text-decoration: none;
        font-weight: 600;
        display: block;
        margin-bottom: 0.5rem;
        transition: color 0.2s;
    }
    
    .latest-thread:hover {
        color: rgba(99, 102, 241, 0.9);
    }
    
    .latest-meta {
        font-size: 0.8125rem;
        color: rgba(255, 255, 255, 0.6);
    }
    
    .author-link {
        color: rgba(99, 102, 241, 0.8);
        text-decoration: none;
        font-weight: 500;
    }
    
    .author-link:hover {
        text-decoration: underline;
    }
    
    .post-time {
        margin-left: 0.5rem;
        color: rgba(255, 255, 255, 0.4);
    }
    
    .moderators {
        font-size: 0.8125rem;
        color: rgba(255, 255, 255, 0.6);
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
        align-items: center;
        margin-top: auto;
    }
    
    .mod-label {
        color: rgba(255, 255, 255, 0.4);
    }
    
    .mod-link {
        color: rgba(147, 51, 234, 0.9);
        text-decoration: none;
        font-weight: 500;
    }
    
    .mod-link:hover {
        text-decoration: underline;
    }
    
    .mod-link:not(:last-child)::after {
        content: ",";
        margin-right: 0.25rem;
    }
</style>