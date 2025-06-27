<script>
    let {
        username = "User",
        avatar = null,
        rank = "Member",
        joinDate = "2024",
        postCount = 0,
        reputation = 0,
        status = "offline",
        bio = "",
        badges = [],
        isOnline = false
    } = $props();
</script>

<div class="user-card">
    <div class="user-header">
        <div class="avatar-container">
            {#if avatar}
                <img src={avatar} alt={username} class="user-avatar" />
            {:else}
                <div class="user-avatar-placeholder">
                    {username.slice(0, 2).toUpperCase()}
                </div>
            {/if}
            {#if isOnline}
                <div class="online-indicator"></div>
            {/if}
        </div>
        
        <div class="user-info">
            <h3 class="username">{username}</h3>
            <div class="user-rank">{rank}</div>
        </div>
    </div>
    
    {#if bio}
        <p class="user-bio">{bio}</p>
    {/if}
    
    <div class="user-stats">
        <div class="stat">
            <span class="stat-value">{postCount.toLocaleString()}</span>
            <span class="stat-label">Posts</span>
        </div>
        <div class="stat">
            <span class="stat-value">{reputation.toLocaleString()}</span>
            <span class="stat-label">Rep</span>
        </div>
        <div class="stat">
            <span class="stat-value">{joinDate}</span>
            <span class="stat-label">Joined</span>
        </div>
    </div>
    
    {#if badges.length > 0}
        <div class="user-badges">
            {#each badges as badge}
                <span class="badge" title={badge.description}>
                    {badge.icon}
                </span>
            {/each}
        </div>
    {/if}
    
    <div class="user-actions">
        <button class="action-btn primary">View Profile</button>
        <button class="action-btn">Send Message</button>
    </div>
</div>

<style>
    .user-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        display: flex;
        flex-direction: column;
        gap: 1rem;
        height: 100%;
        transition: all 0.3s ease;
    }
    
    .user-card:hover {
        border-color: rgba(99, 102, 241, 0.3);
        box-shadow: 0 8px 32px rgba(99, 102, 241, 0.1);
        transform: translateY(-2px);
    }
    
    .user-header {
        display: flex;
        align-items: center;
        gap: 1rem;
    }
    
    .avatar-container {
        position: relative;
    }
    
    .user-avatar {
        width: 64px;
        height: 64px;
        border-radius: 50%;
        object-fit: cover;
        border: 2px solid rgba(99, 102, 241, 0.3);
    }
    
    .user-avatar-placeholder {
        width: 64px;
        height: 64px;
        border-radius: 50%;
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        display: flex;
        align-items: center;
        justify-content: center;
        font-weight: 700;
        font-size: 1.25rem;
        color: white;
        border: 2px solid rgba(99, 102, 241, 0.3);
    }
    
    .online-indicator {
        position: absolute;
        bottom: 2px;
        right: 2px;
        width: 16px;
        height: 16px;
        background: #10b981;
        border-radius: 50%;
        border: 2px solid #000;
        animation: pulse-online 2s infinite;
    }
    
    @keyframes pulse-online {
        0%, 100% { transform: scale(1); opacity: 1; }
        50% { transform: scale(1.1); opacity: 0.8; }
    }
    
    .user-info {
        flex: 1;
    }
    
    .username {
        font-size: 1.25rem;
        font-weight: 700;
        margin: 0 0 0.25rem 0;
        color: rgba(255, 255, 255, 0.95);
    }
    
    .user-rank {
        font-size: 0.875rem;
        color: rgba(147, 51, 234, 0.9);
        font-weight: 500;
    }
    
    .user-bio {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.7);
        line-height: 1.5;
        margin: 0;
    }
    
    .user-stats {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 1rem;
        padding: 1rem;
        background: rgba(0, 0, 0, 0.2);
        border-radius: 8px;
    }
    
    .stat {
        text-align: center;
    }
    
    .stat-value {
        display: block;
        font-size: 1.25rem;
        font-weight: 700;
        color: rgba(99, 102, 241, 0.9);
    }
    
    .stat-label {
        display: block;
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-top: 0.25rem;
    }
    
    .user-badges {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
    }
    
    .badge {
        font-size: 1.5rem;
        cursor: help;
        filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2));
        transition: transform 0.2s;
    }
    
    .badge:hover {
        transform: scale(1.2);
    }
    
    .user-actions {
        display: flex;
        gap: 0.75rem;
        margin-top: auto;
    }
    
    .action-btn {
        flex: 1;
        padding: 0.75rem 1rem;
        border-radius: 8px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        background: rgba(255, 255, 255, 0.05);
        color: rgba(255, 255, 255, 0.9);
        font-weight: 500;
        cursor: pointer;
        transition: all 0.2s;
        font-size: 0.875rem;
    }
    
    .action-btn:hover {
        background: rgba(255, 255, 255, 0.1);
        border-color: rgba(255, 255, 255, 0.2);
    }
    
    .action-btn.primary {
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        border-color: transparent;
        color: white;
    }
    
    .action-btn.primary:hover {
        background: linear-gradient(135deg, #4f46e5, #7c3aed);
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
    }
</style>