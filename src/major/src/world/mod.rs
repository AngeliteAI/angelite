use std::collections::HashMap;

use crate::{engine, gfx, math};

pub struct EntityId(u64);

impl EntityId {
    pub unsafe fn from_actor(actor: *mut engine::Actor) -> Self {
        Self(actor as u64)
    }
    pub unsafe fn to_actor(&self) -> *mut engine::Actor {
        self.0 as *mut engine::Actor
    }
}

pub struct ObserverId(u64);

impl ObserverId {
    pub unsafe fn from_camera(camera: *mut gfx::Camera) -> Self {
        Self(camera as u64)
    }
    pub unsafe fn to_camera(&self) -> *mut gfx::Camera {
        self.0 as *mut gfx::Camera
    }
}

pub struct Entity {
    actor: EntityId,
}

#[derive(Default)]
pub struct World {
    origin: crate::math::Vec3<i64>,
    entities: HashMap<EntityId, Entity>,
    cameras: Vec<(ObserverId, EntityId)>,
}

impl World {}
