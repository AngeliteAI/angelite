// grid.vert
uniform float time;
uniform vec2 mousePos;
uniform vec2 resolution;
uniform float influenceRadius;
uniform float scrollOffset;

varying vec2 vPosition;
varying float vTime;

void main() {
    vec4 worldPosition = modelMatrix * vec4(position, 1.0);
    vPosition = worldPosition.xy;
    // Keep the parallax effect on the grid
    vec4 scrolledPosition = vec4(position.x, position.y + scrollOffset / 8.0, position.z, 1.0);
    vTime = time;
    gl_Position = projectionMatrix * modelViewMatrix * scrolledPosition;
}
