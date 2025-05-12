<script context="module" lang="ts">
import { writable } from 'svelte/store';

class VNode {
    id: string;
    tagName: string;
    props: Record<string, any>;
    children: string[]; // Assuming children are stored as an array of IDs
    parentId: string | null;
    styleProps: Record<string, any>;

    constructor(id: string, tagName: string, parentId: string | null = null, children: string[] = [], props: Record<string, any> = {}, styleProps: Record<string, any> = {}) {
      this.id = id;
      this.tagName = tagName;
      this.props = props;
      this.children = children;
      this.parentId = parentId;
      this.styleProps = styleProps;
    }
  
    appendChild(childNode: VNode) { // Assuming child is a VNode instance
      childNode.parentId = this.id;
      this.children.push(childNode.id);
    }
  
    setStyle(property: string, value: any) {
      this.styleProps[property] = value;
    }
  
    setProperty(name: string, value: any) {
      this.props[name] = value;
    }
  
    toString(): string {
      return JSON.stringify(this, null, 2);
    }
}


class VDom {
    nodes = $state(new Map<string, VNode>());
    rootNodeId: string | null;

    constructor() {
        this.rootNodeId = null;
        console.log("New VDom instance created");
    }

    getNode(id: string): VNode | undefined {
        return this.nodes.get(id);
    }

    createNode(elementType: string, parentId: string | null): [string, VNode] {
        const id = crypto.randomUUID();
        // Ensure children array is initialized as string[] for VNode constructor
        const element = new VNode(id, elementType, parentId, [], {}, {}); 
        console.log(`Node created: ${id} (${elementType})`);
        return [id, element];
    }

    addNode(elementType: string, parentId: string | null): string {
        const [id, element] = this.createNode(elementType, parentId);

        if (parentId === null) {
            this.rootNodeId = id;
            console.log(`Root node set: ${id}`);
        }

        this.nodes.set(id, element);
        
        if (parentId !== null) {
            const parentNode = this.nodes.get(parentId);
            if (parentNode) {
                console.log(`Adding child ${id} to parent ${parentId}`);
                parentNode.appendChild(element); // Pass the VNode element
                // No need to this.nodes.set(parentId, parentNode) if appendChild mutates parentNode directly 
                // and parentNode is the same object reference from the map. Svelte $state should track deep mutations.
            }
        }
        return id;
    }
    
    printTree() {
        if (!this.rootNodeId) {
            console.log("No root node");
            return;
        }
        
        const printNode = (id: string, depth = 0) => {
            const node = this.nodes.get(id);
            if (!node) return;
            
            const indent = "  ".repeat(depth);
            console.log(`${indent}- ${node.tagName} (${id})`);
            
            if (node.children) { // Check if children exist
                for (const childId of node.children) {
                    printNode(childId, depth + 1);
                }
            }
        };
        
        console.log("VDom Tree:");
        printNode(this.rootNodeId);
    }
}

function initializeActiveVDom(pageRootData: any | null) { // pageRootData matches PageContentNode structure
    console.log("[VDom.svelte] Initializing activeVDom with data:", pageRootData);
    let instance = activeVDom;
    if (!instance) {
        instance = new VDom();
    }
    instance.nodes.clear();
    instance.rootNodeId = null;

    if (!pageRootData) {
        console.log("[VDom.svelte] No page data, creating default placeholder.");
        const rootId = instance.addNode('div', null);
        const h1Id = instance.addNode('h1', rootId);
        const h1Node = instance.getNode(h1Id);
        if (h1Node) h1Node.setProperty('textContent', 'No document loaded or empty (from VDom.svelte).');
        const rootNode = instance.getNode(rootId);
        if (rootNode) rootNode.setProperty('className', 'placeholder-content');
    } else {
        // Recursive function to add nodes from the page data structure
        function recursivelyAddNodesFromPageData(currentVDom: VDom, pageNode: any, parentVNodeId: string | null) {
            const newVNodeId = currentVDom.addNode(pageNode.type, parentVNodeId);
            const newVNode = currentVDom.getNode(newVNodeId);
            if (newVNode) {
                if (pageNode.props) {
                    for (const key in pageNode.props) {
                        newVNode.setProperty(key, pageNode.props[key]);
                    }
                }
                if (pageNode.textContent && !pageNode.props?.textContent) {
                    newVNode.setProperty('textContent', pageNode.textContent);
                }
                if (pageNode.children) {
                    for (const pageChild of pageNode.children) {
                        recursivelyAddNodesFromPageData(currentVDom, pageChild, newVNodeId);
                    }
                }
            }
        }
        recursivelyAddNodesFromPageData(instance, pageRootData, null);
        console.log("[VDom.svelte] populated from page data.");
    }
    activeVDom?.printTree();
}
let activeVDom = $state(new VDom());

// Convert to writable stores for drag state
export const draggedElement = writable<string | null>(null);
export const draggedCurrentX = writable(0);
export const draggedCurrentY = writable(0);

// Helper update functions
export function updateDraggedElement(id: string | null) {
    draggedElement.set(id);
}

export function updateDraggedPosition(x: number, y: number) {
    draggedCurrentX.set(x);
    draggedCurrentY.set(y);
}

export function resetDragState() {
    draggedElement.set(null);
    draggedCurrentX.set(0);
    draggedCurrentY.set(0);
}

export { VNode, VDom, initializeActiveVDom, activeVDom };
</script>
