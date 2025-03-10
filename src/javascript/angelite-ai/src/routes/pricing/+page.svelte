<script>
    import {onMount} from "svelte";
    import { Slider } from "angelite/ui";
    let slider = $state(0.5);

    function tier() {

    }
    
    function lines(slider) {
        const g = 577777;
        return Math.floor(g * (Math.pow(Math.E, slider)) - g);
    }

    const tiers = [
    {
      name:  "Hobby"
    }, 
    {
      name:  "Pro"
    },
    {  name: "Business"

    }];
    </script>

<div id="hero" class="relative flex flex-col justify-end items-start h-full">
    <span class="select-none w-full">
    <h1 class="text-4xl">Transparent and Flexible Pricing.</h1>
    <h2 class="text-2xl text-secondary">
        Usage based to scale with you.<br/>Move the slider to understand your usage.
    </h2>
        <br/>
        <br/>
    <h1 class="text-2xl">Bind (generation)</h1>
    <h2 class="text-1xl text-secondary">Measured in compiled lines.</h2>
    <br/>
    <span class=" absolute left-[16.666%] w-[66.66%]">
    <Slider bind:slider={slider} convert={lines}/>
    </span>
    </span>
    <br/>
    <br/>
    <br/>
    <span class="select-none w-full flex justify-center text-3xl">
    <div id="details" class="border-accent relative border w-full rounded h-200">
    <div class="absolute inset-0 flex">
      {#each tiers as tier, i (i)}
      <div class=" flex-1 h-20 border rounded-xs border-secondary text-center">
        <p class="leading-20 align-middle">{i}{tier.name}</p>
      </div>

      {/each}
    </div>
    </div>
    </span>
</div>

<style>
    #tiers div {
        width: 33%;
    }
</style>
