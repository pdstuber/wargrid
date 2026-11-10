//! Horde step slice (`horde.gd` `Horde.step`). Buffer layout: docs/reference/native-sim-spike-slice-horde.md.

use crate::{Buffer, Slice};
use std::collections::HashMap;

const INPUTS: usize = 12;

/// Per-kind rule table, kept between calls; replaced whenever a call carries a new one.
#[derive(Default)]
struct Kinds {
    radius: Vec<f64>,
    combat_radius: Vec<f64>,
    count: Vec<i32>,
    by_class: Vec<bool>,
    class: Vec<i32>,
    rate: Vec<i32>,
}

#[derive(Default)]
pub struct Horde {
    kinds: Option<Kinds>,
}

struct View<'a> {
    ids: &'a [i64],
    px: &'a [f64],
    py: &'a [f64],
    kind: &'a [i32],
    owner: &'a [i32],
    team: &'a [i32],
    contained: &'a [u8],
    horde_tick: &'a [i64],
    level: &'a [u8],
    tick: i64,
    kind_f: &'a [f64],
    kind_i: &'a [i32],
}

fn column<'a, T>(inputs: &'a [Buffer], at: usize, pick: fn(&'a Buffer) -> Option<&'a [T]>, name: &str) -> Result<&'a [T], String> {
    pick(&inputs[at]).ok_or_else(|| format!("horde: input {at} ({name}) has the wrong type"))
}

impl<'a> View<'a> {
    fn parse(inputs: &'a [Buffer]) -> Result<Self, String> {
        if inputs.len() != INPUTS {
            return Err(format!("horde: expected {INPUTS} inputs, got {}", inputs.len()));
        }
        let i64s = |b: &'a Buffer| if let Buffer::I64(v) = b { Some(v.as_slice()) } else { None };
        let f64s = |b: &'a Buffer| if let Buffer::F64(v) = b { Some(v.as_slice()) } else { None };
        let i32s = |b: &'a Buffer| if let Buffer::I32(v) = b { Some(v.as_slice()) } else { None };
        let u8s = |b: &'a Buffer| if let Buffer::U8(v) = b { Some(v.as_slice()) } else { None };
        let view = View {
            ids: column(inputs, 0, i64s, "id")?,
            px: column(inputs, 1, f64s, "x")?,
            py: column(inputs, 2, f64s, "y")?,
            kind: column(inputs, 3, i32s, "kind")?,
            owner: column(inputs, 4, i32s, "owner")?,
            team: column(inputs, 5, i32s, "team")?,
            contained: column(inputs, 6, u8s, "contained")?,
            horde_tick: column(inputs, 7, i64s, "horde_tick")?,
            level: column(inputs, 8, u8s, "level")?,
            tick: *column(inputs, 9, i64s, "tick")?.first().ok_or("horde: tick buffer is empty")?,
            kind_f: column(inputs, 10, f64s, "kind_f")?,
            kind_i: column(inputs, 11, i32s, "kind_i")?,
        };
        let n = view.ids.len();
        let same = [view.px.len(), view.py.len(), view.kind.len(), view.owner.len(), view.team.len(), view.contained.len(), view.horde_tick.len(), view.level.len()];
        if same.iter().any(|&len| len != n) {
            return Err("horde: per-unit columns differ in length".into());
        }
        Ok(view)
    }

    fn due(&self, i: usize) -> bool {
        self.horde_tick[i] <= self.tick && self.contained[i] == 0
    }
}

impl Kinds {
    fn parse(kind_f: &[f64], kind_i: &[i32]) -> Result<Kinds, String> {
        let k = kind_f.len() / 2;
        if kind_f.len() != 2 * k || kind_i.len() != 4 * k {
            return Err("horde: kind table has the wrong shape".into());
        }
        let ints = |at: usize| (0..k).map(move |n| kind_i[4 * n + at]);
        Ok(Kinds {
            radius: (0..k).map(|n| kind_f[2 * n]).collect(),
            combat_radius: (0..k).map(|n| kind_f[2 * n + 1]).collect(),
            count: ints(0).collect(),
            by_class: ints(1).map(|m| m == 1).collect(),
            class: ints(2).collect(),
            rate: ints(3).collect(),
        })
    }
}

type Grid = HashMap<(i32, i32), Vec<usize>>;

fn cell(v: &View, i: usize, size: f64) -> (i32, i32) {
    ((v.px[i] / size).floor() as i32, (v.py[i] / size).floor() as i32)
}

fn hostile(v: &View, a: usize, b: usize) -> bool {
    v.owner[a] != v.owner[b] && (v.team[a] == 0 || v.team[b] == 0 || v.team[a] != v.team[b])
}

impl Horde {
    fn kinds(&self) -> Result<&Kinds, String> {
        self.kinds.as_ref().ok_or_else(|| "horde: no kind table received".to_string())
    }

    fn check_rows(&self, v: &View) -> Result<(), String> {
        if v.ids.is_empty() {
            return Ok(());
        }
        let k = self.kinds()?.radius.len() as i32;
        if v.kind.iter().any(|&kind| kind < 0 || kind >= k) {
            return Err("horde: kind index outside the table".into());
        }
        Ok(())
    }

    fn cell_size(&self, v: &View) -> f64 {
        let kinds = self.kinds.as_ref().expect("checked");
        let (mut widest, mut largest) = (0.0_f64, 0.0_f64);
        for &kind in v.kind {
            widest = widest.max(kinds.radius[kind as usize]);
            largest = largest.max(kinds.combat_radius[kind as usize]);
        }
        widest + 2.0 * largest
    }

    fn level_of(&self, v: &View, level: &[u8], grid: &Grid, size: f64, i: usize) -> u8 {
        let kinds = self.kinds.as_ref().expect("checked");
        let ki = v.kind[i] as usize;
        let need = kinds.count[ki] - 1;
        if need <= 0 {
            return 2;
        }
        let (mut near, mut rubbed) = (0, false);
        let home = cell(v, i, size);
        for dy in -1..=1 {
            for dx in -1..=1 {
                let Some(bucket) = grid.get(&(home.0.wrapping_add(dx), home.1.wrapping_add(dy))) else { continue };
                for &j in bucket {
                    let kj = v.kind[j] as usize;
                    let same = if kinds.by_class[ki] { kinds.class[kj] == kinds.class[ki] } else { kj == ki };
                    if v.ids[j] == v.ids[i] || v.contained[j] != 0 || hostile(v, i, j) || !same {
                        continue;
                    }
                    let (ox, oy) = (v.px[j] - v.px[i], v.py[j] - v.py[i]);
                    let gap = (ox * ox + oy * oy).sqrt() - kinds.combat_radius[ki] - kinds.combat_radius[kj];
                    if gap.max(0.0) > kinds.radius[ki] {
                        continue;
                    }
                    near += 1;
                    rubbed = rubbed || level[j] == 2;
                    if near >= need {
                        return 2;
                    }
                }
            }
        }
        u8::from(rubbed)
    }

    /// Hand-off timing: the same conversion work as `step`, outputs sized like the real ones, no rule work beyond counting due rows.
    pub fn pass(&self, inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        let v = View::parse(inputs)?;
        let due = (0..v.ids.len()).filter(|&i| v.due(i)).count();
        Ok(vec![Buffer::I32(vec![0; due]), Buffer::U8(vec![0; due]), Buffer::I64(vec![0; due]), Buffer::U8(vec![0; due])])
    }
}

impl Slice for Horde {
    fn step(&mut self, inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        let v = View::parse(inputs)?;
        if !v.kind_f.is_empty() || !v.kind_i.is_empty() {
            self.kinds = Some(Kinds::parse(v.kind_f, v.kind_i)?);
        }
        self.check_rows(&v)?;
        let mut level = v.level.to_vec();
        let (mut rows, mut levels, mut ticks, mut changed) = (vec![], vec![], vec![], vec![]);
        let mut grid = Grid::new();
        let mut size = 0.0;
        for i in (0..v.ids.len()).filter(|&i| v.due(i)) {
            if grid.is_empty() {
                size = self.cell_size(&v);
                for j in 0..v.ids.len() {
                    grid.entry(cell(&v, j, size)).or_default().push(j);
                }
            }
            let rate = i64::from(self.kinds()?.rate[v.kind[i] as usize]);
            let new = self.level_of(&v, &level, &grid, size, i);
            rows.push(i as i32);
            levels.push(new);
            ticks.push(v.tick + rate);
            changed.push(u8::from((level[i] > 0) != (new > 0)));
            level[i] = new;
        }
        Ok(vec![Buffer::I32(rows), Buffer::U8(levels), Buffer::I64(ticks), Buffer::U8(changed)])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Kind 0: count 3, radius 1.2, by class; kind 1: count 1; kind 2: count 3 by kind (class 0 as kind 0).
    fn table() -> [Buffer; 2] {
        [
            Buffer::F64(vec![1.2, 0.0, 1.2, 0.0, 1.2, 0.0]),
            Buffer::I32(vec![3, 1, 0, 30, 1, 1, 1, 31, 3, 0, 0, 30]),
        ]
    }

    // (id, x, kind, owner, team, contained, horde_tick, level)
    type Row = (i64, f64, i32, i32, i32, u8, i64, u8);
    const fn row(id: i64, x: f64) -> Row {
        (id, x, 0, 1, 1, 0, 0, 0)
    }

    fn inputs(rows: &[Row], tick: i64, with_table: bool) -> Vec<Buffer> {
        let col = |f: fn(&Row) -> i32| Buffer::I32(rows.iter().map(f).collect());
        let [kind_f, kind_i] = if with_table { table() } else { [Buffer::F64(vec![]), Buffer::I32(vec![])] };
        vec![
            Buffer::I64(rows.iter().map(|r| r.0).collect()),
            Buffer::F64(rows.iter().map(|r| r.1).collect()),
            Buffer::F64(vec![0.0; rows.len()]),
            col(|r| r.2),
            col(|r| r.3),
            col(|r| r.4),
            Buffer::U8(rows.iter().map(|r| r.5).collect()),
            Buffer::I64(rows.iter().map(|r| r.6).collect()),
            Buffer::U8(rows.iter().map(|r| r.7).collect()),
            Buffer::I64(vec![tick]),
            kind_f,
            kind_i,
        ]
    }

    fn levels(out: &[Buffer]) -> Vec<u8> {
        match &out[1] {
            Buffer::U8(v) => v.clone(),
            _ => panic!("levels"),
        }
    }

    fn run(rows: &[Row]) -> Vec<Buffer> {
        Horde::default().step(&inputs(rows, 10, true)).unwrap()
    }

    #[test]
    fn earlier_level_is_visible_to_later_unit() {
        assert_eq!(levels(&run(&[row(1, 0.0), row(2, -1.0), row(3, 1.0)])), [2, 1, 1]);
        assert_eq!(levels(&run(&[row(2, -1.0), row(1, 0.0), row(3, 1.0)])), [0, 2, 1]);
    }

    #[test]
    fn contained_and_hostile_do_not_count() {
        let mut rows = [row(1, 0.0), row(2, 0.5), row(3, 1.0)];
        assert_eq!(levels(&run(&rows)), [2, 2, 2]);
        rows[1].5 = 1;
        let out = run(&rows);
        assert_eq!(levels(&out), [0, 0]);
        rows[1].5 = 0;
        rows[1].3 = 2;
        rows[1].4 = 2;
        assert_eq!(levels(&run(&rows)), [0, 0, 0]);
        rows[1].4 = 0;
        assert_eq!(levels(&run(&rows)), [0, 0, 0]);
    }

    #[test]
    fn small_need_is_level_two_and_changed_flag_follows_zero_crossing() {
        let mut rows = [row(1, 0.0)];
        rows[0].2 = 1;
        let out = run(&rows);
        assert_eq!(levels(&out), [2]);
        assert!(matches!(&out[3], Buffer::U8(v) if v == &[1]));
        assert!(matches!(&out[2], Buffer::I64(v) if v == &[41]));
        rows[0].7 = 2;
        assert!(matches!(&run(&rows)[3], Buffer::U8(v) if v == &[0]));
    }

    #[test]
    fn match_by_kind_or_class() {
        let mut rows = [row(1, 0.0), row(2, 0.5), row(3, 1.0)];
        rows[0].2 = 2;
        rows[1].2 = 2;
        rows[2].2 = 0;
        assert_eq!(levels(&run(&rows))[0], 0);
        rows[0].2 = 0;
        rows[1].2 = 2;
        assert_eq!(levels(&run(&rows))[0], 2);
    }

    #[test]
    fn nothing_due_and_no_members() {
        let mut rows = [row(1, 0.0), row(2, 0.5), row(3, 1.0)];
        rows.iter_mut().for_each(|r| r.6 = 11);
        let out = run(&rows);
        assert!(out.iter().all(Buffer::is_empty));
        assert!(run(&[]).iter().all(Buffer::is_empty));
    }

    #[test]
    fn rejects_bad_input_and_keeps_table() {
        let mut core = Horde::default();
        assert!(core.step(&inputs(&[row(1, 0.0)], 10, false)).unwrap_err().contains("no kind table"));
        assert!(core.step(&inputs(&[row(1, 0.0)], 10, true)).is_ok());
        assert!(core.step(&inputs(&[row(1, 0.0)], 10, false)).is_ok());
        let mut bad = row(1, 0.0);
        bad.2 = 9;
        assert!(core.step(&inputs(&[bad], 10, false)).unwrap_err().contains("outside"));
        assert!(core.step(&[]).is_err());
        let mut short = inputs(&[row(1, 0.0)], 10, false);
        short[1] = Buffer::F64(vec![]);
        assert!(core.step(&short).unwrap_err().contains("length"));
    }

    #[test]
    fn pass_is_sized_like_step() {
        let rows = [row(1, 0.0), row(2, 0.5), row(3, 1.0)];
        let input = inputs(&rows, 10, true);
        let (real, pass) = (Horde::default().step(&input).unwrap(), Horde::default().pass(&input).unwrap());
        assert!(real.iter().zip(&pass).all(|(a, b)| a.tag() == b.tag() && a.len() == b.len()));
    }
}
