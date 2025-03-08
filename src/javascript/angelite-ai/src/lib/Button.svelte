<div class="min-w-[200px] cursor-pointer border rounded-sm p-3 bg-accent text-background text-xl"><slot/></div>

<style>
:global(.accent-button) * {
    background: var(--color-background) !important;
    color: var(--color-accent) !important;
}
</style>
