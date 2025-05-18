<script lang="ts">
    import { mount } from "svelte";
    import Dom from "$lib/Dom.svelte";
    import { onMount } from "svelte";
    import Document from "$lib/components/Document.svelte";
    import {get} from "svelte/store";
    import VDom from "$lib/VDom.svelte";
    import { virtualScale, activeDocuments } from "$lib/store";

    let localVirtualScale = $derived(get(virtualScale));

</script>

{#if $activeDocuments.length != 0}
{#each $activeDocuments as _, i}
<Document
    bind:activeVDom={$activeDocuments[i].activeVDom}
    virtualScale={localVirtualScale}
    width={$activeDocuments[i].width || 1337}
    height={$activeDocuments[i].height || 1337 }
    selectedNodeId={$activeDocuments[i].selectedNodeId}
/>
{/each}
{/if}

<style>
    .debug-panel {
        position: fixed;
        bottom: 10px;
        right: 10px;
        width: 400px;
        max-height: 400px;
        overflow-y: auto;
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 10px;
        border-radius: 4px;
        font-family: monospace;
        font-size: 12px;
        z-index: 1000;
    }

    .log-container {
        margin-top: 10px;
        border-top: 1px solid #444;
        padding-top: 10px;
        max-height: 200px;
        overflow-y: auto;
    }

    .log-line {
        font-size: 11px;
        margin-bottom: 2px;
        white-space: pre-wrap;
        word-break: break-all;
    }

    .debug {
        margin-top: 20px;
        padding: 10px;
        background: #f0f0f0;
        border-radius: 4px;
        font-family: monospace;
        font-size: 12px;
    }

    .loading {
        padding: 20px;
        background: #eeeeff;
        border-radius: 4px;
        text-align: center;
        font-style: italic;
        color: #6666aa;
    }

    .drag-drop-test-area {
        position: fixed;
        bottom: 20px;
        right: 20px;
        width: 600px;
        background: white;
        border-radius: 8px;
        border: 2px solid #3b82f6;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        padding: 15px;
        z-index: 5000;
    }

    .drag-drop-test-area h3 {
        margin: 0 0 15px 0;
        font-size: 16px;
        color: #3b82f6;
        text-align: center;
    }

    .drop-zone {
        padding: 15px;
        background: #f8f9fc;
        border: 2px dashed #cbd5e1;
        border-radius: 8px;
        margin-bottom: 15px;
    }

    .drop-zone h4 {
        margin: 0 0 10px 0;
        font-size: 14px;
        color: #64748b;
    }

    .nested-container {
        margin: 10px 0;
        padding: 10px;
        background: #f1f5f9;
        border: 1px solid #cbd5e1;
        border-radius: 6px;
    }

    .nested-container.empty {
        min-height: 50px;
        border: 1px dashed #94a3b8;
        background: #f8fafc;
    }

    .nested-header {
        font-size: 12px;
        color: #64748b;
        margin-bottom: 8px;
        font-weight: 500;
    }

    .draggable-item {
        padding: 10px 15px;
        background: white;
        border: 1px solid #e2e8f0;
        border-radius: 6px;
        margin-bottom: 8px;
        cursor: grab;
        position: relative;
        user-select: none;
        transition: background 0.2s;
    }

    .draggable-item:hover {
        background: #f1f5f9;
    }

    .draggable-item .handle {
        position: absolute;
        left: 5px;
        top: 50%;
        transform: translateY(-50%);
        color: #94a3b8;
        font-size: 14px;
    }

    .draggable-item.dragging {
        opacity: 0.7;
        box-shadow: 0 5px 10px rgba(0, 0, 0, 0.15);
    }
</style>
