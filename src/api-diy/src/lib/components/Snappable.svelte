<script>
    let { virtualScale = $bindable(0.2) } = $props();
    import Draggable from "./Draggable.svelte";
    
    // Log when virtualScale changes
    $effect(() => {
        console.log(`Snappable received virtualScale: ${virtualScale}`);
    });
</script>

<div class="relative">
    <Draggable virtualScale={virtualScale}>
        <slot />
    </Draggable>
</div>
