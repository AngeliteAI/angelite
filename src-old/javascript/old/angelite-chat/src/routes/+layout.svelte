<script>
    let { children, ...rest } = $props();
    import("../app.css");
</script>

<main class="w-full bg-space text-day flex flex-col items-center">
    <div class="max-w-150 w-full">
        {@render children()}
    </div>
</main>

<style>
    :global(body) {
        width: 100%;
        height: 100%;
    }
</style>
