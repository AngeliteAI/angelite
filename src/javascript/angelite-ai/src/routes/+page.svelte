<script>
 import Button from '$lib/Button.svelte'
</script>

<main class="w-full h-full flex justify-center">
    <div id="container" class="color-text max-w-[800px] w-full h-[560px]">
        <div id="hero" class="flex flex-col justify-end items-start h-full">
            <span class="select-none">
            <h1 class="text-6xl">Connection, simplified.</h1>
            <h2 class="text-3xl text-secondary">Universal language bindings, AI powered.</h2>
            </span>
            <br/>
            <br/>
            <span class="select-none">
            <Button><h1 class="text-2xl">Get Started</h1></Button>
            <br/>
            <span class="accent-button"><Button><h1 class="text-2xl">Pricing</h1></Button></span>
            </span>
        </div>
    </div>
</main>
