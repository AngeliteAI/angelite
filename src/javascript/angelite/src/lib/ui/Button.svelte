<script>
    let { min, max } = $props();
</script>

<div style="min-width: {min}; max-width: {max};" class="button cursor-pointer border rounded-sm p-3 bg-accent text-background text-xl"><slot/></div>

<style>
:global(.accent-button) * {
    background: var(--color-background) !important;
    color: var(--color-accent) !important;
}
:global(.button) * {    
    vertical-align: middle;
}
</style>
