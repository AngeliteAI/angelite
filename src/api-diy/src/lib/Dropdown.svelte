<script>
  import { createEventDispatcher } from 'svelte';
  import { onMount } from 'svelte';
  const dispatch = createEventDispatcher();

  export let options = [];
  export let value = 0;
  export let label = 'Select an option';
  export let placeholder = 'Choose...';
  
  let isOpen = false;
  let dropdownContainer;
  
  function selectOption(index) {
    value = index;
    isOpen = false;
    dispatch('change', index);
  }

  function handleClickOutside(event) {
    if (dropdownContainer && !dropdownContainer.contains(event.target)) {
      isOpen = false;
    }
  }

  onMount(() => {
    document.addEventListener('click', handleClickOutside);
    return () => {
      document.removeEventListener('click', handleClickOutside);
    };
  });
</script>

<div class="dropdown-container" bind:this={dropdownContainer}>
  <div class="input-wrapper" on:click|stopPropagation={() => isOpen = !isOpen}>
    <input
      type="text"
      value={options[value] || ''}
      readonly
      {placeholder}
      class="dropdown-input"
    />
    <label class="floating-label" class:active={value !== undefined || isOpen}>
      {label}
    </label>
    <span class="arrow" class:open={isOpen}>▼</span>
  </div>
  
  {#if isOpen}
    <div class="dropdown-menu">
      {#each options as option, index}
        <div
          class="dropdown-item"
          class:selected={value === index}
          on:click|stopPropagation={() => {
            selectOption(index);
            isOpen = false;
          }}
        >
          {option}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .dropdown-container {
    position: relative;
    display: inline-block;
    min-width: 200px;
    max-width: 100%;
  }

  .input-wrapper {
    position: relative;
    cursor: pointer;
    width: 100%;
  }

  .dropdown-input {
    width: 100%;
    padding: 0 6px;
    border: 1px solid #333;
    border-radius: 2px;
    font-size: 11px;
    background: #1a1a1a;
    color: #fff;
    box-sizing: border-box;
    height: 1.25rem;
    position: relative;
  }

  .floating-label {
    position: absolute;
    left: 6px;
    top: 50%;
    transform: translateY(-50%);
    background: #1a1a1a;
    padding: 0 2px;
    color: #666;
    transition: all 0.2s;
    pointer-events: none;
    font-size: 11px;
  }

  .floating-label.active {
    top: 0;
    font-size: 9px;
    color: #2196f3;
  }

  .arrow {
    position: absolute;
    right: 6px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 7px;
    transition: transform 0.2s;
    color: #666;
  }

  .arrow.open {
    transform: translateY(-50%) rotate(180deg);
  }

  .dropdown-menu {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: #1a1a1a;
    border: 1px solid #333;
    border-radius: 2px;
    margin-top: 1px;
    max-height: 200px;
    overflow-y: auto;
    z-index: 1000;
    width: 100%;
    box-sizing: border-box;
  }

  .dropdown-item {
    padding: 2px 6px;
    cursor: pointer;
    font-size: 11px;
    color: #fff;
  }

  .dropdown-item:hover {
    background: #333;
  }

  .dropdown-item.selected {
    background: #2196f3;
    color: #fff;
  }
</style>
