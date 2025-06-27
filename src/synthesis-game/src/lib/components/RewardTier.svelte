<script>
    let {
        tier = "Explorer",
        price = 49,
        currency = "$",
        description = "",
        rewards = [],
        backers = 0,
        limited = false,
        remaining = null,
        featured = false,
        earlyBird = false,
        onClick = () => {}
    } = $props();
    
    const isLimitedEdition = $derived(limited && remaining !== null);
    const soldOut = $derived(isLimitedEdition && remaining === 0);
</script>

<button 
    class="reward-tier {featured ? 'featured' : ''} {soldOut ? 'sold-out' : ''}"
    onclick={onClick}
    disabled={soldOut}
>
    {#if featured}
        <div class="featured-badge">Most Popular</div>
    {/if}
    
    {#if earlyBird}
        <div class="early-bird-badge">🐦 Early Bird</div>
    {/if}
    
    <div class="tier-header">
        <h3 class="tier-name">{tier}</h3>
        <div class="tier-price">
            <span class="currency">{currency}</span>
            <span class="amount">{price}</span>
        </div>
    </div>
    
    <p class="tier-description">{description}</p>
    
    <div class="rewards-list">
        <h4 class="rewards-title">Includes:</h4>
        <ul>
            {#each rewards as reward}
                <li class="reward-item">
                    <span class="reward-check">✓</span>
                    {reward}
                </li>
            {/each}
        </ul>
    </div>
    
    <div class="tier-footer">
        {#if isLimitedEdition}
            <div class="limited-info {remaining < 10 ? 'urgent' : ''}">
                {#if soldOut}
                    <span class="sold-out-text">Sold Out</span>
                {:else}
                    <span class="remaining">Only {remaining} left!</span>
                {/if}
            </div>
        {/if}
        
        <div class="backer-count">
            {backers} backers
        </div>
    </div>
    
    <div class="select-button">
        {soldOut ? 'No Longer Available' : 'Select This Reward'}
    </div>
</button>

<style>
    .reward-tier {
        background: rgba(255, 255, 255, 0.03);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 20px;
        padding: 2rem;
        position: relative;
        overflow: hidden;
        transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
        cursor: pointer;
        display: flex;
        flex-direction: column;
        width: 100%;
        text-align: left;
    }
    
    .reward-tier:hover:not(.sold-out) {
        transform: translateY(-4px);
        background: rgba(255, 255, 255, 0.05);
        border-color: rgba(99, 102, 241, 0.3);
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    }
    
    .reward-tier.featured {
        border-color: rgba(99, 102, 241, 0.4);
        background: linear-gradient(135deg, rgba(99, 102, 241, 0.1) 0%, rgba(139, 92, 246, 0.05) 100%);
    }
    
    .reward-tier.sold-out {
        opacity: 0.6;
        cursor: not-allowed;
    }
    
    .featured-badge {
        position: absolute;
        top: -1px;
        right: 20px;
        background: linear-gradient(135deg, #6366f1, #8b5cf6);
        color: white;
        padding: 0.5rem 1.5rem;
        font-size: 0.875rem;
        font-weight: 600;
        border-radius: 0 0 12px 12px;
        letter-spacing: 0.05em;
        text-transform: uppercase;
    }
    
    .early-bird-badge {
        position: absolute;
        top: 20px;
        left: 20px;
        background: linear-gradient(135deg, #f59e0b, #f97316);
        color: white;
        padding: 0.375rem 1rem;
        font-size: 0.875rem;
        font-weight: 600;
        border-radius: 999px;
        animation: float 3s ease-in-out infinite;
    }
    
    @keyframes float {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(-4px); }
    }
    
    .tier-header {
        margin-bottom: 1.5rem;
    }
    
    .tier-name {
        font-size: 1.75rem;
        font-weight: 700;
        margin-bottom: 0.5rem;
        color: rgba(255, 255, 255, 0.95);
        letter-spacing: -0.02em;
    }
    
    .tier-price {
        display: flex;
        align-items: baseline;
        gap: 0.25rem;
    }
    
    .currency {
        font-size: 1.25rem;
        color: rgba(255, 255, 255, 0.6);
    }
    
    .amount {
        font-size: 2.5rem;
        font-weight: 800;
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        letter-spacing: -0.03em;
    }
    
    .tier-description {
        font-size: 1.125rem;
        line-height: 1.6;
        color: rgba(255, 255, 255, 0.7);
        margin-bottom: 2rem;
    }
    
    .rewards-list {
        flex: 1;
        margin-bottom: 2rem;
    }
    
    .rewards-title {
        font-size: 0.875rem;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        color: rgba(255, 255, 255, 0.5);
        margin-bottom: 1rem;
        font-weight: 600;
    }
    
    .rewards-list ul {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    
    .reward-item {
        display: flex;
        align-items: flex-start;
        gap: 0.75rem;
        margin-bottom: 0.75rem;
        font-size: 1rem;
        color: rgba(255, 255, 255, 0.85);
        line-height: 1.5;
    }
    
    .reward-check {
        color: #10b981;
        font-weight: 600;
        font-size: 1.125rem;
        flex-shrink: 0;
    }
    
    .tier-footer {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1.5rem;
        padding-top: 1.5rem;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
    }
    
    .limited-info {
        font-size: 0.875rem;
        font-weight: 600;
    }
    
    .limited-info.urgent {
        color: #f59e0b;
    }
    
    .remaining {
        animation: pulse 2s ease-in-out infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.7; }
    }
    
    .sold-out-text {
        color: #ef4444;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .backer-count {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
    }
    
    .select-button {
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
        color: white;
        padding: 1rem;
        border-radius: 12px;
        text-align: center;
        font-weight: 600;
        font-size: 1rem;
        letter-spacing: -0.01em;
        transition: all 0.3s ease;
        position: relative;
        overflow: hidden;
    }
    
    .reward-tier:hover:not(.sold-out) .select-button {
        transform: scale(1.02);
        box-shadow: 0 4px 20px rgba(99, 102, 241, 0.4);
    }
    
    .sold-out .select-button {
        background: rgba(255, 255, 255, 0.1);
        color: rgba(255, 255, 255, 0.4);
    }
    
    @media (max-width: 768px) {
        .reward-tier {
            padding: 1.5rem;
        }
        
        .tier-name {
            font-size: 1.5rem;
        }
        
        .amount {
            font-size: 2rem;
        }
    }
</style>