use crate::ffi::math::{Vec3, Quat};

#[repr(C)]
pub struct Volume {
    pub id: u64,
}

#[repr(C)]
pub struct Brush {
    pub id: u64,
}

#[repr(C)]
pub struct Transform {
    pub position: Vec3,
    pub rotation: Quat,
    pub scale: Vec3,
}

// FFI bindings to the Zig voxel engine
#[link(name = "gfx", kind = "static")]
extern "C" {
    // Volume creation and management
    pub fn createEmptyVolume(size_x: u32, size_y: u32, size_z: u32) -> *mut Volume;
    pub fn createVolumeFromSDF(sdf: *mut core::ffi::c_void, brush: *const Brush, position: [i32; 3], size: [u32; 3]) -> *mut Volume;
    pub fn cloneVolume(vol: *const Volume) -> *mut Volume;
    pub fn releaseVolume(vol: *mut Volume);

    // Volume modification operations
    pub fn unionVolume(vol: *const Volume, transform: *const Transform, brush: *const Brush, position: [i32; 3]) -> *mut Volume;
    pub fn subtractVolume(vol: *const Volume, transform: *const Transform, position: [i32; 3]) -> *mut Volume;
    pub fn replaceVolume(vol: *const Volume, transform: *const Transform, brush: *const Brush, position: [i32; 3]) -> *mut Volume;
    pub fn paintVolumeRegion(vol: *const Volume, transform: *const Transform, brush: *const Brush, position: [i32; 3]) -> *mut Volume;

    // Volume compositing
    pub fn mergeVolumes(volumes: *const *const Volume, count: usize) -> *mut Volume;
    pub fn extractRegion(vol: *const Volume, min_x: i32, min_y: i32, min_z: i32, max_x: i32, max_y: i32, max_z: i32) -> *mut Volume;

    // Structure management
    pub fn registerStructure(vol: *const Volume, name: *const core::ffi::c_char, name_len: usize) -> u32;
    pub fn getStructure(id: u32) -> *mut Volume;
    pub fn placeStructure(world: *const Volume, structure: *const Volume, position: [i32; 3], rotation: u8) -> *mut Volume;

    // Serialization
    pub fn saveVolume(vol: *const Volume, path: *const core::ffi::c_char, path_len: usize) -> bool;
    pub fn loadVolume(path: *const core::ffi::c_char, path_len: usize) -> *mut Volume;

    // Direct access
    pub fn getVoxel(vol: *const Volume, positions: *const Vec3, out_blocks: *mut u16, count: usize);
    pub fn setVoxel(vol: *const Volume, positions: *const Vec3, blocks: *const u16, count: usize);
    pub fn getVolumeSize(vol: *const Volume) -> [u32; 3];
    pub fn getVolumePosition(vol: *const Volume) -> [i32; 3];

    // Volume transformations
    pub fn moveVolume(vol: *const Volume, x: i32, y: i32, z: i32) -> *mut Volume;
    pub fn rotateVolume(vol: *const Volume, rotation: u8) -> *mut Volume;
    pub fn mirrorVolume(vol: *const Volume, axis: u8) -> *mut Volume;
}

// Safe wrappers
impl Volume {
    /// Create a new empty voxel volume of the specified size
    pub fn new_empty(size_x: u32, size_y: u32, size_z: u32) -> Self {
        unsafe {
            let ptr = createEmptyVolume(size_x, size_y, size_z);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Clone this volume
    pub fn clone(&self) -> Self {
        unsafe {
            let ptr = cloneVolume(self);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Get the size of this volume
    pub fn size(&self) -> [u32; 3] {
        unsafe { getVolumeSize(self) }
    }

    /// Get the position of this volume
    pub fn position(&self) -> [i32; 3] {
        unsafe { getVolumePosition(self) }
    }

    /// Move this volume by the specified offset
    pub fn move_by(&self, x: i32, y: i32, z: i32) -> Self {
        unsafe {
            let ptr = moveVolume(self, x, y, z);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Rotate this volume
    pub fn rotate(&self, rotation: u8) -> Self {
        unsafe {
            let ptr = rotateVolume(self, rotation);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Mirror this volume along an axis
    pub fn mirror(&self, axis: u8) -> Self {
        unsafe {
            let ptr = mirrorVolume(self, axis);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Extract a region from this volume
    pub fn extract_region(&self, min_x: i32, min_y: i32, min_z: i32, max_x: i32, max_y: i32, max_z: i32) -> Self {
        unsafe {
            let ptr = extractRegion(self, min_x, min_y, min_z, max_x, max_y, max_z);
            std::mem::transmute_copy(&ptr)
        }
    }

    /// Get voxels at specific positions
    pub fn get_voxels(&self, positions: &[Vec3], out_blocks: &mut [u16]) {
        let count = std::cmp::min(positions.len(), out_blocks.len());
        if count == 0 { return; }
        
        unsafe {
            getVoxel(self, positions.as_ptr(), out_blocks.as_mut_ptr(), count);
        }
    }

    /// Set voxels at specific positions
    pub fn set_voxels(&self, positions: &[Vec3], blocks: &[u16]) {
        let count = std::cmp::min(positions.len(), blocks.len());
        if count == 0 { return; }
        
        unsafe {
            setVoxel(self, positions.as_ptr(), blocks.as_ptr(), count);
        }
    }

    /// Save this volume to a file
    pub fn save(&self, path: &str) -> bool {
        unsafe {
            saveVolume(
                self,
                path.as_ptr() as *const core::ffi::c_char,
                path.len(),
            )
        }
    }
}

// Implement Drop for Volume to automatically release when it goes out of scope
impl Drop for Volume {
    fn drop(&mut self) {
        // We need a mutable pointer to self
        let ptr = self as *mut Volume;
        unsafe {
            releaseVolume(ptr);
        }
    }
}

// Additional utilities
pub fn load_volume(path: &str) -> Option<Volume> {
    unsafe {
        let ptr = loadVolume(
            path.as_ptr() as *const core::ffi::c_char,
            path.len(),
        );
        if ptr.is_null() {
            None
        } else {
            Some(std::mem::transmute_copy(&ptr))
        }
    }
}

pub fn merge_volumes(volumes: &[Volume]) -> Option<Volume> {
    if volumes.is_empty() {
        return None;
    }

    // Convert Vec<Volume> to Vec<*const Volume>
    let ptrs: Vec<*const Volume> = volumes.iter().map(|v| v as *const Volume).collect();

    unsafe {
        let ptr = mergeVolumes(ptrs.as_ptr(), volumes.len());
        if ptr.is_null() {
            None
        } else {
            Some(std::mem::transmute_copy(&ptr))
        }
    }
}