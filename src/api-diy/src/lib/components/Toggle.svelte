<script>
	import { createEventDispatcher } from 'svelte';

	export let checked = false;
	export let disabled = false;
	export let size = 'md'; // 'sm', 'md', 'lg'
	export let color = 'blue'; // 'blue', 'green', 'purple', 'red'
	export let label = '';
	export let id = '';

	const dispatch = createEventDispatcher();

	const sizes = {
		sm: {
			track: 'w-8 h-5',
			thumb: 'w-3 h-3',
			translate: 'translate-x-3'
		},
		md: {
			track: 'w-11 h-6',
			thumb: 'w-4 h-4',
			translate: 'translate-x-5'
		},
		lg: {
			track: 'w-14 h-8',
			thumb: 'w-6 h-6',
			translate: 'translate-x-6'
		}
	};

	const colors = {
		blue: 'bg-blue-500',
		green: 'bg-green-500',
		purple: 'bg-purple-500',
		red: 'bg-red-500'
	};

	function handleChange(event) {
		if (disabled) return;
		checked = event.target.checked;
		dispatch('change', { checked });
	}

	function handleClick() {
		if (disabled) return;
		checked = !checked;
		dispatch('change', { checked });
	}

	function handleKeyDown(event) {
		if (disabled) return;
		if (event.key === ' ' || event.key === 'Enter') {
			event.preventDefault();
			checked = !checked;
			dispatch('change', { checked });
		}
	}

	$: currentSize = sizes[size] || sizes.md;
	$: activeColor = colors[color] || colors.blue;
</script>

<div class="flex items-center gap-2">
	{#if label}
		<label for={id} class="text-sm font-medium text-gray-700 dark:text-gray-300 select-none">
			{label}
		</label>
	{/if}
	
	<button
		type="button"
		role="switch"
		aria-checked={checked}
		aria-disabled={disabled}
		{id}
		class="
			relative inline-flex shrink-0 cursor-pointer rounded-full border-2 border-transparent
			transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-offset-2
			{currentSize.track}
			{checked ? activeColor : 'bg-gray-200 dark:bg-gray-700'}
			{disabled ? 'opacity-50 cursor-not-allowed' : 'focus:ring-blue-500'}
		"
		on:click={handleClick}
		on:keydown={handleKeyDown}
		{disabled}
	>
		<span class="sr-only">{label || 'Toggle'}</span>
		<span
			class="
				pointer-events-none inline-block rounded-full bg-white shadow transform ring-0
				transition duration-200 ease-in-out
				{currentSize.thumb}
				{checked ? currentSize.translate : 'translate-x-0'}
			"
		>
		</span>
	</button>

	<!-- Hidden input for form integration -->
	<input
		type="checkbox"
		bind:checked
		on:change={handleChange}
		{disabled}
		{id}
		class="sr-only"
		tabindex="-1"
	/>
</div>

<style>
	/* Additional custom styles if needed */
	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}
</style>