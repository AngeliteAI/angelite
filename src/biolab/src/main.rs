#![feature(random, let_chains)]
use std::{
    alloc::alloc,
    collections::HashMap,
    ops::Mul,
    ptr,
    random::random,
    thread,
    time::{Duration, Instant},
};

use glam::Vec2;
use major::{
    engine::{Actor, Binding},
    gfx::Index,
    math,
};
use quadtree::{
    P2, Point, QuadTree,
    shapes::{self, Circle},
};

#[derive(Debug, Clone)]
pub struct Action {
    pub ty: Type,
}

#[derive(Clone, Debug)]
pub struct EntityAccel {
    pub index: usize,
    pub pos: Vec2,
}

impl Point for EntityAccel {
    fn point(&self) -> quadtree::P2 {
        quadtree::P2::new(self.pos.x as f64, self.pos.y as f64)
    }
}
#[derive(Debug, Clone)]
pub enum Type {
    Place(Box<Entity>),
    Set(major::tile::Type),
}

impl Default for Entity {
    fn default() -> Self {
        Entity {
            actor: ptr::null_mut(),
            action: None,
            action_cooldown: Duration::from_secs(0),
            action_last: Instant::now(),
            position: Vec2::new(0.0, 0.0),
        }
    }
}
#[derive(Debug, Clone)]
pub struct Entity {
    actor: *mut major::engine::Actor,
    action: Option<Action>,
    action_cooldown: Duration,
    action_last: Instant,
    position: glam::Vec2,
}

pub fn main() {
    let engine = major::current_engine();
    let surface = engine.surface_create();
    let gfx = engine.gfx_create(surface);

    let mut mesh = gfx.mesh_create();
    //triangle vertices
    gfx.mesh_update_vertices(
        mesh,
        &[
            math::Vector([0.0, 0.0, 0.0]),
            math::Vector([0.0, 1.0, 0.0]),
            math::Vector([1.0, 0.0, 0.0]),
        ],
    );
    gfx.mesh_update_indices(mesh, &[Index::U32(0), Index::U32(1), Index::U32(2)]);

    let mut batch = gfx.batch_create();
    gfx.batch_add_mesh(batch, mesh);

    loop {
        gfx.frame_begin();
        gfx.batch_queue_draw(batch);
        gfx.frame_commit_draw();
        gfx.frame_end();
    }
}
