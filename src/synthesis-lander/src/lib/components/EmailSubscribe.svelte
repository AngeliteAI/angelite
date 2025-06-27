<script>
  let email = $state('');
  let isSubmitting = $state(false);
  let isSuccess = $state(false);
  let mouseX = $state(0);
  let mouseY = $state(0);
  let inputRef;
  
  function handleMouseMove(e) {
    if (!inputRef) return;
    const rect = inputRef.getBoundingClientRect();
    mouseX = ((e.clientX - rect.left) / rect.width) * 100;
    mouseY = ((e.clientY - rect.top) / rect.height) * 100;
  }
  
  async function handleSubmit(e) {
    e.preventDefault();
    if (!email || isSubmitting) return;
    
    isSubmitting = true;
    
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1500));
    
    isSuccess = true;
    isSubmitting = false;
    email = '';
    
    // Reset success state after 3 seconds
    setTimeout(() => {
      isSuccess = false;
    }, 3000);
  }
</script>

<div class="email-container">
  <form onsubmit={handleSubmit}>
    <div 
      class="input-wrapper glass"
      bind:this={inputRef}
      onmousemove={handleMouseMove}
      style="--mouse-x: {mouseX}%; --mouse-y: {mouseY}%"
    >
      <div class="input-glow"></div>
      
      <input
        type="email"
        bind:value={email}
        placeholder="Enter your command center email"
        class="email-input"
        required
        disabled={isSubmitting || isSuccess}
      />
      
      <button 
        type="submit" 
        class="submit-button"
        disabled={isSubmitting || isSuccess || !email}
        class:submitting={isSubmitting}
        class:success={isSuccess}
      >
        {#if isSubmitting}
          <span class="button-spinner"></span>
        {:else if isSuccess}
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M16.667 5L7.5 14.167L3.333 10" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        {:else}
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <path d="M3.333 6.667L10 11.667L16.667 6.667" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            <rect x="2.5" y="5" width="15" height="10" rx="2" stroke="currentColor" stroke-width="2"/>
          </svg>
        {/if}
      </button>
    </div>
  </form>
  
  {#if isSuccess}
    <p class="success-message">
      Thanks for subscribing! We'll be in touch soon.
    </p>
  {/if}
</div>

<style>
  .email-container {
    width: 100%;
    max-width: 500px;
    margin: 0 auto;
  }
  
  .input-wrapper {
    position: relative;
    display: flex;
    align-items: center;
    padding: 4px;
    border-radius: 9999px;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    overflow: hidden;
  }
  
  .input-wrapper:hover {
    transform: translateY(-2px);
    box-shadow: 
      0 20px 40px rgba(0, 0, 0, 0.3),
      0 0 60px rgba(99, 102, 241, 0.2),
      inset 0 1px rgba(255, 255, 255, 0.2);
  }
  
  .input-glow {
    position: absolute;
    width: 200px;
    height: 200px;
    background: radial-gradient(circle, rgba(99, 102, 241, 0.4) 0%, transparent 70%);
    border-radius: 50%;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.3s;
    left: var(--mouse-x);
    top: var(--mouse-y);
    transform: translate(-50%, -50%);
  }
  
  .input-wrapper:hover .input-glow {
    opacity: 1;
  }
  
  .email-input {
    flex: 1;
    background: none;
    border: none;
    padding: 16px 24px;
    font-size: 16px;
    color: #fff;
    outline: none;
    font-family: var(--font-family);
    letter-spacing: -0.01em;
  }
  
  .email-input::placeholder {
    color: rgba(255, 255, 255, 0.4);
  }
  
  .email-input:disabled {
    opacity: 0.5;
  }
  
  .submit-button {
    background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
    border: none;
    width: 52px;
    height: 52px;
    border-radius: 9999px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    color: #fff;
    flex-shrink: 0;
  }
  
  .submit-button:hover:not(:disabled) {
    transform: scale(1.05);
    box-shadow: 0 8px 24px rgba(99, 102, 241, 0.4);
  }
  
  .submit-button:active:not(:disabled) {
    transform: scale(0.95);
  }
  
  .submit-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .submit-button.submitting {
    background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  }
  
  .submit-button.success {
    background: linear-gradient(135deg, #10b981 0%, #34d399 100%);
  }
  
  .button-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: #fff;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }
  
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  
  .success-message {
    margin-top: 16px;
    text-align: center;
    color: #34d399;
    font-size: 14px;
    animation: fadeIn 0.3s ease-out;
  }
  
  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  @media (max-width: 640px) {
    .email-input {
      font-size: 14px;
      padding: 14px 20px;
    }
    
    .submit-button {
      width: 48px;
      height: 48px;
    }
  }
</style>