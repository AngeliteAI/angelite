<script>
    import { onMount } from "svelte";
    export let form;
    function on_newsletter_submit() {
        document.getElementById("newsletter").submit();
    }
    onMount(() => {
        window.on_newsletter_submit = on_newsletter_submit;
    });
</script>

<svelte:head>
    <script
        src="https://www.google.com/recaptcha/enterprise.js?render=6LdrJbsqAAAAANfvTFn0RwvfqvdvgR7QXdyGxOt9"
    ></script>
    <!-- Your code -->
</svelte:head>
<header>
    <span
        ><h1>tech<span class="thin">kit</span></h1>
        <h6 class="thin">code at ⚡ speed</h6></span
    >
</header>
<div id="hero">
    <form action="?/newsletter" id="newsletter" method="POST">
        <input
            name="email"
            type="email"
            placeholder="your email will never be sold or bartered"
        />
        <button
            class="g-recaptcha"
            data-sitekey="6LdrJbsqAAAAANfvTFn0RwvfqvdvgR7QXdyGxOt9"
            data-callback="on_newsletter_submit"
            data-action="submit"
        >
            ⚡ power up
        </button>
    </form>
    <p>
        {#if form?.message}
            {form?.message}
        {/if}
    </p>
    <span>
        <a href="https://github.com/blockglow/techkit"
            ><img src="/github.svg" /></a
        >
        <a href="https://buy.stripe.com/eVa6qdafScGv52M7ss">contribute</a>
    </span>
</div>
<footer>
    <span class="lightning"></span>
</footer>

<style>
    @font-face {
        src: url("/mont-heavy.otf");
        font-family: "Mont";
        font-weight: bold;
    }
    @font-face {
        src: url("/mont-light.otf");
        font-family: "Mont";
        font-weight: lighter;
    }
    :global(*) {
        font-family: "Mont", sans-serif;
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        color: rgb(235, 250, 250);
    }

    :global(body) {
        width: 100vw;
        height: 100vh;
        background-color: rgb(18, 18, 26);
        overflow-x: hidden;
    }

    header {
        width: 100%;
        padding: 1em;
        font-size: xx-large;
        flex-direction: row;
        display: flex;
        justify-content: center;
    }

    header span {
        align-items: center;
    }

    footer {
        width: 100%;
        height: 300px;
        position: relative;
        overflow: visible;
    }
    footer::after {
        content: "";
        position: absolute;
        bottom: -400px;
        left: 50%;
        transform: translateX(-50%);
        width: 100vw;
        height: 100vh;
        background: radial-gradient(
            circle at center,
            rgba(255, 0, 0, 0.2) 0%,
            rgba(255, 165, 0, 0.2) 15%,
            rgba(255, 255, 0, 0.2) 30%,
            rgba(0, 128, 0, 0.2) 45%,
            rgba(0, 0, 255, 0.2) 60%,
            rgba(75, 0, 130, 0.2) 75%,
            rgba(238, 130, 238, 0.2) 90%
        );
        background-size: 200% 200%;
        animation: gradient 30s ease infinite;
        pointer-events: none;
        z-index: 0;
        opacity: 0.6;
        filter: blur(100px);
    }

    #hero {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        height: 30%;
        text-align: center;
    }

    .thin {
        font-weight: lighter;
    }

    #hero > * {
        margin-top: 2em;
    }

    #hero span {
        display: flex;
        min-width: 2em;
        flex-direction: row;
        font-size: xx-large;
    }

    #hero span > * {
        margin-left: 0.25em;
        margin-right: 0.2em;
    }

    #hero span h1:nth-of-type(2) {
        transform: translateX(-0.1em);
    }

    .lightning {
        position: absolute;
        left: calc(50% - 150px);
        width: 300px;
        height: 300px;
        background: linear-gradient(
            -45deg,
            red,
            orange,
            yellow,
            green,
            blue,
            indigo,
            violet
        );
        background-size: 200% 200%;
        animation: gradient 30s ease infinite;
        mask-image: url("/lightning.svg");
        mask-mode: alpha;
        mask-repeat: no-repeat;
        transform: translateY(5em) scale(1.5);
    }

    header {
        width: 100%;
    }
    header span {
        display: flex;
        flex-direction: column;
    }

    header span h1 {
        display: flex;
    }

    #hero span a {
        font-weight: lighter;
        font-size: 1em;
        text-decoration: none;
        color: white;
    }

    #hero span a img {
        filter: brightness(100);
        width: 30px;
    }

    #hero form {
        display: flex;
        min-width: 500px;
        max-width: 600px;
    }

    #hero form button {
        padding: 0.5em;
        border-radius: 0em 0.5em 0.5em 0em;
        text-decoration: none;
        color: white;
        border: 0.1em solid purple;
        border-left: none;
        background-color: transparent;
        font-size: medium;
        cursor: pointer;
    }
    #hero form input {
        flex-grow: 1;
        padding: 0.5em;
        border-radius: 0.5em 0em 0em 0.5em;
        border: 0.1em solid purple;
        background-color: transparent;
        font-size: medium;
        color: white;
    }

    @keyframes gradient {
        0% {
            background-position: 0% 50%;
        }
        50% {
            background-position: 100% 50%;
        }
        100% {
            background-position: 0% 50%;
        }
    }
</style>
