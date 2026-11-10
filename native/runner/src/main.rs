//! Standalone caller without Godot: replays recorded fixtures bit for bit or times the kernels alone.

use std::collections::BTreeMap;
use std::process::ExitCode;
use std::time::Instant;
use wargrid_core::fixture::{self, Record};
use wargrid_core::{first_difference, new_slice, Slice};

const USAGE: &str = "usage: wargrid_runner replay <file> | bench <file> <repeats>";

fn load(path: &str) -> Result<Vec<Record>, String> {
    let bytes = std::fs::read(path).map_err(|e| format!("{path}: {e}"))?;
    fixture::read(&bytes)
}

// One instance per slice for the whole file, because a slice may keep state across ticks.
fn instance<'a>(slices: &'a mut BTreeMap<String, Box<dyn Slice>>, name: &str) -> Result<&'a mut Box<dyn Slice>, String> {
    if !slices.contains_key(name) {
        slices.insert(name.to_string(), new_slice(name)?);
    }
    Ok(slices.get_mut(name).unwrap())
}

fn replay(records: &[Record]) -> Result<String, String> {
    let mut slices = BTreeMap::new();
    let mut ticks = std::collections::BTreeSet::new();
    for record in records {
        let outputs = instance(&mut slices, &record.slice)?.step(&record.inputs);
        let outputs = outputs.map_err(|e| format!("REPLAY ERROR slice={} tick={} {e}", record.slice, record.tick))?;
        if let Some(diff) = first_difference(&record.outputs, &outputs) {
            return Err(format!("REPLAY MISMATCH slice={} tick={} {diff}", record.slice, record.tick));
        }
        ticks.insert(record.tick);
    }
    Ok(format!("REPLAY OK ticks={} records={}", ticks.len(), records.len()))
}

fn bench(records: &[Record], repeats: u32) -> Result<String, String> {
    let mut total = BTreeMap::<String, (u128, usize)>::new();
    for _ in 0..repeats {
        let mut slices = BTreeMap::new();
        for record in records {
            let slice = instance(&mut slices, &record.slice)?;
            let start = Instant::now();
            let outputs = slice.step(&record.inputs)?;
            let elapsed = start.elapsed().as_nanos();
            std::hint::black_box(outputs);
            let entry = total.entry(record.slice.clone()).or_default();
            entry.0 += elapsed;
            entry.1 += 1;
        }
    }
    let lines: Vec<String> = total
        .iter()
        .map(|(name, (ns, calls))| {
            format!("KERNEL slice={name} repeats={repeats} calls={calls} total_us={} per_call_us={:.3}", ns / 1000, *ns as f64 / 1000.0 / *calls as f64)
        })
        .collect();
    Ok(lines.join("\n"))
}

fn run(args: &[String]) -> Result<String, String> {
    match args {
        [cmd, file] if cmd == "replay" => replay(&load(file)?),
        [cmd, file, repeats] if cmd == "bench" => {
            let repeats = repeats.parse().map_err(|_| format!("bad repeats: {repeats}"))?;
            bench(&load(file)?, repeats)
        }
        _ => Err(USAGE.into()),
    }
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match run(&args) {
        Ok(text) => {
            println!("{text}");
            ExitCode::SUCCESS
        }
        Err(text) => {
            println!("{text}");
            ExitCode::FAILURE
        }
    }
}
