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
    let mut deez = 0.0;
    let mut entities = vec![];
    entities.push({
        let mut player = engine.actor_create(Actor::Player);
        Entity {
            actor: player,
            position: Vec2::new(0.0, 0.0),
            ..Default::default()
        }
    });
    entities.push(Entity {
        actor: engine.actor_create(Actor::Ghost),
        action: None,
        action_cooldown: Duration::from_millis(1000),
        action_last: Instant::now(),
        position: Vec2::new(0.0, 0.0),
    });

    for i in 0..10 {
        fn rand() -> f32 {
            (random::<u64>() as f64 / u64::MAX as f64) as f32
        }
        entities.push(Entity {
            actor: engine.actor_create(Actor::Zombie),
            position: Vec2::new(rand() * 10. - 5., rand() * 10. - 5.),
            ..Default::default()
        });
    }
    let batch = gfx.batch_create();

    for entity in &entities {
        let mesh = gfx.mesh_create();
        //triangle
        //triangle vertices
        let verts = [-1.0, -1.0, 1.0, -1.0, 0.0, 1.0];
        gfx.mesh_update_vertices(mesh, &verts);
        gfx.mesh_update_indices(mesh, &[Index::U32(0), Index::U32(1), Index::U32(2)]);
        gfx.batch_add_mesh(batch, mesh);
    }
    loop {
        gfx.frame_begin();
        gfx.batch_queue_draw(batch);
        gfx.frame_end();

        // Handle player movement with WASD keys
        if !entities.is_empty() {
            let player = &mut entities[0];
            engine.set_focus_point(
                player.position.x.rem_euclid(32.),
                player.position.y.rem_euclid(32.),
            );
            engine.set_origin(
                (player.position.x as i128).div_euclid(32).mul(32),
                (player.position.y as i128).div_euclid(32).mul(32),
            );

            // Check movement input_bindings and update player position
            if let x = unsafe { engine.input_binding_data(Binding::MoveVertical).scalar }
                && x != 0.0
            {
                player.position.y -= x;
            }
            if let x = unsafe { engine.input_binding_data(Binding::MoveHorizontal).scalar }
                && x != 0.0
            {
                player.position.x += x;
            }
            engine.actor_move(player.actor, player.position.x, player.position.y);
            let mut add_later = vec![];

            if let x = unsafe { engine.input_binding_data(Binding::Escape).activate }
                && x
            {
                break;
            }
            if let cursor = unsafe { engine.input_binding_data(Binding::Cursor).pos } {
                let frustum = engine.cell_frustum();
                let player_pos = (player.position.x as i128);
                let size = [frustum.right - frustum.left, frustum.bottom - frustum.top];
                engine.debug_value(Box::new(format!("{frustum:?}")));
                let range = [
                    cursor.0 * size[0] as f32 - size[0] as f32 / 2.0,
                    cursor.1 * size[1] as f32 - size[1] as f32 / 2.0,
                ];
                engine.debug_value(Box::new(format!("){cursor:?}")));

                *get_ghost(&mut entities) = Entity {
                    actor: engine.actor_create(Actor::Ghost),
                    position: Vec2::from_array(range),
                    action: Some(Action {
                        ty: Type::Place(Box::new(Entity {
                            actor: engine.actor_create(Actor::Turret.into()),
                            position: Vec2::from_array(range),
                            action: None,
                            action_cooldown: Duration::from_secs(1),
                            action_last: Instant::now(),
                        })),
                    }),
                    action_cooldown: Duration::from_secs(1),
                    action_last: Instant::now(),
                }
            }
            if let x = unsafe { engine.input_binding_data(Binding::Cursor).activate }
                && x
            {
                let ghost_clone = get_ghost(&mut entities).clone();
                match ghost_clone.action.unwrap().ty {
                    Type::Place(place) => {
                        add_later.push(Entity {
                            actor: engine.actor_create(unsafe { place.actor.read() }),
                            ..*place.clone()
                        });
                    }
                    _ => {}
                }
            }
            entities.extend(add_later);
            // Update player position
        }

        for entity in entities.iter() {
            engine.actor_move(entity.actor, entity.position.x, entity.position.y);
        }

        let mut quadtree = QuadTree::<EntityAccel>::new(
            quadtree::shapes::Rect::new(P2::new(-2048., -2048.), P2::new(2048., 2048.)),
            100,
        );

        let mut accels = vec![];
        for (index, entity) in entities.iter().enumerate() {
            accels.push(EntityAccel {
                index,
                pos: entity.position,
            });
        }

        quadtree.insert_many(&accels);

        #[derive(Debug)]
        pub enum Change {
            Position { index: usize, pos: Vec2 },
        }

        let mut changes = vec![];

        for (index, entity) in entities.iter().enumerate() {
            match unsafe { entity.actor.read() } {
                Actor::Zombie => {
                    let players = quadtree.query_filter(
                        &Circle::new(
                            P2::new(entity.position.x as f64, entity.position.y as f64),
                            100.,
                        ),
                        |accel| {
                            matches!(
                                unsafe { entities[accel.index].actor.as_ref().unwrap() },
                                &Actor::Player
                            )
                        },
                    );

                    if players.len() > 0 {
                        changes.push(Change::Position {
                            index,
                            pos: 0.03 * (players[0].pos - entity.position),
                        });
                    }
                }
                _ => {}
            }
        }
        for change in changes {
            match change {
                Change::Position { index, pos } => {
                    entities[index].position += pos;
                }
            }
        }
        // Draw other entities (zombies)

        deez += 0.2;

        // Use a shorter sleep time for more responsive input
        thread::sleep(Duration::from_millis(10));
    }
}

fn get_ghost(entities: &mut [Entity]) -> &mut Entity {
    entities
        .iter_mut()
        .find(|entity| {
            matches!(
                dbg!(unsafe { entity.actor.as_ref().unwrap() }),
                &Actor::Ghost
            )
        })
        .unwrap()
}
