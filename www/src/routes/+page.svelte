<header><span><h1>tech<span class="thin">kit</span></h1><h6 class="thin">code at lightning speed</h6></span></header>
<div id="hero">
<form>
    <input placeholder="your email will never be sold or bartered."/>
    <button>stay updated</button>
</form>
<span >
<a><img src="/github.svg"></a>
<a>contribute</a>
</span>
</div>
<footer>
    <span class="lightning"></span>
</footer>
<style>
@font-face {
    src: url("/mont-heavy.otf");
         font-family: 'Mont';
         font-weight: bold;
}
@font-face {
    src: url("/mont-light.otf");
         font-family: 'Mont';
         font-weight: lighter;
}
    :global(*) {
        font-family: 'Mont', sans-serif;
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

    header span {
        align-items: center;
    }

    footer {
        width: 100%;
               height: 300px;
                       position: relative;
    }


#hero {
    display: flex;
             flex-direction: column;
    justify-content: center;
    align-items: center;
    height: 50%;
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
        background: linear-gradient(-45deg, red, orange, yellow, green, blue, indigo, violet);
	background-size: 800% 800%;
	animation: gradient 30s ease infinite;
        mask-image: url("/lightning.svg");
        mask-mode: alpha;
        mask-repeat: no-repeat;
        transform: translateY(.2em) scale(1.5);
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
        border: 0.1em solid purple;
                border-left: none;
        background-color: transparent;
        font-size: medium;
        cursor: pointer;
    }
#hero form input {
    padding: 0.5em;
        border-radius: 0.5em 0em 0em  0.5em;
        border: 0.1em solid purple;
        background-color: transparent;
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