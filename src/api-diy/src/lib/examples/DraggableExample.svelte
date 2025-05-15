<script>
    import SimpleDraggable from '$lib/components/SimpleDraggable.svelte';
    
    // Reference to draggable instances
    let box1;
    let box2;
    let box3;
    
    // Track positions for display
    let position1 = { x: 50, y: 50 };
    let position2 = { x: 200, y: 100 };
    let position3 = { x: 350, y: 150 };
    
    // Handle events from the first box
    function onDragMove(event) {
        position1 = event.detail;
    }
    
    // Reset all boxes to their initial positions
    function resetAll() {
        box1.reset();
        box2.reset();
        box3.reset();
    }
    
    // Set box 3 to center of container
    function centerBox3() {
        const container = document.getElementById('draggable-container');
        if (container) {
            const rect = container.getBoundingClientRect();
            const centerX = rect.width / 2 - 50; // Half container width minus half box width
            const centerY = rect.height / 2 - 50; // Half container height minus half box height
            box3.setPosition(centerX, centerY);
        }
    }
</script>

<div class="container">
    <h1>Draggable Examples</h1>
    
    <div id="draggable-container" class="playground">
        <!-- Basic draggable with event handling -->
        <SimpleDraggable 
            bind:this={box1}
            x={position1.x} 
            y={position1.y}
            on:dragmove={onDragMove}
        >
            <div class="box blue">
                <p>Drag Me</p>
                <p>Position: {Math.round(position1.x)}, {Math.round(position1.y)}</p>
            </div>
        </SimpleDraggable>
        
        <!-- Custom styled draggable -->
        <SimpleDraggable bind:this={box2} x={position2.x} y={position2.y}>
            <div class="box green">
                <p>Styled Box</p>
                <p>Try dragging me too!</p>
            </div>
        </SimpleDraggable>
        
        <!-- Conditionally disabled draggable -->
        <SimpleDraggable bind:this={box3} x={position3.x} y={position3.y} disabled={false}>
            <div class="box orange">
                <p>Controllable</p>
                <p>Use buttons below</p>
            </div>
        </SimpleDraggable>
    </div>
    
    <div class="controls">
        <button on:click={resetAll}>Reset All Positions</button>
        <button on:click={centerBox3}>Center Orange Box</button>
    </div>
    
    <div class="instructions">
        <h2>How to use SimpleDraggable:</h2>
        <pre>
import SimpleDraggable from '$lib/components/SimpleDraggable.svelte';

// Basic usage
&lt;SimpleDraggable x={100} y={100}&gt;
    &lt;div&gt;Your content here&lt;/div&gt;
&lt;/SimpleDraggable&gt;

// With events
&lt;SimpleDraggable 
    on:dragstart={(e) => console.log('Started', e.detail)}
    on:dragmove={(e) => console.log('Moving', e.detail)}
    on:dragend={(e) => console.log('Ended', e.detail)}
&gt;
    &lt;div&gt;Event handling&lt;/div&gt;
&lt;/SimpleDraggable&gt;
        </pre>
    </div>
</div>

<style>
    .container {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
        max-width: 800px;
        margin: 0 auto;
        padding: 20px;
    }
    
    .playground {
        position: relative;
        height: 400px;
        border: 2px solid #eee;
        border-radius: 8px;
        margin: 20px 0;
        overflow: hidden;
    }
    
    .box {
        width: 150px;
        height: 150px;
        border-radius: 8px;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        color: white;
        font-weight: bold;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        padding: 10px;
        text-align: center;
    }
    
    .blue {
        background-color: #3b82f6;
    }
    
    .green {
        background-color: #10b981;
    }
    
    .orange {
        background-color: #f97316;
    }
    
    .controls {
        margin: 20px 0;
        display: flex;
        gap: 10px;
    }
    
    button {
        padding: 8px 16px;
        background-color: #4b5563;
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-weight: 500;
    }
    
    button:hover {
        background-color: #374151;
    }
    
    .instructions {
        margin-top: 30px;
        padding: 20px;
        background-color: #f9fafb;
        border-radius: 8px;
    }
    
    pre {
        background-color: #1e293b;
        color: #e2e8f0;
        padding: 15px;
        border-radius: 4px;
        overflow-x: auto;
        font-family: monospace;
        font-size: 14px;
    }
    
    h1 {
        color: #1e293b;
    }
    
    h2 {
        color: #334155;
        font-size: 1.25rem;
    }
    
    p {
        margin: 5px 0;
    }
</style>