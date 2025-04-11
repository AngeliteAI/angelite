use crate::ffi::gfx::surface::Surface;

#[repr(C)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[repr(C)]
pub struct Quat {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub w: f32,
}

#[repr(C)]
pub struct Mat4 {
    pub data: [f32; 16],
}

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

unsafe extern "C" {
    // Initialization
    pub fn init(surface: *mut Surface) -> *mut Renderer;
    pub fn shutdown(renderer: *mut Renderer);
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
