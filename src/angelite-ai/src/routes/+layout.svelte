<script>
	import '../app.css';
	
	let { children } = $props();
</script>

<main class="width-full max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
	<div class="flex items-center justify-between mb-4">
		<h1 class="text-2xl font-bold">Angelite AI</h1>
		<span class="flex-grow"></span>
		<a>Learn more</a>
	</div>
{@render children()}
</main>
<style>
	@import url('https://fonts.googleapis.com/css2?family=Inter:ital,opsz,wght@0,14..32,100..900;1,14..32,100..900&family=Rubik:ital,wght@0,300..900;1,300..900&display=swap');

	:global(*) {
		font-family: 'Inter', sans-serif;
	}
</style>