<script>
import { fade, fly } from 'svelte/transition';
    let {placeholder, index, value = $bindable() } = $props();
    let lead = $state(0);
    let focus = $state(false);
    let input = $state();
    function displacementOut() {
        focus = true;
        input.style.outline = 'none';
        input.style.boxShadow = 'none';
        input.style.webkitAppearance = 'none';
        input.style.webkitTapHighlightColor = 'transparent';
    }
    function displacementIn() {
        if (!value || value.length == 0) {
            focus = false;
        }
    }

</script>

<span bind:clientHeight={lead} class="relative grid grid-cols-1 grid-rows-1" >
  <input 
    type="text" 
    bind:this={input}
    on:focus={displacementOut} 
    on:blur={displacementIn} 
    bind:value={value}
    class:focused={focus}
    class="col-span-full rounded row-span-full outline-0 border border-secondary bg-background w-full  p-4 z-10"
  />
  {#each placeholder as x, i (i)}
{#if index == i}
    <span 
    class="absolute z-20 col-span-full row-span-full transition-all pointer-events-none align-middle"
        in:fly={{ y: -10, duration: 200 }}
      out:fly={{ y: -10, duration: 200 }}
>
    <span     class:text-lg={!focus} 
    class:text-sm={focus}
    class="delay-50 transition-all">
    <p 
      in:fade={{ duration: 100, delay: 100 }}
      out:fade={{ duration: 100, delay: 100}}
    id="placeholder" 
    class="ml-1 pl-2 bg-background translate-[1px] transition-all override"
    style="--lead: {lead}px"
    class:transform={focus}
    class:down={focus}
    class:up={!focus}
  >
    {x}
  </p>
  </span>
  </span>
  {/if}
  {/each}
  
</span>
<style>
.focused {
    border-width: calc(var(--spacing) / 2) !important; /* 'border-size' should be 'border-width' */
  border-color: var(--color-accent) !important;
}

.down {
    transform: translateY(-50%);
    line-height: 3px;
    padding-left: 2px;
    padding-right: 2px;
}
    .up {
        transform: translateY(calc(0%));
        line-height: calc( var(--lead) - 2px)

    }
</style>
