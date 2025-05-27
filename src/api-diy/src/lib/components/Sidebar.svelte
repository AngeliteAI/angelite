<script lang="ts">
  export let showRightSidebar = true;
  export let activeSidebarTab = "Style";
  export let vdom = null;
  
  // Event dispatcher
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
  
  function setActiveTab(tab) {
    dispatch('setActiveTab', tab);
  }
  
  function toggleSidebar() {
    dispatch('toggleSidebar');
  }
  
  function handleStyleUpdate(style) {
    dispatch('updateStyle', {
      style
    });
  }
</script>

<aside class="w-64 bg-black border-l border-gray-700 overflow-y-auto h-full">
  <!-- Sidebar Header with Toggle Button -->
  <div class="flex items-center justify-between p-2 border-b border-gray-700">
    <h2 class="text-sm font-semibold">Element Inspector</h2>
    <button 
      class="p-1 hover:bg-gray-700 rounded"
      on:click={toggleSidebar}
      title="Toggle Sidebar"
    >
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="15 18 9 12 15 6"></polyline>
      </svg>
    </button>
  </div>
  
  <!-- Element Info -->

  <!-- Tabs -->
  
</aside>

<style>
  /* Any sidebar-specific styles can go here */
</style>