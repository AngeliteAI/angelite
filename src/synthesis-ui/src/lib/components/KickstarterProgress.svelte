<script>
    let { 
        currentAmount = 0,
        goalAmount = 0,
        backerCount = 0,
        daysLeft = 0,
        currency = "$"
    } = $props();
    
    const percentage = $derived(Math.min((currentAmount / goalAmount) * 100, 100));
    const formattedCurrent = $derived(new Intl.NumberFormat('en-US').format(currentAmount));
    const formattedGoal = $derived(new Intl.NumberFormat('en-US').format(goalAmount));
    const formattedBackers = $derived(new Intl.NumberFormat('en-US').format(backerCount));
</script>

<div class="kickstarter-progress">
    <div class="progress-header">
        <h2 class="amount-raised">
            {currency}{formattedCurrent}
            <span class="goal-text">pledged of {currency}{formattedGoal} goal</span>
        </h2>
    </div>
    
    <div class="progress-bar-container">
        <div class="progress-bar-bg">
            <div 
                class="progress-bar-fill"
                style="width: {percentage}%"
            >
                <div class="progress-glow"></div>
            </div>
        </div>
        <span class="percentage-label">{percentage.toFixed(1)}%</span>
    </div>
    
    <div class="stats-grid">
        <div class="stat">
            <div class="stat-value">{formattedBackers}</div>
            <div class="stat-label">backers</div>
        </div>
        <div class="stat">
            <div class="stat-value">{daysLeft}</div>
            <div class="stat-label">days to go</div>
        </div>
    </div>
</div>

<style>
    .kickstarter-progress {
        background: rgba(255, 255, 255, 0.03);
        backdrop-filter: blur(40px);
        -webkit-backdrop-filter: blur(40px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 24px;
        padding: 2.5rem;
        position: relative;
        overflow: hidden;
    }
    
    .kickstarter-progress::before {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(
            circle,
            rgba(99, 102, 241, 0.1) 0%,
            transparent 70%
        );
        animation: rotate 20s linear infinite;
    }
    
    @keyframes rotate {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }
    
    .progress-header {
        margin-bottom: 2rem;
        position: relative;
    }
    
    .amount-raised {
        font-size: clamp(2.5rem, 4vw, 3.5rem);
        font-weight: 800;
        letter-spacing: -0.04em;
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        margin: 0;
    }
    
    .goal-text {
        display: block;
        font-size: 1.125rem;
        font-weight: 500;
        color: rgba(255, 255, 255, 0.6);
        margin-top: 0.5rem;
        letter-spacing: -0.02em;
    }
    
    .progress-bar-container {
        position: relative;
        margin-bottom: 2.5rem;
    }
    
    .progress-bar-bg {
        width: 100%;
        height: 12px;
        background: rgba(255, 255, 255, 0.05);
        border-radius: 999px;
        overflow: hidden;
        position: relative;
    }
    
    .progress-bar-fill {
        height: 100%;
        background: linear-gradient(90deg, #6366f1 0%, #8b5cf6 100%);
        border-radius: 999px;
        position: relative;
        transition: width 1.5s cubic-bezier(0.4, 0, 0.2, 1);
        box-shadow: 0 0 20px rgba(99, 102, 241, 0.5);
    }
    
    .progress-glow {
        position: absolute;
        top: 0;
        right: 0;
        width: 50px;
        height: 100%;
        background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4));
        animation: shimmer 2s ease-in-out infinite;
    }
    
    @keyframes shimmer {
        0% { transform: translateX(-50px); }
        100% { transform: translateX(50px); }
    }
    
    .percentage-label {
        position: absolute;
        right: 0;
        top: -30px;
        font-size: 1.125rem;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.9);
    }
    
    .stats-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 2rem;
        position: relative;
    }
    
    .stat {
        text-align: center;
        padding: 1.5rem;
        background: rgba(255, 255, 255, 0.02);
        border-radius: 16px;
        border: 1px solid rgba(255, 255, 255, 0.05);
        transition: all 0.3s ease;
    }
    
    .stat:hover {
        background: rgba(255, 255, 255, 0.04);
        transform: translateY(-2px);
    }
    
    .stat-value {
        font-size: 2.5rem;
        font-weight: 800;
        letter-spacing: -0.03em;
        background: linear-gradient(180deg, #ffffff 0%, rgba(255, 255, 255, 0.7) 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }
    
    .stat-label {
        font-size: 1rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.1em;
        font-weight: 500;
        margin-top: 0.25rem;
    }
    
    @media (max-width: 768px) {
        .kickstarter-progress {
            padding: 1.5rem;
        }
        
        .stats-grid {
            gap: 1rem;
        }
        
        .stat {
            padding: 1rem;
        }
    }
</style>