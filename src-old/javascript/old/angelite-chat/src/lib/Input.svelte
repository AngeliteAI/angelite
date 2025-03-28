<script>
    /** @type {string} */
    export let value = "";
    /** @type {string} */
    export let label = "";
    /** @type {string} */
    export let placeholder = "";

    let focused = false;
    /** @type {HTMLTextAreaElement} */
    let textarea;

    $: hasContent = value.length > 0;

    function adjustHeight() {
        textarea.style.height = "0";
        const maxHeight = Math.min(
            textarea.scrollHeight,
            200,
            window.innerHeight * 0.3,
        );
        textarea.style.height = `${maxHeight}px`;
    }

    /** @param {KeyboardEvent} e */
    function handleKeydown(e) {
        textarea.dispatchEvent(
            new CustomEvent("keydown", {
                detail: e,
                bubbles: true,
            }),
        );
    }
</script>

<div class="relative w-full">
    <div
        class="w-full min-h-[56px] max-h-[200px] p-0 m-0
               !border border-day rounded-lg
               focus-within:!border-angelite focus-within:ring-1 focus-within:!ring-angelite
               transition-colors overflow-hidden"
    >
        <textarea
            bind:this={textarea}
            bind:value
            on:input={adjustHeight}
            on:focus={() => (focused = true)}
            on:blur={() => (focused = false)}
            {placeholder}
            rows="1"
            class="w-full h-full
                   pt-4 px-4
                   text-base text-day
                   bg-transparent
                   leading-7
                   resize-none outline-none
                   overflow-y-auto"
        ></textarea>
    </div>

    <label
        class="absolute left-4 top-4
               text-angelite text-base
               transition-all duration-200 ease-in-out
               pointer-events-none origin-[0]
               bg-space pl-1 pr-1 py-0
               {focused || hasContent ? '-translate-y-7 scale-90' : ''}
               {focused ? 'text-angelite' : 'text-angelite'}"
    >
        {label}
    </label>
</div>

<style>
    textarea {
        box-sizing: border-box;
        margin: 0;
        padding: 16px 16px 0 16px;
    }

    /* Hide scrollbar for Chrome, Safari and Opera */
    textarea::-webkit-scrollbar {
        display: none;
    }

    /* Hide scrollbar for IE, Edge and Firefox */
    textarea {
        -ms-overflow-style: none; /* IE and Edge */
        scrollbar-width: none; /* Firefox */
    }
</style>
