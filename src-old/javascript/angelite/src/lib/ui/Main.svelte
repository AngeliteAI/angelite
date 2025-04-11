<script>
    	let { children } = $props();

</script>

<main class="w-full h-full min-h-[100vh] flex z-0 flex-col items-center">
        <div class="sm:w-150 md:w-175 lg:w-250 min-h-[100vh] m-2 h-full flex flex-col">

        <span class="w-full max-h-30 flex-grow"></span>
        <div id="container" class="color-text w-full h-full">
	    {@render children()}
        </div>
        </div>
    </main>
