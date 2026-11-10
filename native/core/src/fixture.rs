//! Recorded slice fixtures. Format (little-endian) in docs/reference/native-sim-spike-boundary.md "Fixture file".

use crate::Buffer;

pub const MAGIC: &[u8; 4] = b"WGFX";
pub const VERSION: u32 = 1;

#[derive(Clone, Debug)]
pub struct Record {
    pub slice: String,
    pub tick: i64,
    pub inputs: Vec<Buffer>,
    pub outputs: Vec<Buffer>,
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        let end = self.at.checked_add(n).filter(|&end| end <= self.bytes.len());
        let end = end.ok_or_else(|| format!("truncated at byte {}", self.at))?;
        let out = &self.bytes[self.at..end];
        self.at = end;
        Ok(out)
    }

    fn u8(&mut self) -> Result<u8, String> {
        Ok(self.take(1)?[0])
    }

    fn u32(&mut self) -> Result<u32, String> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }

    fn i64(&mut self) -> Result<i64, String> {
        Ok(i64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }

    fn buffer(&mut self) -> Result<Buffer, String> {
        let tag = self.u8()?;
        let count = self.u32()? as usize;
        let width = match tag {
            1 => 1,
            2 | 4 => 4,
            3 | 5 => 8,
            _ => return Err(format!("unknown buffer tag {tag} at byte {}", self.at - 5)),
        };
        let raw = self.take(count.checked_mul(width).ok_or("buffer too large")?)?;
        let words = raw.chunks_exact(width);
        Ok(match tag {
            1 => Buffer::U8(raw.to_vec()),
            2 => Buffer::I32(words.map(|w| i32::from_le_bytes(w.try_into().unwrap())).collect()),
            3 => Buffer::I64(words.map(|w| i64::from_le_bytes(w.try_into().unwrap())).collect()),
            4 => Buffer::F32(words.map(|w| f32::from_le_bytes(w.try_into().unwrap())).collect()),
            _ => Buffer::F64(words.map(|w| f64::from_le_bytes(w.try_into().unwrap())).collect()),
        })
    }

    fn buffers(&mut self) -> Result<Vec<Buffer>, String> {
        let count = self.u32()?;
        (0..count).map(|_| self.buffer()).collect()
    }
}

pub fn read(bytes: &[u8]) -> Result<Vec<Record>, String> {
    let mut r = Reader { bytes, at: 0 };
    if r.take(4)? != MAGIC {
        return Err("not a WGFX fixture".into());
    }
    let version = r.u32()?;
    if version != VERSION {
        return Err(format!("fixture version {version}, expected {VERSION}"));
    }
    let mut records = Vec::new();
    while r.at < bytes.len() {
        let len = r.u8()? as usize;
        let slice = String::from_utf8(r.take(len)?.to_vec()).map_err(|_| "slice name is not UTF-8")?;
        let tick = r.i64()?;
        let inputs = r.buffers()?;
        let outputs = r.buffers()?;
        records.push(Record { slice, tick, inputs, outputs });
    }
    Ok(records)
}

fn put_buffer(out: &mut Vec<u8>, buffer: &Buffer) {
    out.push(buffer.tag());
    out.extend((buffer.len() as u32).to_le_bytes());
    match buffer {
        Buffer::U8(v) => out.extend(v),
        Buffer::I32(v) => v.iter().for_each(|x| out.extend(x.to_le_bytes())),
        Buffer::I64(v) => v.iter().for_each(|x| out.extend(x.to_le_bytes())),
        Buffer::F32(v) => v.iter().for_each(|x| out.extend(x.to_le_bytes())),
        Buffer::F64(v) => v.iter().for_each(|x| out.extend(x.to_le_bytes())),
    }
}

pub fn write(records: &[Record]) -> Vec<u8> {
    let mut out = MAGIC.to_vec();
    out.extend(VERSION.to_le_bytes());
    for record in records {
        out.push(record.slice.len() as u8);
        out.extend(record.slice.as_bytes());
        out.extend(record.tick.to_le_bytes());
        for list in [&record.inputs, &record.outputs] {
            out.extend((list.len() as u32).to_le_bytes());
            list.iter().for_each(|b| put_buffer(&mut out, b));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::first_difference;

    // Same bytes as test_native_horde.gd test_fixture_bytes writes through NativeBridge.
    const SAMPLE: &str = "574746580100000005686f72646507000000000000000200000002010000000700000005020000000000000000000080000000000000f83f01000000010100000001";

    fn sample() -> Record {
        Record {
            slice: "horde".into(),
            tick: 7,
            inputs: vec![Buffer::I32(vec![7]), Buffer::F64(vec![-0.0, 1.5])],
            outputs: vec![Buffer::U8(vec![1])],
        }
    }

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    #[test]
    fn writes_documented_bytes() {
        assert_eq!(hex(&write(&[sample()])), SAMPLE);
    }

    #[test]
    fn round_trips_bits() {
        let records = read(&write(&[sample(), sample()])).unwrap();
        assert_eq!(records.len(), 2);
        assert_eq!(records[1].slice, "horde");
        assert_eq!(records[1].tick, 7);
        assert!(first_difference(&sample().inputs, &records[1].inputs).is_none());
        assert!(first_difference(&sample().outputs, &records[1].outputs).is_none());
    }

    #[test]
    fn rejects_bad_input() {
        assert!(read(b"XXXX\x01\0\0\0").is_err());
        let bytes = write(&[sample()]);
        assert!(read(&bytes[..bytes.len() - 1]).unwrap_err().contains("truncated"));
        let mut bad = bytes.clone();
        bad[26] = 9; // first input buffer's tag
        assert!(read(&bad).unwrap_err().contains("tag"));
    }
}
