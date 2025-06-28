#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::{Vec3, Mat4f};
    
    #[test]
    fn test_sdf_sphere() {
        use crate::universe::sdf::{Sphere, Sdf};
        
        let sphere = Sphere {
            center: Vec3::new([0.0, 0.0, 0.0]),
            radius: 1.0,
        };
        
        // Test distance at center
        assert_eq!(sphere.distance(Vec3::new([0.0, 0.0, 0.0])), -1.0);
        
        // Test distance on surface
        assert!((sphere.distance(Vec3::new([1.0, 0.0, 0.0]))).abs() < 0.001);
        
        // Test distance outside
        assert_eq!(sphere.distance(Vec3::new([2.0, 0.0, 0.0])), 1.0);
    }
    
    #[test]
    fn test_sdf_union() {
        use crate::universe::sdf::{Sphere, Box3, Sdf, SdfOps};
        
        let sphere = Sphere {
            center: Vec3::new([0.0, 0.0, 0.0]),
            radius: 1.0,
        };
        
        let box_sdf = Box3 {
            center: Vec3::new([2.0, 0.0, 0.0]),
            half_extents: Vec3::new([1.0, 1.0, 1.0]),
        };
        
        let union = sphere.union(box_sdf);
        
        // Test that union contains both shapes
        assert!(union.distance(Vec3::new([0.0, 0.0, 0.0])) < 0.0);
        assert!(union.distance(Vec3::new([2.0, 0.0, 0.0])) < 0.0);
    }
    
    #[test]
    fn test_brush_conditions() {
        use crate::universe::brush::{Condition, EvaluationContext};
        
        let height_condition = Condition::height(0.0, 10.0);
        
        let context = EvaluationContext {
            position: Vec3::new([0.0, 5.0, 0.0]),
            sdf_value: -1.0,
            normal: Vec3::new([0.0, 1.0, 0.0]),
            surface_position: Vec3::new([0.0, 0.0, 0.0]),
            depth_from_surface: 1.0,
        };
        
        // Height condition should pass
        match height_condition {
            Condition::Height { min, max } => {
                assert!(context.position.y() >= min && context.position.y() <= max);
            }
            _ => panic!("Wrong condition type"),
        }
    }
    
    #[test]
    fn test_palette_compression() {
        use crate::universe::Voxel;
        use crate::universe::palette_compression::BitpackedData;
        
        // Test bitpacking
        let mut bitpacked = BitpackedData {
            data: vec![0; 10],
            bits_per_index: 3,
            voxel_count: 20,
        };
        
        // Set and get indices
        for i in 0..8 {
            bitpacked.set_index(i, i as u8);
            assert_eq!(bitpacked.get_index(i), i as u8);
        }
        
        // Test cross-byte boundaries
        bitpacked.set_index(2, 7);
        assert_eq!(bitpacked.get_index(2), 7);
    }
    
    #[test]
    fn test_voxel_workspace() {
        use crate::universe::{VoxelWorkspace, WorldBounds, Voxel};
        
        let bounds = WorldBounds {
            min: Vec3::new([0.0, 0.0, 0.0]),
            max: Vec3::new([64.0, 64.0, 64.0]),
            voxel_size: 1.0,
        };
        
        assert_eq!(bounds.voxel_count(), 64 * 64 * 64);
        assert_eq!(bounds.dimensions(), (64, 64, 64));
        
        // Create workspace
        let voxels = vec![Voxel(1); bounds.voxel_count()];
        let workspace = VoxelWorkspace::from_gpu_buffer(voxels, bounds);
        
        assert_eq!(workspace.dimensions, (64, 64, 64));
        assert_eq!(workspace.metadata.unique_voxels.len(), 1);
    }
    
    #[test]
    fn test_performance_profiler() {
        use crate::universe::performance::{VoxelPerformanceProfiler, MovingAverage};
        
        let mut avg = MovingAverage::new(3);
        avg.add_sample(1.0);
        avg.add_sample(2.0);
        avg.add_sample(3.0);
        assert_eq!(avg.average(), 2.0);
        
        // Test overflow
        avg.add_sample(4.0);
        assert_eq!(avg.average(), 3.0); // (2 + 3 + 4) / 3
        
        // Test profiler
        let mut profiler = VoxelPerformanceProfiler::new();
        profiler.begin_frame();
        
        // Simulate some work
        std::thread::sleep(std::time::Duration::from_millis(1));
        
        profiler.end_frame();
        
        let report = profiler.get_report();
        assert!(report.frame_time.average > 0.0);
    }
    
    #[test]
    fn test_vertex_pool() {
        use crate::universe::vertex_pool_renderer::VertexPool;
        
        let mut pool = VertexPool::new(1000);
        
        // Test allocation
        let offset1 = pool.allocate(1, 100).unwrap();
        assert_eq!(offset1, 0);
        
        let offset2 = pool.allocate(2, 200).unwrap();
        assert_eq!(offset2, 100);
        
        // Test deallocation and reuse
        pool.deallocate(1);
        let offset3 = pool.allocate(3, 50).unwrap();
        assert_eq!(offset3, 0); // Should reuse freed space
    }
}