use godot::prelude::*;
use wargrid_core::movement::{Movement, Pass};

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WargridMovement {
    core: Movement,
    error: GString,
}

#[godot_api]
impl WargridMovement {
    #[func]
    fn run(&mut self, inputs: VarArray) -> VarArray {
        let result = crate::run_generic(&mut self.core, &inputs);
        crate::answer(&mut self.error, result)
    }

    #[func]
    fn run_pass(&mut self, inputs: VarArray) -> VarArray {
        let result = crate::run_generic(&mut Pass, &inputs);
        crate::answer(&mut self.error, result)
    }

    #[func]
    fn last_error(&self) -> GString {
        self.error.clone()
    }
}
