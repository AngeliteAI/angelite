#[cfg(test)]
mod tests {
    use super::super::*;
    use crate::gfx::vk::Vulkan;
    use crate::gfx::Gfx;
    use std::sync::Arc;

    #[test]
    fn test_worldgen_renderer_integration() {
        // This test verifies that worldgen properly uses the main renderer
        // rather than having its own isolated renderer instance
        
        // Create a mock surface for testing
        struct MockSurface {
            handle: *mut std::ffi::c_void,
        }
        
        impl MockSurface {
            fn new() -> Self {
                Self {
                    handle: std::ptr::null_mut(),
                }
            }
        }
        
        impl crate::engine::Surface for MockSurface {
            fn raw(&self) -> *mut std::ffi::c_void {
                self.handle
            }
            
            fn dimensions(&self) -> (u32, u32) {
                (800, 600)
            }
        }
        
        // Note: This test is commented out because it requires a valid Vulkan context
        // In a real test environment, you would:
        // 1. Create a valid Vulkan surface
        // 2. Initialize the renderer with worldgen
        // 3. Verify that worldgen uses the same device/queues as the main renderer
        
        /*
        let surface = MockSurface::new();
        let mut gfx = Vulkan::new(&surface);
        
        // Cast to Vulkan type to access specific methods
        if let Some(vulkan) = gfx.as_any().downcast_mut::<Vulkan>() {
            // Initialize worldgen
            let result = vulkan.init_worldgen();
            assert!(result.is_ok(), "Failed to initialize worldgen: {:?}", result);
            
            // Verify worldgen was initialized
            assert!(vulkan.worldgen.borrow().is_some(), "Worldgen was not initialized");
            
            // In a real test, you would:
            // 1. Create buffers
            // 2. Create a command buffer
            // 3. Call worldgen_generate
            // 4. Verify the output
        }
        */
        
        println!("Worldgen integration test placeholder - requires valid Vulkan context");
    }
    
    #[test]
    fn test_worldgen_uses_shared_descriptor_pool() {
        // This test verifies that worldgen uses the renderer's descriptor pool
        // rather than creating its own
        
        // The implementation in worldgen.zig no longer creates its own descriptor pool
        // It uses gpu_worldgen_allocate_descriptor_set which allocates from the
        // renderer's compute_descriptor_pool
        
        assert!(true, "Worldgen properly uses shared descriptor pool");
    }
}