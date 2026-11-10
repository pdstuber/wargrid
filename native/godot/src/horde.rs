use godot::prelude::*;
use wargrid_core::horde::Horde;
use wargrid_core::Buffer;

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

    // Same conversion as `run`, then outputs of the real size without the rule work.
    #[func]
    fn run_pass(&mut self, inputs: VarArray) -> VarArray {
        let result = pass(&self.core, &inputs);
        crate::answer(&mut self.error, result)
    }

    #[func]
    fn last_error(&self) -> GString {
        self.error.clone()
    }
}

fn pass(core: &Horde, inputs: &VarArray) -> Result<VarArray, String> {
    let buffers = inputs.iter_shared().enumerate().map(|(i, v)| crate::to_buffer(&v, i)).collect::<Result<Vec<Buffer>, _>>()?;
    let mut out = VarArray::new();
    for buffer in core.pass(&buffers)? {
        out.push(&crate::to_variant(buffer));
    }
    Ok(out)
}
