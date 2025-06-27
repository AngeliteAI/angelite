<script>
    let {
        title = "Announcement",
        content = "",
        author = "Admin",
        date = "Today",
        type = "info", // info, warning, success, error
        icon = "📢"
    } = $props();
</script>

<div class="announcement-card {type}">
    <div class="announcement-header">
        <span class="announcement-icon">{icon}</span>
        <h3 class="announcement-title">{title}</h3>
        <span class="announcement-date">{date}</span>
    </div>
    
    <div class="announcement-content">
        {@html content}
    </div>
    
    <div class="announcement-footer">
        <span class="announcement-author">Posted by <a href="/user/{author}">{author}</a></span>
    </div>
</div>

<style>
    .announcement-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        width: 100%;
        margin-bottom: 1.5rem;
        position: relative;
        overflow: hidden;
    }
    
    .announcement-card::before {
        content: '';
        position: absolute;
        left: 0;
        top: 0;
        bottom: 0;
        width: 4px;
        background: linear-gradient(180deg, #6366f1, #8b5cf6);
    }
    
    .announcement-card.warning::before {
        background: linear-gradient(180deg, #f59e0b, #ef4444);
    }
    
    .announcement-card.success::before {
        background: linear-gradient(180deg, #10b981, #059669);
    }
    
    .announcement-card.error::before {
        background: linear-gradient(180deg, #ef4444, #dc2626);
    }
    
    .announcement-header {
        display: flex;
        align-items: center;
        gap: 1rem;
        margin-bottom: 1rem;
    }
    
    .announcement-icon {
        font-size: 1.5rem;
    }
    
    .announcement-title {
        font-size: 1.25rem;
        font-weight: 700;
        margin: 0;
        flex: 1;
        color: rgba(255, 255, 255, 0.95);
    }
    
    .announcement-date {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .announcement-content {
        font-size: 0.9375rem;
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.8);
        margin-bottom: 1rem;
    }
    
    .announcement-content :global(a) {
        color: #6366f1;
        text-decoration: none;
    }
    
    .announcement-content :global(a:hover) {
        text-decoration: underline;
    }
    
    .announcement-footer {
        font-size: 0.8125rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .announcement-author a {
        color: rgba(99, 102, 241, 0.9);
        text-decoration: none;
        font-weight: 500;
    }
    
    .announcement-author a:hover {
        text-decoration: underline;
    }
</style>