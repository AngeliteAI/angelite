<script>
    import Draggable from "./Draggable.svelte";
    let { children,
        virtualScale = 0.2, 
     } = $props();
     let clientWidth = $state();
     let clientHeight = $state();

    function triggerSnap(e) {
        console.log(clientWidth, clientHeight);
    }
</script>

<!-- Just a basic wrapper div that passes all the content through -->
<Draggable>
    <div bind:clientWidth bind:clientHeight onclick={triggerSnap}>
        {@render children()}
    </div>
</Draggable>

<style>
    .snapper {

    }
    .snappable {
        position: relative;
        width: 100%;
        height: 100%;
    }
</style>