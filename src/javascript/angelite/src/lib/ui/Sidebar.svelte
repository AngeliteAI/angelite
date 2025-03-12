<script>
    import { onMount } from "svelte";
    import { browser } from '$app/environment'; 
    import Button from "./Button.svelte";
    let { menu = [], app_url = "" }= $props();
    let menuEntries = $derived(menu.map(entry => entry));

    let isTransformed = $state(false);
    let sidebarOpened = $state(false);
    let scrollTop = $state(0);
    let scrollTopPx = $derived(scrollTop + 'px');
    
    function mouseover() {
        isTransformed = true;

    }

    function mouseleave() {
        if (!sidebarOpened) {
            isTransformed = false;
        }
    }

    function open() {
        sidebarOpened = true;
    }

    function close() {
        sidebarOpened = false;
    }

    onMount(() => {
        if (browser && !localStorage.getItem("hinted")) {
            isTransformed = true;
        setTimeout(() => {
            isTransformed = false;
            localStorage.setItem("hinted", true);
            }, "2500")
        }
       })
</script>


<span id="sidebar-container" class="fixed z-200 pointer-events-none top-0 h-full w-full">

<div id="sidebar" class="pointer-events-auto select-none z-150 absolute flex flex-col sticky top-0 left-0 h-full w-[50px]" on:mouseover={() => open()} 
  >

    <span class="icon z-300 ">
    <a href="/"><img src="/icon.png" class=" h-[40px]"/></a>
    </span>
    <span class="flex-grow "/>
    <span class="icon">
    <img src="/sidebar.png" class="sidebar-icon invert h-[30px]"/>
    </span>
</div>

<span id="menu-container" class="absolute z-100 bg-background pointer-events-auto" class:changed={sidebarOpened} on:mouseleave={() => close()}>
<span id="menu" class="absolute top-20 bottom-20 left-2 right-2 flex flex-col text-3xl">
  {#each menuEntries as entry (entry.id)}
        <span class="z-500 pointer-event-auto pointer-cursor">
      <Button min='calc(100% - 50px)'>
      <span class="flex flex-row">
      
      <a href={entry.href} class="ml-2 w-full translate-y-[1px] flex"><img src={entry.src} class="min-w-[30px] w-[30px] max-w-[30px] translate-y-[-1px] mr-4" />{entry.name}</a>
      </span>
      </Button>
      </span>
      <span class="mb-2"></span>
    {/each}
    <span class="flex-grow"></span>
      <Button><span class="flex flex-row">
      <span class="min-w-[30px] min-h-[30px] rounded-full bg-background translate-x-[-1px] translate-y-[-1px]" ></span>
      <a href={app_url} class="ml-2 w-full translate-y-[1px]">Dashboard</a>
      </span>
</Button>
</span>
</span>

<span 
  id="trigger" 
  class="fixed top-0 z-50 cursor-grab h-full pointer-events-auto " 

  on:mouseover={() => mouseover()} 
  on:mouseleave={() => mouseleave()}>
</span>

<span id="hint-container fixed" class:moved={sidebarOpened}>
<span id="hint" class="w-40"  class:transformed={!isTransformed}></span>

</span>
</span>
<span class:backdrop-blur={sidebarOpened} class:force-auto={sidebarOpened} class="transition-all duration-500 fixed pointer-events-none left-[-100px] right-[-100px] top-0 bottom-0 z-30"></span>


<style>
    @theme {
        --menu-size: calc(var(--spacing) * 80);
        --menu-size-neg: calc(var(--spacing) * -80);
    }

    #trigger {
        width: calc(var(--menu-size) * 1 / 4); 
    }

    .icon {
        @apply flex justify-center items-center h-[50px] cursor-pointer z-100;
    }

    #hint {
        @apply absolute z-0 pointer-events-none h-[100vh];
        top: 0;
        left: 0;
        bottom: 0;
        background-image: linear-gradient(to right, var(--color-accent), transparent);
        transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), opacity 0.2s cubic-bezier(0.4, 0, 1, 1);
        opacity: 0.25;
    }

#hint-container {
        @apply  relative z-0 pointer-events-none w-[var(--menu-size)] h-[100vh];
        top: 0;
        left: 0;
        bottom: 0;
        transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), opacity 0.2s cubic-bezier(0.4, 0, 1, 1);
        opacity: 1.0;
}

.moved {
    left:var(--menu-size) !important;
    opacity: 0 !important;
}
    
    .transformed {
        left: var(--menu-size-neg) !important;
    }
    
    .blurred {
    }

    .force-auto {
        pointer-events: auto !important;
    }

#menu-container {
    @apply w-[var(--menu-size)] h-full;
    top: 0;
    bottom: 0;
    border-right: 1px var(--color-accent) solid;
    transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), right 0.2s cubic-bezier(0.4, 0, 1, 1);
    left: var(--menu-size-neg);
    right: 0;
}

#menu-container.changed {
    left: 0px;
    right: var(--menu-size); 
}

#sidebar {
transform: translateX(9px);
}


</style>
