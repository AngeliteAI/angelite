<script>
    import Draggable from "./Draggable.svelte";
    let { children,
        virtualScale = 0.2, 
     } = $props();

</script>

<!-- Just a basic wrapper div that passes all the content through -->
<Draggable>
    {@render children()}
</Draggable>

<style>
    .snappable {
        position: relative;
        width: 100%;
        height: 100%;
    }
</style>