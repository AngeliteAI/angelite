<script>
    import Draggable from "./Draggable.svelte";
    let { children,
        virtualScale = 0.2, 
     } = $props();
     let clientWidth = $state();
     let clientHeight = $state();

    function triggerSnap(e) {
        // Check if we should only allow dragging from specific handle
        var element = e.currentTarget;
        const treeWalker = document.createTreeWalker(element, NodeFilter.SHOW_ELEMENT);
        let isParent = false;
        while (treeWalker.nextNode()) {
            if(treeWalker.currentNode == document.elementFromPoint(e.clientX, e.clientY))
        {
            break;
        }
            if (treeWalker.currentNode.classList.contains("snappable")) {
                isParent = true;
                break;
            }
        }
        if (isParent) {
            return;
        }
        console.log(clientWidth, clientHeight);
    }
</script>

<!-- Just a basic wrapper div that passes all the content through -->
<Draggable>
    <div bind:clientWidth bind:clientHeight class="snappable" onclick={triggerSnap}>
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