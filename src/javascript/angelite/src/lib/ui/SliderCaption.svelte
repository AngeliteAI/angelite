<script>
    import Slider from "./Slider.svelte"
    let clicked = $state(false);
    let { slider = $bindable(), convertMoney = (s) => {}, convertProduct = (s) => {}, money, product } = $props();
</script>

<span class="flex flex-row w-[80%]"><p>{convertProduct(slider)} {product} </p><div class="flex-grow"></div><p> <span class:text-hint={!clicked} class:text-accent={clicked} class="transition-all"> = +{convertMoney(slider)} {money}</span></p></span>
<Slider bind:slider={slider} bind:clicked={clicked} cssWidth="80%" convert={convertMoney}/>

