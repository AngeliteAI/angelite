<script>
    let {
        users = [],
        totalOnline = 0,
        guests = 0,
        bots = []
    } = $props();
</script>

<div class="online-users-card">
    <h3 class="card-title">🟢 Who's Online ({totalOnline})</h3>
    
    <div class="user-lists">
        {#if users.length > 0}
            <div class="user-section">
                <h4 class="section-title">Members ({users.length})</h4>
                <div class="user-list">
                    {#each users as user}
                        <a href="/user/{user.username}" class="user-link" style="color: {user.color || '#6366f1'}">
                            {user.username}
                        </a>
                    {/each}
                </div>
            </div>
        {/if}
        
        {#if guests > 0}
            <div class="guest-section">
                <span class="guest-count">{guests} Guest{guests !== 1 ? 's' : ''}</span>
            </div>
        {/if}
        
        {#if bots.length > 0}
            <div class="bot-section">
                <h4 class="section-title">Bots ({bots.length})</h4>
                <div class="bot-list">
                    {#each bots as bot}
                        <span class="bot-name">{bot}</span>
                    {/each}
                </div>
            </div>
        {/if}
    </div>
    
    <div class="legend">
        <span class="legend-item"><span class="legend-color admin"></span> Administrator</span>
        <span class="legend-item"><span class="legend-color mod"></span> Moderator</span>
        <span class="legend-item"><span class="legend-color vip"></span> VIP</span>
        <span class="legend-item"><span class="legend-color member"></span> Member</span>
    </div>
</div>

<style>
    .online-users-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        height: 100%;
    }
    
    .card-title {
        font-size: 1.125rem;
        font-weight: 700;
        margin: 0 0 1.5rem 0;
        color: rgba(255, 255, 255, 0.95);
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .user-lists {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        margin-bottom: 1.5rem;
    }
    
    .section-title {
        font-size: 0.875rem;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.7);
        margin: 0 0 0.5rem 0;
    }
    
    .user-list {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
    }
    
    .user-link {
        text-decoration: none;
        font-weight: 500;
        font-size: 0.875rem;
        transition: opacity 0.2s;
    }
    
    .user-link:hover {
        opacity: 0.8;
        text-decoration: underline;
    }
    
    .user-link:not(:last-child)::after {
        content: ",";
        margin-left: 0.125rem;
        color: rgba(255, 255, 255, 0.3);
    }
    
    .guest-count {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.6);
        font-style: italic;
    }
    
    .bot-list {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
    }
    
    .bot-name {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
        font-style: italic;
    }
    
    .bot-name:not(:last-child)::after {
        content: ",";
        margin-left: 0.125rem;
    }
    
    .legend {
        display: flex;
        flex-wrap: wrap;
        gap: 1rem;
        padding-top: 1rem;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        font-size: 0.75rem;
    }
    
    .legend-item {
        display: flex;
        align-items: center;
        gap: 0.375rem;
        color: rgba(255, 255, 255, 0.6);
    }
    
    .legend-color {
        width: 12px;
        height: 12px;
        border-radius: 2px;
    }
    
    .legend-color.admin {
        background: #ef4444;
    }
    
    .legend-color.mod {
        background: #8b5cf6;
    }
    
    .legend-color.vip {
        background: #f59e0b;
    }
    
    .legend-color.member {
        background: #6366f1;
    }
</style>