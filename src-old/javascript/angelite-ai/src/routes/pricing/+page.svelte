<script>
    import {onMount} from "svelte";
    import { SliderCaption } from "angelite/ui";
    import { Button } from "angelite/ui";
    let app_url = "";
    let slider = $state(0.5);
    let credits = $derived(Math.floor((slider * 100) * 100) / 100);

    function tier() {

    }
    
    function lines(slider) {
        const g = 577777;
        return Math.floor(g * (Math.pow(Math.E, slider)) - g);
    }

    const accomodations = [
        {
            name: "Free email support (always)"
        },
        {
            name: "Chat during business hours"
        },
        {
            name: "Chat 24/7"
        },
        {
            name: "Phone call during business hours"
        },
        {
            name: "Phone call 24/7"
        }
    ]

    const tiersDim = [
    {
      name:  "Hobby",
      given: [0,1],
      min: 10
    }, 
    {
      name:  "Pro",
      given: [0,2,3],
      min: 80
    },
    {  name: "Business",
    given: [0,2,4],
    min: 99

    }];

    let tiersFact = $derived([
    {
      active: tierActive(credits, 0)
    }, 
    {
      active: tierActive(credits, 1)
    },
    {
    active: tierActive(credits, 2)

    }]);


    function tierActive(credits, i) {
            return !(tiersDim[i - 1] && credits < tiersDim[i - 1].min) ^ (tiersDim[i] && credits > tiersDim[i].min);
    }

    function activeTier(credits) {
        for(var i = 0; i < tiersDim.length; i++) {
            if (tierActive(credits, i)) {
                return i;
            }
        }
        return null;
    }

    function activeAccomodations(activeTier) {
        if (!tiersDim[activeTier]) {
            return [];
        }
        var res = [];
        for(var i = 0; i < accomodations.length; i++) {
            for (var j = 0; j < tiersDim[activeTier].given.length; j++) {
                if (i == tiersDim[activeTier].given[j]) {
                    res.push(accomodations[i]);
                }
            }
        }
        return res;
    }

    var grants = $derived(activeAccomodations(activeTier(credits)));

    </script>

<div id="hero" class="relative flex flex-col justify-end items-start h-full">
    <div id="details" class="p-4  w-full rounded">
    <span class="relative select-none w-full">
    <h1 class="text-4xl">Transparent and Flexible Pricing.</h1>
    <h2 class="text-2xl text-hint">
        Usage based to scale with you. <br/>Or commit for greater savings.
    
    </h2>
        <br/>
        <br/>
                    <span class="select-none ">
            <a href={app_url} ><Button min='300px' max='300px' special=true><h1 class="text-2xl">Get Started (for free)</h1></Button><h2 class="text-hint">(no credit card required)</h2></a>
            </span>

        <br/>
        <br/>
        <hr/>
        <br/>
    <div class="relative left-1/10 width-8/10">
    <h1 class="text-2xl">Bind (generation)</h1>
    <h2 class="text-1xl text-hint">Move the slider to measure usage</h2>
    <br/>
    <SliderCaption bind:slider={slider} convertMoney={(slider) => Math.floor(slider * 10000) / 100} convertProduct={(slider) => Math.floor(slider * 1000) * 100} money = "credits" product = "lines of input and output code." />
    </div>
    </span>
    <br/>
    <br/>
    <br/>
    <div class="border border-secondary rounded h-100">
    <span class="select-none 
 relative 
    w-full flex justify-center">
    <div class="box-border inset-0 flex flex-row flex-grow">
      {#each tiersDim as tier, i (i)}
      <div class="relative inset-0 flex-grow h-25 rounded-xs text-center transition-all" class:border-hint={!tiersFact[i].active} class:border={!tiersFact[i].active} class:border-accent={tiersFact[i].active} class:border-4={tiersFact[i].active}>
        <span class:text-hint={!tiersFact[i].active} class:text-accent={tiersFact[i].active}>
        <h1 class="absolute left-0 right-0 leading-20 align-middle text-4xl">{tier.name}</h1>
        <h2 class="absolute left-0 right-0 leading-35 align-middle text-xl transition-all" >
        {#if tiersDim[i - 1]}
            > {tiersDim[i - 1].min} credits / m.
        {:else} 
            10 credits free
        {/if}
        </h2>
        </span>
      </div>

      {/each}
    </div>
    </span>
    <ul class="p-4">
    {#each grants as grant, i (i)}
        <li class="text-2xl">{grant.name}</li>
    {/each}
    </ul>
    </div>
    </div>
</div>

<style>
    #tiers div {
        width: 33%;
    }

    br:before { /* and :after */
    border-bottom:1px dashed white;
    /* content and display added as per porneL's comment */
    content: "";
    display: block;
    }

    li:before {
        content: "➜ ";
       }
</style>

