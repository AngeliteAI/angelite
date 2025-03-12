<script>
	import { fade } from 'svelte/transition';
	import { FloatingInput, Button } from 'angelite/ui';
	let index = $state(0);
	let greet = $state(true);
	const buttonState = ['Continue', 'Register'];
	const strategy = [
		{ src: '/github.svg', name: 'Github', action: () => {

            } },
		{ src: '/google.svg', name: 'Google', action: () => {

            } },
		{ src: '/apple.svg', name: 'Apple', action: () => {

            } },
        { src: '/icon.png', name: "Angelite", action: () => {
                greet = false;
            }}
	];
</script>

<div class="flex h-[100vh] w-full items-center justify-center">
	<form class="w-90 -translate-y-3">
		{#if greet}
			<h1 class="text-xl">Login with</h1>
			<br />
			<span>
				{#each strategy as x, i (i)}
                <span on:mousedown={() => x.action()}>
					<Button
						><span class="flex max-h-[40px] items-center justify-start"
							><span class="w-[40px] h-[40px] flex justify-center items-center"><img class="mr-4 max-w-[30px]" src={x.src} /></span>{x.name}</span
						></Button
					>
					<br />
                    </span>
				{/each}
			</span>
			<br />
		{:else}
			<FloatingInput placeholder={['Phone or Email', 'Password']} {index} />
			<br />
			<span on:mousedown={() => (index += 1)}
				><Button><p transition:fade>{buttonState[index]}</p></Button></span
			>
		{/if}
		<br />
		<p class="text-hint">(hint: no credit card required!)</p>
	</form>
</div>
