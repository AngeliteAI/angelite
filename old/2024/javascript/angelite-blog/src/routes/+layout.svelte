<script>
	import 'angelite/styles';
	import { Main } from 'angelite/ui';
	import { Sidebar } from 'angelite/ui';

	import '../app.css';
	let { children } = $props();
</script>

<Sidebar />

<Main>
	{@render children()}
</Main>
