<script>
    let {
        id,
        title = "Thread Title",
        author = "Anonymous",
        authorAvatar = null,
        authorRank = "Member",
        preview = "",
        replyCount = 0,
        viewCount = 0,
        lastReply = null,
        tags = [],
        isPinned = false,
        isLocked = false,
        isHot = false,
        isUnread = false,
        attachments = 0,
        createdAt = "Just now"
    } = $props();
</script>

<div class="thread-card" class:unread={isUnread}>
    <div class="thread-status">
        {#if isPinned}
            <span class="status-icon pinned" title="Pinned">📌</span>
        {/if}
        {#if isLocked}
            <span class="status-icon locked" title="Locked">🔒</span>
        {/if}
        {#if isHot}
            <span class="status-icon hot" title="Hot Topic">🔥</span>
        {/if}
        {#if attachments > 0}
            <span class="status-icon attachment" title="{attachments} Attachments">📎</span>
        {/if}
    </div>
    
    <div class="thread-main">
        <div class="thread-header">
            <h3 class="thread-title">
                <a href="/forum/thread/{id}">{title}</a>
            </h3>
            {#if tags.length > 0}
                <div class="thread-tags">
                    {#each tags as tag}
                        <span class="tag" style="background: {tag.color}20; border-color: {tag.color}40">
                            {tag.name}
                        </span>
                    {/each}
                </div>
            {/if}
        </div>
        
        {#if preview}
            <p class="thread-preview">{preview}</p>
        {/if}
        
        <div class="thread-meta">
            <div class="author-info">
                {#if authorAvatar}
                    <img src={authorAvatar} alt={author} class="author-avatar" />
                {:else}
                    <div class="author-avatar-placeholder">
                        {author.charAt(0).toUpperCase()}
                    </div>
                {/if}
                <div>
                    <a href="/user/{author}" class="author-name">{author}</a>
                    <span class="author-rank">{authorRank}</span>
                </div>
            </div>
            <span class="created-time">{createdAt}</span>
        </div>
    </div>
    
    <div class="thread-stats">
        <div class="stat-item">
            <span class="stat-number">{replyCount}</span>
            <span class="stat-label">Replies</span>
        </div>
        <div class="stat-item">
            <span class="stat-number">{viewCount}</span>
            <span class="stat-label">Views</span>
        </div>
    </div>
    
    {#if lastReply}
        <div class="last-reply">
            <div class="reply-label">Last Reply</div>
            <div class="reply-info">
                <a href="/user/{lastReply.author}" class="reply-author">{lastReply.author}</a>
                <span class="reply-time">{lastReply.time}</span>
            </div>
        </div>
    {/if}
</div>

<style>
    .thread-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.25rem;
        transition: all 0.3s ease;
        display: grid;
        grid-template-columns: auto 1fr auto auto;
        gap: 1rem;
        align-items: start;
        backdrop-filter: blur(10px);
        position: relative;
        overflow: hidden;
    }
    
    .thread-card.unread::before {
        content: '';
        position: absolute;
        left: 0;
        top: 0;
        bottom: 0;
        width: 3px;
        background: linear-gradient(180deg, #6366f1, #8b5cf6);
    }
    
    .thread-card:hover {
        border-color: rgba(99, 102, 241, 0.3);
        box-shadow: 0 4px 24px rgba(99, 102, 241, 0.1);
        transform: translateY(-1px);
    }
    
    .thread-status {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
        align-items: center;
    }
    
    .status-icon {
        font-size: 1.25rem;
        opacity: 0.8;
        cursor: help;
    }
    
    .status-icon.hot {
        animation: pulse 2s infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 0.8; }
        50% { opacity: 1; }
    }
    
    .thread-main {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
        min-width: 0;
    }
    
    .thread-header {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }
    
    .thread-title {
        font-size: 1.125rem;
        font-weight: 600;
        margin: 0;
        line-height: 1.3;
    }
    
    .thread-title a {
        color: rgba(255, 255, 255, 0.95);
        text-decoration: none;
        transition: color 0.2s;
    }
    
    .thread-title a:hover {
        color: rgba(99, 102, 241, 0.9);
    }
    
    .thread-tags {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
    }
    
    .tag {
        font-size: 0.75rem;
        padding: 0.125rem 0.5rem;
        border-radius: 9999px;
        border: 1px solid;
        font-weight: 500;
    }
    
    .thread-preview {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.6);
        margin: 0;
        line-height: 1.5;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
    }
    
    .thread-meta {
        display: flex;
        align-items: center;
        gap: 1rem;
        font-size: 0.8125rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .author-info {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .author-avatar {
        width: 24px;
        height: 24px;
        border-radius: 50%;
        object-fit: cover;
    }
    
    .author-avatar-placeholder {
        width: 24px;
        height: 24px;
        border-radius: 50%;
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 0.75rem;
        font-weight: 600;
        color: white;
    }
    
    .author-name {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        font-weight: 500;
    }
    
    .author-name:hover {
        text-decoration: underline;
    }
    
    .author-rank {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.4);
        margin-left: 0.25rem;
    }
    
    .thread-stats {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
        align-items: center;
        padding: 0 1rem;
    }
    
    .stat-item {
        display: flex;
        flex-direction: column;
        align-items: center;
    }
    
    .stat-number {
        font-size: 1.125rem;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.9);
    }
    
    .stat-label {
        font-size: 0.6875rem;
        color: rgba(255, 255, 255, 0.4);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .last-reply {
        padding: 0.75rem;
        background: rgba(0, 0, 0, 0.2);
        border-radius: 8px;
        font-size: 0.8125rem;
    }
    
    .reply-label {
        font-size: 0.6875rem;
        color: rgba(255, 255, 255, 0.4);
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-bottom: 0.25rem;
    }
    
    .reply-author {
        color: rgba(99, 102, 241, 0.8);
        text-decoration: none;
        font-weight: 500;
    }
    
    .reply-author:hover {
        text-decoration: underline;
    }
    
    .reply-time {
        display: block;
        color: rgba(255, 255, 255, 0.4);
        font-size: 0.75rem;
        margin-top: 0.125rem;
    }
    
    /* Responsive adjustments */
    @media (max-width: 768px) {
        .thread-card {
            grid-template-columns: 1fr;
            gap: 0.75rem;
        }
        
        .thread-status {
            flex-direction: row;
            position: absolute;
            top: 1rem;
            right: 1rem;
        }
        
        .thread-stats {
            flex-direction: row;
            gap: 2rem;
            padding: 0.75rem;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 8px;
        }
        
        .last-reply {
            display: none;
        }
    }
</style>