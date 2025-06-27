<script>
    let {
        currentPath = [],
        quickLinks = []
    } = $props();
</script>

<div class="navigation-card">
    <div class="breadcrumb">
        <a href="/forum" class="breadcrumb-link">🏠 Forum Home</a>
        {#each currentPath as item}
            <span class="breadcrumb-separator">›</span>
            <a href={item.url} class="breadcrumb-link">{item.name}</a>
        {/each}
    </div>
    
    {#if quickLinks.length > 0}
        <div class="quick-links">
            <span class="quick-links-label">Quick Links:</span>
            {#each quickLinks as link}
                <a href={link.url} class="quick-link">{link.icon} {link.name}</a>
            {/each}
        </div>
    {/if}
</div>

<style>
    .navigation-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1rem 1.5rem;
        backdrop-filter: blur(10px);
        width: 100%;
        margin-bottom: 1.5rem;
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
    }
    
    .breadcrumb {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 0.5rem;
        font-size: 0.875rem;
    }
    
    .breadcrumb-link {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        transition: color 0.2s;
    }
    
    .breadcrumb-link:hover {
        color: rgba(99, 102, 241, 1);
        text-decoration: underline;
    }
    
    .breadcrumb-separator {
        color: rgba(255, 255, 255, 0.3);
    }
    
    .quick-links {
        display: flex;
        align-items: center;
        gap: 1rem;
        font-size: 0.875rem;
    }
    
    .quick-links-label {
        color: rgba(255, 255, 255, 0.5);
    }
    
    .quick-link {
        color: rgba(255, 255, 255, 0.8);
        text-decoration: none;
        padding: 0.375rem 0.75rem;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 6px;
        transition: all 0.2s;
        display: flex;
        align-items: center;
        gap: 0.375rem;
    }
    
    .quick-link:hover {
        background: rgba(99, 102, 241, 0.2);
        color: rgba(255, 255, 255, 0.95);
        transform: translateY(-1px);
    }
</style>