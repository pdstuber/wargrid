use godot::prelude::*;
use wargrid_core::horde::Horde;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WargridHorde {
    core: Horde,
    error: GString,
}

#[godot_api]
impl WargridHorde {
    #[func]
    fn run(&mut self, inputs: VarArray) -> VarArray {
        let result = crate::run_generic(&mut self.core, &inputs);
        crate::answer(&mut self.error, result)
    }

    #[func]
    fn run_pass(&mut self, _inputs: VarArray) -> VarArray {
        crate::answer(&mut self.error, Err("horde: pass not implemented".into()))
    }

    #[func]
    fn last_error(&self) -> GString {
        self.error.clone()
    }
}
