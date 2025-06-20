#![feature(random, let_chains)]
use std::{alloc::alloc, collections::HashMap, ops::Mul, random::random, thread, time::Duration};

use glam::Vec2;
use major::{Actor, Binding};

pub struct Entity {
    actor: *mut major::Actor,
    position: glam::Vec2,
}

pub fn main() {
    let engine = major::engine(major::Type::Console);
    let mut deez = 0.0;
    let mut entities = vec![];
    entities.push({
        let mut player = engine.actor_create(Actor::Player);
        Entity {
            actor: player,
            position: Vec2::new(0.0, 0.0),
        }
    });
    for i in 0..10 {
        fn rand() -> f32 {
            (random::<u64>() as f64 / u64::MAX as f64) as f32
        }
        entities.push(Entity {
            actor: engine.actor_create(Actor::Zombie),
            position: Vec2::new(rand() * 10. - 5., rand() * 10. - 5.),
        });
    }
    loop {
        engine.frame_begin();

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
            engine.actor_move(player.actor, player.position.x, player.position.y);
            engine.actor_draw(player.actor);
            if let x = unsafe { engine.input_binding_data(Binding::MoveVertical).scalar }
                && x != 0.0
            {
                player.position.y -= x;
            }
            if let x = unsafe { engine.input_binding_data(Binding::MoveHorizontal).scalar }
                && x != 0.0
            {
                player.position.x += x;
                if let cursor = unsafe { engine.input_binding_data(Binding::Cursor).pos } {
                    let frustum = engine.cell_frustum();
                    let player_pos = (player.position.x as i128);
                    let size = [frustum.right - frustum.left, frustum.bottom - frustum.top];
                    let range = [cursor.0 * size[0] as f32, cursor.1 * size[1] as f32];
                    engine.debug_value(Box::new(format!("{cursor:?}")) as Box<dyn core::fmt::Display>);
                    entities.push(Entity {
                        actor: engine.actor_create(Actor::Turret),
                        position: Vec2::from_array(range),
                    })
                }
            }
            if let x = unsafe { engine.input_binding_data(Binding::Escape).activate }
                && x
            {
                break;
            }
            // Update player position
        }

        // Draw other entities (zombies)
        for entity in entities.iter().skip(1) {
            engine.actor_move(entity.actor, entity.position.x, entity.position.y);
            engine.actor_draw(entity.actor);
        }

        engine.frame_end();
        deez += 0.2;

        // Use a shorter sleep time for more responsive input
        thread::sleep(Duration::from_millis(10));
    }
}
