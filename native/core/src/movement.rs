//! Movement slice (`simulation.gd` `_advance` with `locomotion.gd`). Stub until T6; see docs/reference/native-sim-spike-slice-move.md.

use crate::{Buffer, Slice};

#[derive(Default)]
pub struct Movement;

impl Slice for Movement {
    fn step(&mut self, _inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        Err("move: not implemented".into())
    }
}
