<script lang="ts">
  export let showBlueprintMode = false;
  export let showRightSidebar = true;
  
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
  
  function toggleBlueprintMode() {
    dispatch('toggleBlueprintMode');
  }
  
  function toggleSidebar() {
    dispatch('toggleSidebar');
  }
</script>

<header class="bg-black z-10 flex items-center justify-between px-4 h-12">
  <h1 class="text-xl font-bold">AngeliteDIY</h1>
  <div class="flex space-x-2">
    <button 
      class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm"
      on:click={toggleBlueprintMode}
    >
      {showBlueprintMode ? 'Normal Mode' : 'Blueprint Mode'}
    </button>
    <button 
      class="px-3 py-1 bg-gray-700 hover:bg-gray-600 rounded text-sm"
      on:click={toggleSidebar}
    >
      {showRightSidebar ? 'Hide Sidebar' : 'Show Sidebar'}
    </button>
  </div>
</header>

<style>
  header {
    border-bottom: 1px solid #27272a;
  }
</style>