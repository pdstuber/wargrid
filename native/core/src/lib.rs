//! Wargrid simulation slices without any engine dependency. Contract: docs/reference/native-sim-spike-boundary.md.

pub mod fixture;
#[cfg(feature = "horde")]
pub mod horde;
#[cfg(feature = "movement")]
pub mod movement;

/// One flat column, the in-process counterpart of a Godot packed array.
#[derive(Clone, Debug)]
pub enum Buffer {
    U8(Vec<u8>),
    I32(Vec<i32>),
    I64(Vec<i64>),
    F32(Vec<f32>),
    F64(Vec<f64>),
}

impl Buffer {
    pub fn len(&self) -> usize {
        match self {
            Buffer::U8(v) => v.len(),
            Buffer::I32(v) => v.len(),
            Buffer::I64(v) => v.len(),
            Buffer::F32(v) => v.len(),
            Buffer::F64(v) => v.len(),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn tag(&self) -> u8 {
        match self {
            Buffer::U8(_) => 1,
            Buffer::I32(_) => 2,
            Buffer::I64(_) => 3,
            Buffer::F32(_) => 4,
            Buffer::F64(_) => 5,
        }
    }

    /// Element `i` as raw bits, so `-0.0` differs from `0.0` and NaN payloads are compared exactly.
    fn bits(&self, i: usize) -> u64 {
        match self {
            Buffer::U8(v) => v[i] as u64,
            Buffer::I32(v) => v[i] as u32 as u64,
            Buffer::I64(v) => v[i] as u64,
            Buffer::F32(v) => v[i].to_bits() as u64,
            Buffer::F64(v) => v[i].to_bits(),
        }
    }

    fn show(&self, i: usize) -> String {
        match self {
            Buffer::U8(v) => v[i].to_string(),
            Buffer::I32(v) => v[i].to_string(),
            Buffer::I64(v) => v[i].to_string(),
            Buffer::F32(v) => format!("{:?} (0x{:08x})", v[i], v[i].to_bits()),
            Buffer::F64(v) => format!("{:?} (0x{:016x})", v[i], v[i].to_bits()),
        }
    }
}

/// First bit difference between two buffer lists, as text naming buffer and row; `None` when equal.
pub fn first_difference(expected: &[Buffer], got: &[Buffer]) -> Option<String> {
    if expected.len() != got.len() {
        return Some(format!("buffer count expected={} got={}", expected.len(), got.len()));
    }
    for (b, (e, g)) in expected.iter().zip(got).enumerate() {
        if e.tag() != g.tag() || e.len() != g.len() {
            return Some(format!(
                "buffer={b} shape expected=tag{}x{} got=tag{}x{}",
                e.tag(),
                e.len(),
                g.tag(),
                g.len()
            ));
        }
        if let Some(i) = (0..e.len()).find(|&i| e.bits(i) != g.bits(i)) {
            return Some(format!("buffer={b} row={i} expected={} got={}", e.show(i), g.show(i)));
        }
    }
    None
}

/// A slice kernel driven through generic buffers (the standalone runner's path).
/// Errors are returned, never panicked, so nothing unwinds into a caller.
pub trait Slice {
    fn step(&mut self, inputs: &[Buffer]) -> Result<Vec<Buffer>, String>;
}

/// Slice names as the bridge and fixtures use them: `horde`, `move`.
pub fn new_slice(name: &str) -> Result<Box<dyn Slice>, String> {
    match name {
        #[cfg(feature = "horde")]
        "horde" => Ok(Box::<horde::Horde>::default()),
        #[cfg(feature = "movement")]
        "move" => Ok(Box::<movement::Movement>::default()),
        _ => Err(format!("unknown slice: {name}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn signed_zero_differs() {
        let a = [Buffer::F64(vec![0.0])];
        let b = [Buffer::F64(vec![-0.0])];
        assert!(first_difference(&a, &b).unwrap().contains("row=0"));
        assert!(first_difference(&a, &a).is_none());
    }

    #[test]
    fn shape_and_count_differ() {
        let a = [Buffer::I32(vec![1, 2])];
        assert!(first_difference(&a, &[Buffer::I64(vec![1, 2])]).unwrap().contains("shape"));
        assert!(first_difference(&a, &[]).unwrap().contains("count"));
    }

    #[test]
    fn stubs_report_not_implemented() {
        for name in ["move"] {
            let err = new_slice(name).unwrap().step(&[]).unwrap_err();
            assert!(err.contains("not implemented"), "{name}: {err}");
        }
        assert!(new_slice("nope").is_err());
    }
}
