use crate::ffi::surface::Surface;
use crate::ffi::math::{Vec3, Quat, Mat4};

#[repr(C)]
pub struct Camera {
    pub position: Vec3,
    pub rotation: Quat,
    pub projection: Mat4,
}

#[repr(C)]
pub struct RenderSettings {
    pub view_distance: u32,
    pub enable_ao: bool,
}

#[repr(C)]
pub struct Volume {
    pub id: u64,
}

#[repr(C)]
pub struct Renderer {
    pub id: u64,
}

extern "C" {
    // Initialization
    pub fn init(surface: *mut Surface) -> *const Renderer;
    pub fn shutdown(renderer: *const Renderer);
    pub fn supportsMultiple() -> bool;

    // Camera control
    pub fn setCamera(renderer: *mut Renderer, camera: *const Camera);
    pub fn setSettings(renderer: *mut Renderer, settings: *const RenderSettings);

    // Volume management
    pub fn addVolume(renderer: *mut Renderer, volume: *const Volume, position: [i32; 3]);
    pub fn removeVolume(renderer: *mut Renderer, position: [i32; 3]);
    pub fn clearVolumes(renderer: *mut Renderer);

    // Rendering
    pub fn render(renderer: *mut Renderer);
}

// Safe wrappers
impl Renderer {
    pub fn set_camera(&mut self, camera: &Camera) {
        unsafe {
            setCamera(self, camera);
        }
    }

    pub fn add_volume(&mut self, volume: &Volume, position: [i32; 3]) {
        unsafe {
            addVolume(self, volume, position);
        }
    }

    pub fn render(&mut self) {
        unsafe {
            render(self);
        }
    }
}
