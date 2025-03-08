<script>
    let isTransformed = $state(false);
    let sidebarOpened = $state(false);

    function mouseover() {
        isTransformed = true;
    }

    function mouseleave() {
        isTransformed = false;
    }

    function open() {
        sidebarOpened = true;
    }

    function close() {
        sidebarOpened = false;
    }
</script>

<span id="sidebar-container" class="absolute top-0 h-full w-full">

<div id="sidebar" class="cursor-pointer select-none z-100 absolute flex flex-col top-0 left-0 h-full w-[50px]" on:mouseover={() => open()} 
  on:mouseleave={() => close()}>

    <span class="icon">
    <img src="/icon.png" class=" h-[40px]  "/>
    </span>
    <span class="flex-grow "/>
    <span class="icon">
    <img src="/sidebar.png" class="sidebar-icon invert h-[30px]"/>
    </span>
</div>

<span id="menu-container" class="absolute" class:changed={sidebarOpened}>
<span id="menu" class="absolute">
</span>
</span>

<span 
  id="trigger" 
  class="absolute top-0 z-50 cursor-grab h-full w-[200px]" 
  on:mouseover={() => mouseover()} 
  on:mouseleave={() => mouseleave()}>
</span>

<span id="hint-container" class:moved={sidebarOpened}>
<span id="hint"  class:transformed={!isTransformed}></span>

</span>
</span>

<style>
    .icon {
        @apply flex justify-center items-center h-[50px] cursor-pointer z-100;
    }

    #hint {
        @apply absolute z-0 pointer-events-none w-[200px] h-[100vh];
        top: 0;
        left: 0;
        bottom: 0;
        background-image: linear-gradient(to right, var(--color-accent), transparent);
        transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), opacity 0.2s cubic-bezier(0.4, 0, 1, 1);
        opacity: 0.25;
    }

#hint-container {
        @apply  relative z-0 pointer-events-none w-[200px] h-[100vh];
        top: 0;
        left: 0;
        bottom: 0;
        transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), opacity 0.2s cubic-bezier(0.4, 0, 1, 1);
        opacity: 1.0;
}

.moved {
    left:200px !important;
    opacity: 0 !important;
}
    
    .transformed {
        left: -200px !important;
    }

#menu-container {
    @apply w-[200px] h-full;
    top: 0;
    bottom: 0;
    border-right: 1px var(--color-accent) solid;
    transition: left 0.3s  cubic-bezier(0.4, 0, 1, 1), right 0.2s cubic-bezier(0.4, 0, 1, 1);
    left: -200px;
    right: 0;
}

#menu-container.changed {
    left: 0px;
    right: 200px; 
}



</style>
