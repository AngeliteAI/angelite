<script lang="ts">
  // Props for the snap indicator
  export let show = false;
  export let x = 0;
  export let y = 0;
  export let direction = 'horizontal'; // or 'vertical'
  export let length = 0;
</script>

{#if show}
  <div 
    class="snap-indicator"
    style={direction === 'horizontal' 
      ? `top: ${y}px; width: ${length}px; left: 0;` 
      : `left: ${x}px; height: ${length}px; top: 0;`}
  >
    <div class="snap-indicator-line"></div>
  </div>
{/if}

<style>
  .snap-indicator {
    position: absolute;
    pointer-events: none;
    z-index: 1000;
  }
  
  .snap-indicator-line {
    position: absolute;
    background-color: rgba(59, 130, 246, 0.8);
    width: 100%;
    height: 100%;
  }
  
  /* Horizontal snap indicator */
  .snap-indicator[style*="width"] .snap-indicator-line {
    height: 2px;
    top: 0;
  }
  
  /* Vertical snap indicator */
  .snap-indicator[style*="height"] .snap-indicator-line {
    width: 2px;
    left: 0;
  }
</style>