<script>
    let { document } = $props();
    let container = $state();

    let out = $derived(() => {
            let stack = "";
            let state = {};
            let output = []; 

            for(var index = 0; index < document.length; index++) {
                stack.push(document[index]); 

                switch(stack[0]) {
                    case '#':
                        state = { title: true, sig: 1 };
                        break;
                    case '*':
                        state = { title: false, sig: 1 };
                        break;
                }

                if(state.sig) {
                    while(document[index] == stack[0]) {
                        stack.push(document[index]);
                        index += 1;
                    }

                    state.sig = stack.length;

                    if (state.title) {
                        output.push({ }) 
                    } else switch(state.sig) {
                        case 1:
                        case 2:
                    }
                    continue;
                }
            }

            return 
        });
     
</script>

<main bind:this={container}>
</main>
