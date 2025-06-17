import * as THREE from "three";
import vertexShader from "./shaders/grid.vert";
import fragmentShader from "./shaders/grid.frag";

export default class Grid {
  constructor(canvas) {
    console.log("Creating grid...");
    this.scene = new THREE.Scene();
    this.canvas = canvas;
    const frustumSize = Math.max(
      this.canvas.parentElement.offsetWidth,
      this.canvas.parentElement.offsetHeight,
    );
    const aspect =
      this.canvas.parentElement.offsetWidth /
      this.canvas.parentElement.offsetHeight;

    this.camera = new THREE.OrthographicCamera(
      (frustumSize * aspect) / -2,
      (frustumSize * aspect) / 2,
      frustumSize / 2,
      frustumSize / -2,
      1,
      2000,
    );

    this.camera.position.set(0, 0, 1000);
    this.camera.lookAt(0, 0, 0);

    // Track scroll position
    this.scrollY = 0;

    this.uniforms = {
      time: { value: 0 },
      mousePos: { value: new THREE.Vector2(0, 0) },
      resolution: {
        value: new THREE.Vector2(
          this.canvas.parentElement.offsetWidth,
          this.canvas.parentElement.offsetHeight,
        ),
      },
      baseColor: { value: new THREE.Vector3(0.01, 0.02, 0.03) },
      activeColor: { value: new THREE.Vector3(0.6, 0.2, 0.9) },
      influenceRadius: { value: 256.0 },
      scrollOffset: { value: 0 }, // Add this
    };

    this.material = new THREE.ShaderMaterial({
      uniforms: this.uniforms,
      vertexShader,
      fragmentShader,
      transparent: true,
      side: THREE.DoubleSide,
    });

    this.renderer = new THREE.WebGLRenderer({
      canvas,
      alpha: true,
      antialias: true,
    });

    this.renderer.setSize(
      this.canvas.parentElement.offsetWidth,
      this.canvas.parentElement.offsetHeight,
    );
    this.renderer.setPixelRatio(window.devicePixelRatio);

    this.baseColor = new THREE.Color();
    this.clock = new THREE.Clock();
    this.mouse = new THREE.Vector2(100, 100);
    this.lastMousePos = new THREE.Vector2(0, 0);

    // Bind methods
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseLeave = this.handleMouseLeave.bind(this);
    this.handleScroll = this.handleScroll.bind(this);
    this.resize = this.resize.bind(this);
    this.animate = this.animate.bind(this);

    this.init();
    this.setupEvents();
    this.resize();
  }

  init() {
    const positions = [];
    const indices = [];
    const lineWidth = 1.3;
    const cellSize = 40;

    // Calculate grid dimensions to ensure full viewport coverage with some overflow
    const viewportWidth = this.canvas.parentElement.offsetWidth;
    const viewportHeight = this.canvas.parentElement.offsetHeight;
    const aspectRatio = viewportWidth / viewportHeight;

    // Use frustum size to match camera's view
    const frustumSize = Math.max(
      this.canvas.parentElement.offsetWidth,
      this.canvas.parentElement.offsetHeight,
    );
    const halfWidth = (frustumSize * aspectRatio) / 2;
    const halfHeight = frustumSize / 2;

    // Add 20% padding to ensure coverage during rotation/movement
    const padding = 0.2;
    const paddedWidth = halfWidth * (1 + padding);
    const paddedHeight = halfHeight * (1 + padding);

    let vertexIndex = 0;

    // Helper function to create a thick line
    const addThickLine = (x1, y1, x2, y2) => {
      const dx = x2 - x1;
      const dy = y2 - y1;
      const length = Math.sqrt(dx * dx + dy * dy);

      const nx = (-dy / length) * lineWidth;
      const ny = (dx / length) * lineWidth;

      positions.push(
        x1 + nx,
        y1 + ny,
        0,
        x1 - nx,
        y1 - ny,
        0,
        x2 + nx,
        y2 + ny,
        0,
        x2 - nx,
        y2 - ny,
        0,
      );

      indices.push(
        vertexIndex,
        vertexIndex + 1,
        vertexIndex + 2,
        vertexIndex + 1,
        vertexIndex + 3,
        vertexIndex + 2,
      );

      vertexIndex += 4;
    };

    // Create vertical lines
    for (let x = -paddedWidth; x <= paddedWidth; x += cellSize) {
      addThickLine(x, -paddedHeight, x, paddedHeight);
    }

    // Create horizontal lines
    for (let y = -paddedHeight; y <= paddedHeight; y += cellSize) {
      addThickLine(-paddedWidth, y, paddedWidth, y);
    }

    this.geometry = new THREE.BufferGeometry();
    this.geometry.setAttribute(
      "position",
      new THREE.Float32BufferAttribute(positions, 3),
    );
    this.geometry.setIndex(indices);

    this.lines = new THREE.Mesh(this.geometry, this.material);
    this.scene.add(this.lines);
  } // ... keep your existing init() method ...

  setupEvents() {
    if (this.renderer.domElement) {
      this.renderer.domElement.removeEventListener(
        "mousemove",
        this.handleMouseMove,
      );
      this.renderer.domElement.removeEventListener(
        "mouseleave",
        this.handleMouseLeave,
      );
      window.removeEventListener("resize", this.resize);
      window.removeEventListener("scroll", this.handleScroll);
    }

    this.renderer.domElement.addEventListener(
      "mousemove",
      this.handleMouseMove,
    );
    this.renderer.domElement.addEventListener(
      "mouseleave",
      this.handleMouseLeave,
    );
    window.addEventListener("resize", this.resize);
    window.addEventListener("scroll", this.handleScroll);
  }

  handleMouseMove(event) {
    this.updateMousePosition(event.clientX, event.clientY);
  }
  updateMousePosition(x, y) {
    const rect = this.renderer.domElement.getBoundingClientRect();

    // Calculate position relative to viewport without scroll offset
    const viewportX = x - rect.left;
    const viewportY = y - rect.top; // Just use viewport position

    // Convert to normalized device coordinates (-1 to +1)
    const mouseX = (viewportX / rect.width) * 2 - 1;
    const mouseY = -(viewportY / rect.height) * 2 + 1;

    // Create vector for unprojection
    const vector = new THREE.Vector3(mouseX, mouseY, 0);
    vector.unproject(this.camera);

    // Store the last known mouse position
    this.lastMousePos.set(x, y);

    // Update shader uniform with world coordinates
    // Subtract the scroll offset since the grid moves up with scroll
    this.uniforms.mousePos.value.x = vector.x;
    this.uniforms.mousePos.value.y =
      vector.y - this.uniforms.scrollOffset.value / 8.0;
  }

  handleScroll = () => {
    this.uniforms.scrollOffset.value = window.scrollY;

    // Update mouse position if we have a last known position
    if (this.lastMousePos.x !== 0 || this.lastMousePos.y !== 0) {
      this.updateMousePosition(this.lastMousePos.x, this.lastMousePos.y);
    }
  };
  handleMouseLeave() {
    this.lastMousePos.set(0, 0);
    this.uniforms.mousePos.value.set(-10000, -10000);
  }

  animate() {
    const time = this.clock.getElapsedTime();
    this.uniforms.time.value = time;

    // Subtle base color animation
    const baseHue = 0.75 + Math.sin(time * 0.05) * 0.02;
    const baseSat = 0.3 + Math.sin(time * 0.03) * 0.1;
    const baseLight = 0.02 + Math.sin(time * 0.07) * 0.01;

    this.baseColor.setHSL(baseHue, baseSat, baseLight);
    this.uniforms.baseColor.value.set(
      this.baseColor.r,
      this.baseColor.g,
      this.baseColor.b,
    );

    // Dynamic active color
    const activeHue = 0.8 + Math.sin(time * 0.1) * 0.1;
    const activeSat = 0.8 + Math.sin(time * 0.15) * 0.2;
    const activeLight = 0.2 + Math.sin(time * 0.2) * 0.1;

    const activeColor = new THREE.Color();
    activeColor.setHSL(activeHue, activeSat, activeLight);
    this.uniforms.activeColor.value.set(
      activeColor.r,
      activeColor.g,
      activeColor.b,
    );

    // Render
    this.renderer.render(this.scene, this.camera);
    this.animationFrameId = requestAnimationFrame(this.animate);
  }

  destroy() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
    }

    this.renderer.domElement.removeEventListener(
      "mousemove",
      this.handleMouseMove,
    );
    this.renderer.domElement.removeEventListener(
      "mouseleave",
      this.handleMouseLeave,
    );
    window.removeEventListener("resize", this.resize);
    window.removeEventListener("scroll", this.handleScroll);

    this.scene.remove(this.lines);
    this.geometry.dispose();
    this.material.dispose();
    this.renderer.dispose();
  }

  updateGridGeometry() {
    const positions = [];
    const indices = [];
    const lineWidth = 1.0;
    const cellSizeX = 40;
    const cellSizeY = (40 * window.innerHeight) / window.innerWidth;

    const viewportWidth = this.canvas.parentElement.offsetWidth;
    const viewportHeight = this.canvas.parentElement.offsetHeight;
    const aspectRatio = viewportWidth / viewportHeight;

    const frustumSize = Math.max(
      this.canvas.parentElement.offsetWidth,
      this.canvas.parentElement.offsetHeight,
    );
    const halfWidth = (frustumSize * aspectRatio) / 2;
    const halfHeight = frustumSize / 2;

    const padding = 0.2;
    const paddedWidth = halfWidth * (1 + padding);
    const paddedHeight = halfHeight * (1 + padding);

    let vertexIndex = 0;

    const addThickLine = (x1, y1, x2, y2) => {
      const dx = x2 - x1;
      const dy = y2 - y1;
      const length = Math.sqrt(dx * dx + dy * dy);

      const nx = (-dy / length) * lineWidth;
      const ny = (dx / length) * lineWidth;

      positions.push(
        x1 + nx,
        y1 + ny,
        0,
        x1 - nx,
        y1 - ny,
        0,
        x2 + nx,
        y2 + ny,
        0,
        x2 - nx,
        y2 - ny,
        0,
      );

      indices.push(
        vertexIndex,
        vertexIndex + 1,
        vertexIndex + 2,
        vertexIndex + 1,
        vertexIndex + 3,
        vertexIndex + 2,
      );

      vertexIndex += 4;
    };

    // Create vertical lines
    for (let x = -paddedWidth; x <= paddedWidth; x += cellSizeX) {
      addThickLine(x, -paddedHeight, x, paddedHeight);
    }

    // Create horizontal lines
    for (let y = -paddedHeight; y <= paddedHeight; y += cellSizeY) {
      addThickLine(-paddedWidth, y, paddedWidth, y);
    }

    this.geometry.setAttribute(
      "position",
      new THREE.Float32BufferAttribute(positions, 3),
    );
    this.geometry.setIndex(indices);
  }

  resize() {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const aspect = width / height;
    const frustumSize = Math.max(width, height);

    // Update camera
    this.camera.left = (-frustumSize * aspect) / 4;
    this.camera.right = (frustumSize * aspect) / 4;
    this.camera.top = frustumSize / 2;
    this.camera.bottom = -frustumSize / 2;
    this.camera.updateProjectionMatrix();

    // Update renderer and uniforms
    this.renderer.setSize(
      this.canvas.parentElement.offsetWidth,
      this.canvas.parentElement.offsetHeight,
    );
    this.uniforms.resolution.value.set(width, height);
    this.uniforms.influenceRadius.value = frustumSize / 6;

    // Update grid geometry
    this.updateGridGeometry();
  }
}
