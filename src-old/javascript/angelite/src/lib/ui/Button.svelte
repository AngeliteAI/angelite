<script>
    let { min, max, special } = $props();
</script>

<div style="min-width: {min}; max-width: {max};" class:bg-secondary={!special} class:bg-accent={special} class="button cursor-pointer border rounded-sm p-3 bg-secondary text-background text-xl"><slot/></div>

<style>
:global(.accent-button) * {
    background: var(--color-background) !important;
    color: var(--color-accent) !important;
}
:global(.button) * {    
    vertical-align: middle;
}
</style>
