<script>
    import Slider from "./Slider.svelte"
    let clicked = $state(false);
    let { slider = $bindable(), convertMoney, convertProduct, money, product } = $props();
</script>

<p>+ {convertMoney(slider)} {money} <span class:text-hint={!clicked} class:text-accent={clicked} class="transition-all"> = {convertProduct(slider)} {product}</span></p>
<Slider bind:slider={slider} bind:clicked={clicked} cssWidth="80%" convert={convertMoney}/>

