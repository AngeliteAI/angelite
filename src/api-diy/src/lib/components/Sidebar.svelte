<script lang="ts">
  export let selectedNodeId = null;
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
    if (!selectedNodeId) return;
    
    dispatch('updateStyle', {
      nodeId: selectedNodeId,
      style
    });
  }
</script>

<aside class="w-64 bg-gray-800 border-l border-gray-700 overflow-y-auto h-[calc(100vh-3rem)]">
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
  <div class="p-3 border-b border-gray-700">
    {#if selectedNodeId && vdom?.getNode(selectedNodeId)}
      <div class="text-sm">
        <p>Type: <span class="text-blue-300">{vdom.getNode(selectedNodeId).type}</span></p>
        <p>ID: <span class="text-blue-300">{selectedNodeId}</span></p>
      </div>
    {:else}
      <p class="text-sm text-gray-400">No element selected</p>
    {/if}
  </div>
  
  <!-- Tabs -->
  <div class="flex border-b border-gray-700">
    <button 
      class="flex-1 py-2 text-sm text-center {activeSidebarTab === 'Style' ? 'bg-gray-700 text-white' : 'text-gray-400 hover:bg-gray-700'}"
      on:click={() => setActiveTab('Style')}
    >
      Style
    </button>
    <button 
      class="flex-1 py-2 text-sm text-center {activeSidebarTab === 'Settings' ? 'bg-gray-700 text-white' : 'text-gray-400 hover:bg-gray-700'}"
      on:click={() => setActiveTab('Settings')}
    >
      Settings
    </button>
  </div>
  
  <!-- Tab Content -->
  {#if activeSidebarTab === 'Style' && selectedNodeId && vdom?.getNode(selectedNodeId)}
    <div class="p-4">
      <div class="mb-4">
        <h3 class="text-sm font-medium mb-2">Position</h3>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-xs text-gray-400">Top</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.top || '0px'} 
              on:change={(e) => handleStyleUpdate({ top: e.target.value })}
            />
          </div>
          <div>
            <label class="text-xs text-gray-400">Left</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.left || '0px'} 
              on:change={(e) => handleStyleUpdate({ left: e.target.value })}
            />
          </div>
        </div>
      </div>
      
      <div class="mb-4">
        <h3 class="text-sm font-medium mb-2">Size</h3>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="text-xs text-gray-400">Width</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.width || 'auto'} 
              on:change={(e) => handleStyleUpdate({ width: e.target.value })}
            />
          </div>
          <div>
            <label class="text-xs text-gray-400">Height</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.height || 'auto'} 
              on:change={(e) => handleStyleUpdate({ height: e.target.value })}
            />
          </div>
        </div>
      </div>
      
      <div class="mb-4">
        <h3 class="text-sm font-medium mb-2">Appearance</h3>
        <div class="space-y-2">
          <div>
            <label class="text-xs text-gray-400">Background</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.background || ''} 
              on:change={(e) => handleStyleUpdate({ background: e.target.value })}
            />
          </div>
          <div>
            <label class="text-xs text-gray-400">Color</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.color || ''} 
              on:change={(e) => handleStyleUpdate({ color: e.target.value })}
            />
          </div>
          <div>
            <label class="text-xs text-gray-400">Border</label>
            <input 
              type="text" 
              class="w-full bg-gray-700 border border-gray-600 text-sm p-1 rounded"
              value={vdom.getNode(selectedNodeId).styles?.border || ''} 
              on:change={(e) => handleStyleUpdate({ border: e.target.value })}
            />
          </div>
        </div>
      </div>
    </div>
  {:else if activeSidebarTab === 'Settings'}
    <div class="p-4">
      <h3 class="text-sm font-medium mb-2">Builder Settings</h3>
      <p class="text-xs text-gray-400">Configure global settings for the builder.</p>
    </div>
  {/if}
</aside>

<style>
  /* Any sidebar-specific styles can go here */
</style>