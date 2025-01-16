<header><h1>Techkit</h1></header>
<div id="hero">
<span><h1>Code</h1><h1>at</h1><span class="lightning"></span><h1>Speed</h1></span>
<span>
<a>Contribute</a>
<a>Repository</a>
</span>
<form>
    <input placeholder="Your email will never be sold or bartered."/>
    <button>Keep me updated!</button>
</form>
</div>
<footer>
    <h6>Copyright Blockglow 2024, All rights reserved</h6>
    <h6>Techkit is open-source under the MIT license</h6>
</footer>

<style>
@font-face {
    src: url("/mundial.otf");
         font-family: 'Mundial';
}
    :global(*) {
        font-family: 'Mundial', sans-serif;
        margin: 0;
        padding: 0;
        box-sizing: border-box;
        color: rgb(235, 250, 250)
    }

    :global(body) {
        width: 100vw;
        height:100vh;
               background-color: rgb(18, 18, 26);
    }

    header {
        width: 100%;
    padding: 1em;
             font-size: xx-large;
            flex-direction: row;
            display: flex;
            justify-content: center;
    }


#hero {
    display: flex;
             flex-direction: column;
    justify-content: center;
    align-items: center;
    height: 50%;
text-align: center;
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
        width: 100%;
        background: linear-gradient(-45deg, red, orange, yellow, green, blue, indigo, violet);
	background-size: 400% 400%;
	animation: gradient 15s ease infinite;
        mask-image: url("/lightning.svg");
        mask-mode: alpha;
        mask-repeat: no-repeat;
        transform: translateY(.2em) scale(1.5);
    }

    #hero span a {
        margin: 0.5em;
        padding: 0.5em;
        border: 1px solid white;
        border-radius: 0.5em;
        text-decoration: none;
        color: white;
               font-size: larger;
    }
    

    #hero form {
        display: grid;
                 min-width: 500px;
                 max-width: 600px;
        grid-template-columns: 4.5fr 1fr;

    }

    #hero form button {
        padding: 0.5em;
        border-radius: 0em 0.5em 0.5em 0em;
        text-decoration: none;
        color: white;
        background-color: transparent;
        font-size: medium;
    }
#hero form input {
    padding: 0.5em;
        border-radius: 0.5em 0em 0em  0.5em;
                 font-size: medium;
                 color:rgb(18, 18, 26);
}

    @keyframes gradient {

	0% {
		background-position: 0% 50%;
	}
	50% {
		background-position: 100% 50%;
	}
}
</style>