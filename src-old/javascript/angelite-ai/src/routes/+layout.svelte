<script>
    import 'angelite/styles'
	import { i18n } from '$lib/i18n';
	import { ParaglideJS } from '@inlang/paraglide-sveltekit';
    import { ui } from 'angelite';
	import '../app.css';
	let { children } = $props();
  
    let base = [
        {name: 'Content', href: '/content', src: '/live.svg', id: 1},
        {name: 'Support', href: '/support', src: '/donation.svg', id: 2},
        {name: 'Pricing', href: '/pricing', src: '/price-tag.svg', id: 3},
        {name: 'Mission', href: '/mission', src: '/halo.svg', id: 4},
    ];
</script>

<ParaglideJS {i18n}>
    <main class="w-full h-full min-h-[100vh] flex z-0 flex-col items-center">
        <div class="sm:w-150 md:w-175 lg:w-250 min-h-[100vh] m-2 h-full flex flex-col">

        <span class="w-full max-h-30 flex-grow"></span>
        <div id="container" class="color-text w-full">
	    {@render children()}
        </div>
        </div>
    </main>
</ParaglideJS>

<ui.Sidebar menu={base} />
