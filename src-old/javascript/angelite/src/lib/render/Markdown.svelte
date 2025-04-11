<script>
    let { doc = "" } = $props();
    let container = $state();
    
    let out = $state([]);

    $effect(() => {
        if (!doc) return [];
        
        const output = [];
        let index = 0;
        
        while (index < doc.length) {
            // Handle headings
            if (doc[index] === '#') {
                let level = 0;
                // Count # symbols
                while (index < doc.length && doc[index] === '#') {
                    level++;
                    index++;
                }
                
                // Skip whitespace
                if (index < doc.length && doc[index] === ' ') {
                    index++;
                }
                
                // Capture heading text
                let headingText = "";
                while (index < doc.length && doc[index] !== '\n') {
                    headingText += doc[index];
                    index++;
                }
                
                // Skip the newline
                if (index < doc.length) index++;
                
                output.push({ type: 'heading', level, text: headingText });
                continue;
            }
            
            // Handle bold and italic
            if (doc[index] === '*') {
                const startIndex = index;
                let count = 0;
                
                // Count consecutive * symbols
                while (index < doc.length && doc[index] === '*') {
                    count++;
                    index++;
                }
                
                // Find matching closing asterisks
                let content = "";
                let foundClosing = false;
                
                while (index < doc.length) {
                    if (doc[index] === '*') {
                        let closingCount = 0;
                        const closingStart = index;
                        
                        while (index < doc.length && doc[index] === '*') {
                            closingCount++;
                            index++;
                        }
                        
                        if (closingCount === count) {
                            foundClosing = true;
                            break;
                        } else {
                            // Not matching, add to content
                            content += doc.substring(closingStart, index);
                        }
                    } else {
                        content += doc[index];
                        index++;
                    }
                }
                
                if (foundClosing) {
                    if (count === 1) {
                        output.push({ type: 'italic', text: content });
                    } else if (count === 2) {
                        output.push({ type: 'bold', text: content });
                    } else if (count === 3) {
                        output.push({ type: 'bold-italic', text: content });
                    } else {
                        // Just treat as plain text with asterisks
                        output.push({ type: 'text', text: doc.substring(startIndex, index) });
                    }
                } else {
                    // No closing asterisks found, treat as plain text
                    output.push({ type: 'text', text: doc.substring(startIndex, index) });
                }
                
                continue;
            }
            
            // Handle paragraph text
            let textContent = "";
            const startIndex = index;
            
            while (index < doc.length && 
                   doc[index] !== '#' && 
                   doc[index] !== '*' && 
                   doc[index] !== '\n') {
                textContent += doc[index];
                index++;
            }
            
            if (textContent.trim().length > 0) {
                output.push({ type: 'text', text: textContent });
            }
            
            // Handle newlines
            if (index < doc.length && doc[index] === '\n') {
                // Check for double newline (paragraph break)
                if (index + 1 < doc.length && doc[index + 1] === '\n') {
                    output.push({ type: 'paragraph-break' });
                    index += 2; // Skip both newlines
                } else {
                    output.push({ type: 'line-break' });
                    index++; // Skip single newline
                }
                continue;
            }
            
            // If we haven't moved the index, increment to avoid infinite loop
            if (index === startIndex) {
                index++;
            }
        }
        
        out = output;
    });
</script>

<div bind:this={container}>
    {#each out as item}
        {#if item.type === 'heading'}
            {#if item.level === 1}
                <h1 class="text-5xl font-light leading-tight tracking-tight mb-6">{item.text}</h1>
            {:else if item.level === 2}
                <h2 class="text-4xl font-light leading-tight tracking-tight mb-5">{item.text}</h2>
            {:else if item.level === 3}
                <h3 class="text-3xl font-light leading-tight tracking-tight mb-4">{item.text}</h3>
            {:else if item.level === 4}
                <h4 class="text-2xl font-light leading-tight tracking-tight mb-3">{item.text}</h4>
            {:else if item.level === 5}
                <h5 class="text-xl font-light leading-tight tracking-tight mb-2">{item.text}</h5>
            {:else}
                <h6 class="text-lg font-light leading-tight tracking-tight mb-2">{item.text}</h6>
            {/if}
        {:else if item.type === 'bold'}
            <strong class="font-semibold">{item.text}</strong>
        {:else if item.type === 'italic'}
            <em class="italic">{item.text}</em>
        {:else if item.type === 'bold-italic'}
            <strong class="font-semibold"><em class="italic">{item.text}</em></strong>
        {:else if item.type === 'text'}
            <span class="text-base leading-relaxed">{item.text}</span>
        {:else if item.type === 'paragraph-break'}
            <div class="h-6"></div>
        {:else if item.type === 'line-break'}
            <br>
        {/if}
    {/each}
</div>

