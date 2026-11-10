//! Horde step slice (`horde.gd` `Horde.step`). Stub until T5; see docs/reference/native-sim-spike-slice-horde.md.

use crate::{Buffer, Slice};

#[derive(Default)]
pub struct Horde;

impl Slice for Horde {
    fn step(&mut self, _inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        Err("horde: not implemented".into())
    }
}
