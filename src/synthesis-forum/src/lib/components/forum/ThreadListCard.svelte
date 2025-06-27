<script>
    let {
        id = "",
        title = "",
        author = "",
        authorRank = "Member",
        content = "",
        isPinned = false,
        isLocked = false,
        isHot = false,
        tags = [],
        stats = { replies: 0, views: 0, likes: 0 },
        createdAt = "",
        lastReply = null
    } = $props();
</script>

<article class="thread-card" class:pinned={isPinned} class:locked={isLocked} class:hot={isHot}>
    <div class="thread-header">
        <div class="thread-badges">
            {#if isPinned}
                <span class="badge pinned">📌 Pinned</span>
            {/if}
            {#if isLocked}
                <span class="badge locked">🔒 Locked</span>
            {/if}
            {#if isHot}
                <span class="badge hot">🔥 Hot</span>
            {/if}
        </div>
        <div class="thread-meta">
            <span class="created-at">{createdAt}</span>
        </div>
    </div>
    
    <div class="thread-main">
        <div class="thread-content">
            <h2 class="thread-title">
                <a href="/forum/thread/{id}">{title}</a>
            </h2>
            
            <div class="thread-preview">
                {content}
            </div>
            
            {#if tags.length > 0}
                <div class="thread-tags">
                    {#each tags as tag}
                        <span class="tag" style="background-color: {tag.color}20; border-color: {tag.color}">
                            {tag.name}
                        </span>
                    {/each}
                </div>
            {/if}
        </div>
        
        <div class="thread-sidebar">
            <div class="author-info">
                <div class="author-avatar">
                    {author.charAt(0).toUpperCase()}
                </div>
                <div class="author-details">
                    <a href="/user/{author}" class="author-name">{author}</a>
                    <span class="author-rank">{authorRank}</span>
                </div>
            </div>
            
            <div class="thread-stats">
                <div class="stat">
                    <span class="stat-icon">💬</span>
                    <span class="stat-value">{stats.replies}</span>
                    <span class="stat-label">Replies</span>
                </div>
                <div class="stat">
                    <span class="stat-icon">👁️</span>
                    <span class="stat-value">{stats.views}</span>
                    <span class="stat-label">Views</span>
                </div>
                <div class="stat">
                    <span class="stat-icon">❤️</span>
                    <span class="stat-value">{stats.likes}</span>
                    <span class="stat-label">Likes</span>
                </div>
            </div>
        </div>
    </div>
    
    {#if lastReply}
        <div class="last-reply">
            <div class="reply-content">
                <span class="reply-label">Latest reply by</span>
                <a href="/user/{lastReply.author}" class="reply-author">{lastReply.author}</a>
                <span class="reply-time">{lastReply.time}</span>
            </div>
            <div class="reply-preview">
                "{lastReply.content}"
            </div>
        </div>
    {/if}
</article>

<style>
    .thread-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        width: 100%;
        transition: all 0.3s ease;
        position: relative;
        overflow: hidden;
    }
    
    .thread-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
        border-color: rgba(99, 102, 241, 0.3);
    }
    
    .thread-card.pinned {
        border-color: rgba(239, 68, 68, 0.3);
        background: linear-gradient(135deg, rgba(239, 68, 68, 0.05), rgba(255, 255, 255, 0.02));
    }
    
    .thread-card.locked {
        opacity: 0.7;
    }
    
    .thread-card.hot::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle, rgba(239, 68, 68, 0.1) 0%, transparent 70%);
        animation: pulse 3s ease-in-out infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 0.5; }
        50% { opacity: 1; }
    }
    
    .thread-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1rem;
        flex-wrap: wrap;
        gap: 0.5rem;
    }
    
    .thread-badges {
        display: flex;
        gap: 0.5rem;
    }
    
    .badge {
        font-size: 0.75rem;
        padding: 0.25rem 0.5rem;
        border-radius: 4px;
        font-weight: 600;
        display: flex;
        align-items: center;
        gap: 0.25rem;
    }
    
    .badge.pinned {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
    }
    
    .badge.locked {
        background: rgba(156, 163, 175, 0.2);
        color: #9ca3af;
    }
    
    .badge.hot {
        background: rgba(251, 146, 60, 0.2);
        color: #fb923c;
    }
    
    .thread-meta {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .thread-main {
        display: grid;
        grid-template-columns: 1fr auto;
        gap: 2rem;
        align-items: start;
    }
    
    @media (max-width: 768px) {
        .thread-main {
            grid-template-columns: 1fr;
            gap: 1rem;
        }
        
        .thread-sidebar {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
    }
    
    .thread-title {
        font-size: 1.25rem;
        font-weight: 700;
        margin: 0 0 0.75rem 0;
        line-height: 1.4;
    }
    
    .thread-title a {
        color: rgba(255, 255, 255, 0.95);
        text-decoration: none;
        transition: color 0.2s;
    }
    
    .thread-title a:hover {
        color: rgba(99, 102, 241, 0.9);
    }
    
    .thread-preview {
        font-size: 0.9375rem;
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.7);
        margin-bottom: 1rem;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }
    
    .thread-tags {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
    }
    
    .tag {
        font-size: 0.75rem;
        padding: 0.25rem 0.75rem;
        border-radius: 9999px;
        border: 1px solid;
        font-weight: 500;
    }
    
    .thread-sidebar {
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
        min-width: 200px;
    }
    
    .author-info {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }
    
    .author-avatar {
        width: 40px;
        height: 40px;
        border-radius: 8px;
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 700;
        font-size: 1.125rem;
        color: white;
    }
    
    .author-details {
        display: flex;
        flex-direction: column;
    }
    
    .author-name {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        font-weight: 600;
        font-size: 0.9375rem;
    }
    
    .author-name:hover {
        text-decoration: underline;
    }
    
    .author-rank {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .thread-stats {
        display: flex;
        gap: 1rem;
    }
    
    .stat {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 0.25rem;
    }
    
    .stat-icon {
        font-size: 1.125rem;
    }
    
    .stat-value {
        font-size: 0.875rem;
        font-weight: 700;
        color: rgba(255, 255, 255, 0.9);
    }
    
    .stat-label {
        font-size: 0.625rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .last-reply {
        margin-top: 1rem;
        padding-top: 1rem;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
    }
    
    .reply-content {
        font-size: 0.8125rem;
        color: rgba(255, 255, 255, 0.6);
        margin-bottom: 0.5rem;
    }
    
    .reply-author {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        font-weight: 500;
        margin: 0 0.25rem;
    }
    
    .reply-author:hover {
        text-decoration: underline;
    }
    
    .reply-time {
        margin-left: 0.25rem;
    }
    
    .reply-preview {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.7);
        font-style: italic;
        display: -webkit-box;
        -webkit-line-clamp: 1;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }
</style>