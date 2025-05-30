import { writable } from 'svelte/store'

export const virtualScale = writable(0.2);
export const mouseX = writable(0);
export const mouseY = writable(0);
export const selectedNodeId = writable(null);
export const hoveredNodeId = writable(null);
export const isDraggingAny = writable(false);

export const activeDocuments = writable([{}]);