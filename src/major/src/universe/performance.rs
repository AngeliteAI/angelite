use std::time::{Duration, Instant};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

// Performance profiling for voxel engine
#[derive(Clone)]
pub struct VoxelPerformanceProfiler {
    metrics: Arc<Mutex<PerformanceMetrics>>,
    frame_start: Instant,
}

#[derive(Default)]
pub struct PerformanceMetrics {
    // Frame timing
    pub frame_time: MovingAverage,
    pub fps: f32,
    
    // World generation metrics
    pub sdf_evaluation_time: MovingAverage,
    pub brush_evaluation_time: MovingAverage,
    pub compression_time: MovingAverage,
    pub physics_generation_time: MovingAverage,
    
    // Rendering metrics
    pub culling_time: MovingAverage,
    pub batch_building_time: MovingAverage,
    pub draw_time: MovingAverage,
    pub vertex_pool_updates: u32,
    
    // Memory metrics
    pub voxel_memory_mb: f32,
    pub compressed_memory_mb: f32,
    pub vertex_memory_mb: f32,
    pub total_memory_mb: f32,
    
    // Compression metrics
    pub average_compression_ratio: f32,
    pub unique_voxels_per_chunk: MovingAverage,
    pub palette_efficiency: f32,
    
    // GPU metrics
    pub gpu_memory_mb: f32,
    pub compute_utilization: f32,
    pub bandwidth_gbps: f32,
    
    // Custom timers
    pub custom_timers: HashMap<String, MovingAverage>,
}

pub struct MovingAverage {
    samples: Vec<f32>,
    max_samples: usize,
    sum: f32,
}

impl MovingAverage {
    pub fn new(max_samples: usize) -> Self {
        Self {
            samples: Vec::with_capacity(max_samples),
            max_samples,
            sum: 0.0,
        }
    }
    
    pub fn add_sample(&mut self, value: f32) {
        if self.samples.len() >= self.max_samples {
            self.sum -= self.samples.remove(0);
        }
        self.samples.push(value);
        self.sum += value;
    }
    
    pub fn average(&self) -> f32 {
        if self.samples.is_empty() {
            0.0
        } else {
            self.sum / self.samples.len() as f32
        }
    }
    
    pub fn min(&self) -> f32 {
        self.samples.iter().cloned().fold(f32::INFINITY, f32::min)
    }
    
    pub fn max(&self) -> f32 {
        self.samples.iter().cloned().fold(f32::NEG_INFINITY, f32::max)
    }
}

impl Default for MovingAverage {
    fn default() -> Self {
        Self::new(60) // 60 samples = 1 second at 60 FPS
    }
}

impl VoxelPerformanceProfiler {
    pub fn new() -> Self {
        Self {
            metrics: Arc::new(Mutex::new(PerformanceMetrics::default())),
            frame_start: Instant::now(),
        }
    }
    
    pub fn begin_frame(&mut self) {
        self.frame_start = Instant::now();
    }
    
    pub fn end_frame(&mut self) {
        let frame_time = self.frame_start.elapsed().as_secs_f32() * 1000.0; // ms
        let mut metrics = self.metrics.lock().unwrap();
        metrics.frame_time.add_sample(frame_time);
        metrics.fps = 1000.0 / metrics.frame_time.average();
    }
    
    pub fn time_scope<F, R>(&self, name: &str, f: F) -> R
    where
        F: FnOnce() -> R,
    {
        let start = Instant::now();
        let result = f();
        let elapsed = start.elapsed().as_secs_f32() * 1000.0;
        
        let mut metrics = self.metrics.lock().unwrap();
        metrics.custom_timers
            .entry(name.to_string())
            .or_insert_with(MovingAverage::default)
            .add_sample(elapsed);
        
        result
    }
    
    pub fn record_sdf_evaluation(&self, time_ms: f32) {
        self.metrics.lock().unwrap().sdf_evaluation_time.add_sample(time_ms);
    }
    
    pub fn record_brush_evaluation(&self, time_ms: f32) {
        self.metrics.lock().unwrap().brush_evaluation_time.add_sample(time_ms);
    }
    
    pub fn record_compression(&self, time_ms: f32, ratio: f32, unique_voxels: u32) {
        let mut metrics = self.metrics.lock().unwrap();
        metrics.compression_time.add_sample(time_ms);
        metrics.average_compression_ratio = ratio;
        metrics.unique_voxels_per_chunk.add_sample(unique_voxels as f32);
    }
    
    pub fn record_physics_generation(&self, time_ms: f32) {
        self.metrics.lock().unwrap().physics_generation_time.add_sample(time_ms);
    }
    
    pub fn record_culling(&self, time_ms: f32) {
        self.metrics.lock().unwrap().culling_time.add_sample(time_ms);
    }
    
    pub fn record_batch_building(&self, time_ms: f32) {
        self.metrics.lock().unwrap().batch_building_time.add_sample(time_ms);
    }
    
    pub fn record_draw(&self, time_ms: f32) {
        self.metrics.lock().unwrap().draw_time.add_sample(time_ms);
    }
    
    pub fn update_memory_usage(&self, voxel_mb: f32, compressed_mb: f32, vertex_mb: f32) {
        let mut metrics = self.metrics.lock().unwrap();
        metrics.voxel_memory_mb = voxel_mb;
        metrics.compressed_memory_mb = compressed_mb;
        metrics.vertex_memory_mb = vertex_mb;
        metrics.total_memory_mb = voxel_mb + compressed_mb + vertex_mb;
    }
    
    pub fn update_gpu_metrics(&self, memory_mb: f32, utilization: f32, bandwidth_gbps: f32) {
        let mut metrics = self.metrics.lock().unwrap();
        metrics.gpu_memory_mb = memory_mb;
        metrics.compute_utilization = utilization;
        metrics.bandwidth_gbps = bandwidth_gbps;
    }
    
    pub fn get_report(&self) -> PerformanceReport {
        let metrics = self.metrics.lock().unwrap();
        
        PerformanceReport {
            fps: metrics.fps,
            frame_time: FrameTimeReport {
                average: metrics.frame_time.average(),
                min: metrics.frame_time.min(),
                max: metrics.frame_time.max(),
            },
            generation: GenerationReport {
                sdf_eval_ms: metrics.sdf_evaluation_time.average(),
                brush_eval_ms: metrics.brush_evaluation_time.average(),
                compression_ms: metrics.compression_time.average(),
                physics_gen_ms: metrics.physics_generation_time.average(),
            },
            rendering: RenderingReport {
                culling_ms: metrics.culling_time.average(),
                batch_building_ms: metrics.batch_building_time.average(),
                draw_ms: metrics.draw_time.average(),
                vertex_pool_updates: metrics.vertex_pool_updates,
            },
            memory: MemoryReport {
                voxel_mb: metrics.voxel_memory_mb,
                compressed_mb: metrics.compressed_memory_mb,
                vertex_mb: metrics.vertex_memory_mb,
                total_mb: metrics.total_memory_mb,
                gpu_mb: metrics.gpu_memory_mb,
            },
            compression: CompressionReport {
                average_ratio: metrics.average_compression_ratio,
                unique_voxels_per_chunk: metrics.unique_voxels_per_chunk.average(),
                palette_efficiency: metrics.palette_efficiency,
            },
            gpu: GpuReport {
                compute_utilization: metrics.compute_utilization,
                bandwidth_gbps: metrics.bandwidth_gbps,
            },
            custom_timers: metrics.custom_timers.iter()
                .map(|(name, avg)| (name.clone(), avg.average()))
                .collect(),
        }
    }
}

// Performance report structures
pub struct PerformanceReport {
    pub fps: f32,
    pub frame_time: FrameTimeReport,
    pub generation: GenerationReport,
    pub rendering: RenderingReport,
    pub memory: MemoryReport,
    pub compression: CompressionReport,
    pub gpu: GpuReport,
    pub custom_timers: Vec<(String, f32)>,
}

pub struct FrameTimeReport {
    pub average: f32,
    pub min: f32,
    pub max: f32,
}

pub struct GenerationReport {
    pub sdf_eval_ms: f32,
    pub brush_eval_ms: f32,
    pub compression_ms: f32,
    pub physics_gen_ms: f32,
}

pub struct RenderingReport {
    pub culling_ms: f32,
    pub batch_building_ms: f32,
    pub draw_ms: f32,
    pub vertex_pool_updates: u32,
}

pub struct MemoryReport {
    pub voxel_mb: f32,
    pub compressed_mb: f32,
    pub vertex_mb: f32,
    pub total_mb: f32,
    pub gpu_mb: f32,
}

pub struct CompressionReport {
    pub average_ratio: f32,
    pub unique_voxels_per_chunk: f32,
    pub palette_efficiency: f32,
}

pub struct GpuReport {
    pub compute_utilization: f32,
    pub bandwidth_gbps: f32,
}

impl PerformanceReport {
    pub fn print_summary(&self) {
        println!("\n=== Voxel Engine Performance Report ===");
        println!("FPS: {:.1} ({:.2}ms avg, {:.2}ms min, {:.2}ms max)",
            self.fps, self.frame_time.average, self.frame_time.min, self.frame_time.max);
        
        println!("\nGeneration Timings:");
        println!("  SDF Evaluation:    {:.2}ms", self.generation.sdf_eval_ms);
        println!("  Brush Evaluation:  {:.2}ms", self.generation.brush_eval_ms);
        println!("  Compression:       {:.2}ms", self.generation.compression_ms);
        println!("  Physics Gen:       {:.2}ms", self.generation.physics_gen_ms);
        
        println!("\nRendering Timings:");
        println!("  Culling:           {:.2}ms", self.rendering.culling_ms);
        println!("  Batch Building:    {:.2}ms", self.rendering.batch_building_ms);
        println!("  Draw:              {:.2}ms", self.rendering.draw_ms);
        println!("  Vertex Updates:    {}", self.rendering.vertex_pool_updates);
        
        println!("\nMemory Usage:");
        println!("  Voxel Data:        {:.1}MB", self.memory.voxel_mb);
        println!("  Compressed:        {:.1}MB", self.memory.compressed_mb);
        println!("  Vertex Data:       {:.1}MB", self.memory.vertex_mb);
        println!("  GPU Memory:        {:.1}MB", self.memory.gpu_mb);
        println!("  Total:             {:.1}MB", self.memory.total_mb);
        
        println!("\nCompression:");
        println!("  Ratio:             {:.2}x", self.compression.average_ratio);
        println!("  Unique Voxels:     {:.0}", self.compression.unique_voxels_per_chunk);
        println!("  Palette Eff:       {:.1}%", self.compression.palette_efficiency * 100.0);
        
        println!("\nGPU Metrics:");
        println!("  Compute Usage:     {:.1}%", self.gpu.compute_utilization * 100.0);
        println!("  Bandwidth:         {:.1}GB/s", self.gpu.bandwidth_gbps);
        
        if !self.custom_timers.is_empty() {
            println!("\nCustom Timers:");
            for (name, time) in &self.custom_timers {
                println!("  {:20} {:.2}ms", name, time);
            }
        }
        
        println!("=====================================\n");
    }
}

// Scoped timer for RAII-based timing
pub struct ScopedTimer<'a> {
    profiler: &'a VoxelPerformanceProfiler,
    name: String,
    start: Instant,
}

impl<'a> ScopedTimer<'a> {
    pub fn new(profiler: &'a VoxelPerformanceProfiler, name: &str) -> Self {
        Self {
            profiler,
            name: name.to_string(),
            start: Instant::now(),
        }
    }
}

impl<'a> Drop for ScopedTimer<'a> {
    fn drop(&mut self) {
        let elapsed = self.start.elapsed().as_secs_f32() * 1000.0;
        let mut metrics = self.profiler.metrics.lock().unwrap();
        metrics.custom_timers
            .entry(self.name.clone())
            .or_insert_with(MovingAverage::default)
            .add_sample(elapsed);
    }
}

// Macro for easy timing
#[macro_export]
macro_rules! profile_scope {
    ($profiler:expr, $name:expr) => {
        let _timer = $crate::universe::performance::ScopedTimer::new($profiler, $name);
    };
}