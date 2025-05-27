<script>
    import { selectedNodeId } from "$lib/store";

    // Style updater component that applies styles directly to DOM nodes
    // Props
    let {
        vdom = null
    } = $props();

    // Export the style update function
    export function updateStyle(nodeId, name, value) {
        console.log(`StyleUpdater: Updating style ${name}=${value} for node ${nodeId}`);
        
        // Try to update via VDom API first
        if (vdom && typeof vdom.getNode === 'function') {
            try {
                const node = vdom.getNode(nodeId);
                if (node && typeof node.setStyle === 'function') {
                    node.setStyle(name, value);
                    return true;
                }
            } catch (error) {
                console.error("Error using VDom API:", error);
            }
        }
        
        // If VDom API fails, try direct DOM approach
        try {
            // Find the actual DOM node
            const domNode = document.getElementById(nodeId);
            if (domNode) {
                // Convert camelCase to kebab-case if needed
                const cssName = name.replace(/([A-Z])/g, match => `-${match.toLowerCase()}`);
                domNode.style[name] = value; // Try direct property access
                domNode.style.setProperty(cssName, value); // Also try setProperty
                
                // Try to notify VDom of the change
                if (vdom && vdom.nodes && vdom.nodes[nodeId]) {
                    vdom.nodes[nodeId].styles[name] = value;
                    if (typeof vdom.updateCount !== 'undefined') {
                        vdom.updateCount++;
                    }
                }
                
                return true;
            }
        } catch (error) {
            console.error("Error applying style directly:", error);
        }
        
        return false;
    }
    
    // Remove a style from a node
    export function removeStyle(nodeId, name) {
        console.log(`StyleUpdater: Removing style ${name} from node ${nodeId}`);
        
        // Try to update via VDom API first
        if (vdom && typeof vdom.getNode === 'function') {
            try {
                const node = vdom.getNode(nodeId);
                if (node && typeof node.setStyle === 'function') {
                    node.setStyle(name, ''); // Set empty string to remove
                    return true;
                }
            } catch (error) {
                console.error("Error using VDom API:", error);
            }
        }
        
        // If VDom API fails, try direct DOM approach
        try {
            // Find the actual DOM node
            const domNode = document.getElementById(nodeId);
            if (domNode) {
                // Convert camelCase to kebab-case if needed
                const cssName = name.replace(/([A-Z])/g, match => `-${match.toLowerCase()}`);
                domNode.style[name] = null; // Try direct property access
                domNode.style.removeProperty(cssName); // Also try removeProperty
                
                // Try to notify VDom of the change
                if (vdom && vdom.nodes && vdom.nodes[nodeId]) {
                    delete vdom.nodes[nodeId].styles[name];
                    if (typeof vdom.updateCount !== 'undefined') {
                        vdom.updateCount++;
                    }
                }
                
                return true;
            }
        } catch (error) {
            console.error("Error removing style directly:", error);
        }
        
        return false;
    }
    
    // Get all styles for a node
    export function getStyles(nodeId) {
        // Try to get styles via VDom API first
        if (vdom && vdom.nodes && vdom.nodes[nodeId]) {
            return vdom.nodes[nodeId].styles || {};
        }
        
        // If VDom API fails, try direct DOM approach
        try {
            const domNode = document.getElementById(nodeId);
            if (domNode) {
                const computedStyle = window.getComputedStyle(domNode);
                const styles = {};
                
                // Get all applied styles
                for (let i = 0; i < domNode.style.length; i++) {
                    const name = domNode.style[i];
                    // Convert kebab-case to camelCase
                    const camelName = name.replace(/-([a-z])/g, (_, p1) => p1.toUpperCase());
                    styles[camelName] = domNode.style[name];
                }
                
                return styles;
            }
        } catch (error) {
            console.error("Error getting styles directly:", error);
        }
        
        return {};
    }
    
    // Utility function to convert between kebab-case and camelCase
    export function kebabToCamel(kebab) {
        return kebab.replace(/-([a-z])/g, (_, char) => char.toUpperCase());
    }
    
    export function camelToKebab(camel) {
        return camel.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
    }
</script>

<!-- This is a utility component with no visible UI -->