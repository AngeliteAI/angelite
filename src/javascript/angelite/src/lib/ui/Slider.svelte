<script>
import {onMount} from 'svelte';
    import { browser } from '$app/environment'; 
let { slider = $bindable() } = $props();
var sliderWidth = $state();
let smoothing = 1.01;
let sliderSelectorNodePx = $state(0);
let sliderLeft = $derived(Math.max(0, Math.min(sliderWidth, Math.pow(slider, smoothing) * sliderWidth)) - (sliderSelectorNodePx ?? 0) / 2);
let sliderLeftPx = $derived(sliderLeft + 'px');
let clicked = false ;
let sliderNode = $state();
let mouseX = 0;
   
function animate() {
    console.log("2");
    if (clicked) {
        var bound = sliderNode.getBoundingClientRect();
        let newSlider = (mouseX - bound.left - sliderSelectorNodePx / 2) / sliderWidth;
        slider = Math.min(1, Math.max(0, newSlider));
    }
}
    if (browser) {
        console.log("yo");
onmousemove = (event) => {
            if(clicked) {
                mouseX = event.clientX;
                requestAnimationFrame(() => animate());
            }
        };

        onmouseup = () => {
            up();
        };

    }

function click() {
    console.log("1");
    clicked = true;
}
function up() {
        clicked =false; 
}
</script>

<div id="slider" bind:offsetWidth={sliderWidth} bind:this={sliderNode} class="container relative w-full h-10">
    <span class="background absolute w-full top-4.5 h-1 border rounded-full"></span>
    <span id="selector" bind:offsetWidth={sliderSelectorNodePx} on:mousedown={() => click()} on:mouseup={up()}  style:left={sliderLeftPx} class=" circle absolute w-5 h-5 max-w-5 max-h-5 top-2.5 bg-accent rounded-full">
    <p class="top-5 left-[-125px] right-[-125px] text-center absolute">{Math.floor(1e+6 * (Math.pow(Math.E, slider) - 1))}</p>
    </span>
</div>

<style>
    
</style>
