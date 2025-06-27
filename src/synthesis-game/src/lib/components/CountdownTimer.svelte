<script>
    import { onMount, onDestroy } from 'svelte';
    
    let { endDate = new Date('2025-02-28T00:00:00Z') } = $props();
    
    let days = $state(0);
    let hours = $state(0);
    let minutes = $state(0);
    let seconds = $state(0);
    let interval;
    
    function updateCountdown() {
        const now = new Date().getTime();
        const target = new Date(endDate).getTime();
        const difference = target - now;
        
        if (difference > 0) {
            days = Math.floor(difference / (1000 * 60 * 60 * 24));
            hours = Math.floor((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
            minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
            seconds = Math.floor((difference % (1000 * 60)) / 1000);
        } else {
            days = hours = minutes = seconds = 0;
            if (interval) clearInterval(interval);
        }
    }
    
    onMount(() => {
        updateCountdown();
        interval = setInterval(updateCountdown, 1000);
    });
    
    onDestroy(() => {
        if (interval) clearInterval(interval);
    });
</script>

<div class="countdown-container">
    <h3 class="countdown-title">Campaign Ends In</h3>
    <div class="countdown-grid">
        <div class="time-unit">
            <div class="time-value">{days.toString().padStart(2, '0')}</div>
            <div class="time-label">Days</div>
        </div>
        <div class="time-separator">:</div>
        <div class="time-unit">
            <div class="time-value">{hours.toString().padStart(2, '0')}</div>
            <div class="time-label">Hours</div>
        </div>
        <div class="time-separator">:</div>
        <div class="time-unit">
            <div class="time-value">{minutes.toString().padStart(2, '0')}</div>
            <div class="time-label">Minutes</div>
        </div>
        <div class="time-separator">:</div>
        <div class="time-unit">
            <div class="time-value">{seconds.toString().padStart(2, '0')}</div>
            <div class="time-label">Seconds</div>
        </div>
    </div>
    <div class="urgency-message">
        {#if days < 7}
            <span class="urgent">⚡ Final Week!</span>
        {:else if days < 14}
            <span class="warning">Limited Time Remaining</span>
        {:else}
            <span class="normal">Secure Your Early Bird Rewards</span>
        {/if}
    </div>
</div>

<style>
    .countdown-container {
        background: linear-gradient(135deg, rgba(99, 102, 241, 0.1) 0%, rgba(139, 92, 246, 0.05) 100%);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        border: 1px solid rgba(99, 102, 241, 0.2);
        border-radius: 24px;
        padding: 2rem;
        text-align: center;
        position: relative;
        overflow: hidden;
    }
    
    .countdown-container::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 200%;
        height: 100%;
        background: linear-gradient(
            90deg,
            transparent,
            rgba(99, 102, 241, 0.2),
            transparent
        );
        animation: sweep 3s ease-in-out infinite;
    }
    
    @keyframes sweep {
        0% { transform: translateX(-100%); }
        100% { transform: translateX(100%); }
    }
    
    .countdown-title {
        font-size: 1.25rem;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.7);
        margin-bottom: 1.5rem;
        text-transform: uppercase;
        letter-spacing: 0.1em;
    }
    
    .countdown-grid {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        margin-bottom: 1.5rem;
    }
    
    .time-unit {
        position: relative;
    }
    
    .time-value {
        font-size: clamp(2.5rem, 4vw, 3.5rem);
        font-weight: 800;
        font-variant-numeric: tabular-nums;
        letter-spacing: -0.02em;
        background: linear-gradient(180deg, #ffffff 0%, rgba(255, 255, 255, 0.8) 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
        text-shadow: 0 0 30px rgba(99, 102, 241, 0.5);
        line-height: 1;
    }
    
    .time-label {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.5);
        text-transform: uppercase;
        letter-spacing: 0.1em;
        font-weight: 500;
        margin-top: 0.5rem;
    }
    
    .time-separator {
        font-size: 2rem;
        font-weight: 600;
        color: rgba(255, 255, 255, 0.3);
        animation: blink 1s ease-in-out infinite;
        align-self: center;
        padding-bottom: 1.5rem;
    }
    
    @keyframes blink {
        0%, 100% { opacity: 0.3; }
        50% { opacity: 1; }
    }
    
    .urgency-message {
        font-size: 1rem;
        font-weight: 600;
        letter-spacing: -0.01em;
    }
    
    .urgent {
        color: #f59e0b;
        animation: pulse 1s ease-in-out infinite;
    }
    
    .warning {
        color: #8b5cf6;
    }
    
    .normal {
        color: rgba(255, 255, 255, 0.7);
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.7; }
    }
    
    @media (max-width: 768px) {
        .countdown-container {
            padding: 1.5rem;
        }
        
        .countdown-grid {
            gap: 0.25rem;
        }
        
        .time-separator {
            font-size: 1.5rem;
        }
    }
</style>