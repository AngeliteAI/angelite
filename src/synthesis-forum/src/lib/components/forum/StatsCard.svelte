<script>
    let {
        totalUsers = 0,
        totalThreads = 0,
        totalPosts = 0,
        onlineUsers = 0,
        newestMember = null,
        mostOnline = { count: 0, date: "" }
    } = $props();
</script>

<div class="stats-card">
    <h3 class="stats-title">📊 Forum Statistics</h3>
    
    <div class="stats-grid">
        <div class="stat-item">
            <span class="stat-icon">👥</span>
            <div class="stat-content">
                <span class="stat-value">{totalUsers.toLocaleString()}</span>
                <span class="stat-label">Total Members</span>
            </div>
        </div>
        
        <div class="stat-item">
            <span class="stat-icon">💬</span>
            <div class="stat-content">
                <span class="stat-value">{totalThreads.toLocaleString()}</span>
                <span class="stat-label">Threads</span>
            </div>
        </div>
        
        <div class="stat-item">
            <span class="stat-icon">📝</span>
            <div class="stat-content">
                <span class="stat-value">{totalPosts.toLocaleString()}</span>
                <span class="stat-label">Posts</span>
            </div>
        </div>
        
        <div class="stat-item">
            <span class="stat-icon">🟢</span>
            <div class="stat-content">
                <span class="stat-value">{onlineUsers.toLocaleString()}</span>
                <span class="stat-label">Online Now</span>
            </div>
        </div>
    </div>
    
    {#if newestMember}
        <div class="newest-member">
            <span class="label">Welcome our newest member:</span>
            <a href="/user/{newestMember}" class="member-link">{newestMember}</a>
        </div>
    {/if}
    
    <div class="record-online">
        <span class="label">Most users online:</span>
        <span class="record">{mostOnline.count.toLocaleString()} on {mostOnline.date}</span>
    </div>
</div>

<style>
    .stats-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        height: 100%;
    }
    
    .stats-title {
        font-size: 1.125rem;
        font-weight: 700;
        margin: 0 0 1.5rem 0;
        color: rgba(255, 255, 255, 0.95);
    }
    
    .stats-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 1rem;
        margin-bottom: 1.5rem;
    }
    
    .stat-item {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        padding: 0.75rem;
        background: rgba(0, 0, 0, 0.2);
        border-radius: 8px;
        transition: all 0.2s;
    }
    
    .stat-item:hover {
        background: rgba(99, 102, 241, 0.1);
        transform: translateY(-1px);
    }
    
    .stat-icon {
        font-size: 1.5rem;
    }
    
    .stat-content {
        display: flex;
        flex-direction: column;
    }
    
    .stat-value {
        font-size: 1.125rem;
        font-weight: 700;
        color: rgba(99, 102, 241, 0.9);
    }
    
    .stat-label {
        font-size: 0.75rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .newest-member, .record-online {
        padding: 0.75rem;
        background: rgba(99, 102, 241, 0.05);
        border-radius: 8px;
        font-size: 0.875rem;
        margin-bottom: 0.75rem;
    }
    
    .record-online {
        margin-bottom: 0;
    }
    
    .label {
        color: rgba(255, 255, 255, 0.6);
        margin-right: 0.5rem;
    }
    
    .member-link {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        font-weight: 600;
    }
    
    .member-link:hover {
        text-decoration: underline;
    }
    
    .record {
        color: rgba(255, 255, 255, 0.9);
        font-weight: 600;
    }
</style>