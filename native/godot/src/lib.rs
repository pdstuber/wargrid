//! Godot adapter: packed arrays in and out, instance lifetime. Rules live in wargrid_core.

use godot::prelude::*;
use wargrid_core::{Buffer, Slice};

#[cfg(feature = "horde")]
mod horde;
#[cfg(feature = "movement")]
mod movement;
#[cfg(feature = "probe")]
mod probe;

struct WargridNative;

#[gdextension]
unsafe impl ExtensionLibrary for WargridNative {}

fn to_buffer(value: &Variant, index: usize) -> Result<Buffer, String> {
    let bad = |_| format!("input {index}: not a supported packed array");
    Ok(match value.get_type() {
        VariantType::PACKED_BYTE_ARRAY => Buffer::U8(value.try_to::<PackedByteArray>().map_err(bad)?.to_vec()),
        VariantType::PACKED_INT32_ARRAY => Buffer::I32(value.try_to::<PackedInt32Array>().map_err(bad)?.to_vec()),
        VariantType::PACKED_INT64_ARRAY => Buffer::I64(value.try_to::<PackedInt64Array>().map_err(bad)?.to_vec()),
        VariantType::PACKED_FLOAT32_ARRAY => Buffer::F32(value.try_to::<PackedFloat32Array>().map_err(bad)?.to_vec()),
        VariantType::PACKED_FLOAT64_ARRAY => Buffer::F64(value.try_to::<PackedFloat64Array>().map_err(bad)?.to_vec()),
        other => return Err(format!("input {index}: {other:?} is not a packed array")),
    })
}

fn to_variant(buffer: Buffer) -> Variant {
    match buffer {
        Buffer::U8(v) => PackedByteArray::from(v).to_variant(),
        Buffer::I32(v) => PackedInt32Array::from(v).to_variant(),
        Buffer::I64(v) => PackedInt64Array::from(v).to_variant(),
        Buffer::F32(v) => PackedFloat32Array::from(v).to_variant(),
        Buffer::F64(v) => PackedFloat64Array::from(v).to_variant(),
    }
}

/// Generic copying path: Godot buffers to core buffers, one step, back. An empty result means an error.
fn run_generic(slice: &mut dyn Slice, inputs: &VarArray) -> Result<VarArray, String> {
    let buffers = inputs.iter_shared().enumerate().map(|(i, v)| to_buffer(&v, i)).collect::<Result<Vec<_>, _>>()?;
    let mut out = VarArray::new();
    for buffer in slice.step(&buffers)? {
        out.push(&to_variant(buffer));
    }
    Ok(out)
}

/// Keeps the error text for `last_error` and hands Godot an empty array instead.
fn answer(error: &mut GString, result: Result<VarArray, String>) -> VarArray {
    match result {
        Ok(out) => {
            *error = GString::new();
            out
        }
        Err(text) => {
            *error = text.as_str().into();
            VarArray::new()
        }
    }
}
