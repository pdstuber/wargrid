//! Movement slice (`simulation.gd` `_advance` with `locomotion.gd`). Buffers and number audit: docs/reference/native-sim-spike-slice-move.md.

use crate::{Buffer, Slice};

pub const ARRIVED: u8 = 1;
pub const FALLBACK: u8 = 2;
const INPUTS: usize = 14;
const KIND_COLUMNS: usize = 7;
const WHEELS: f64 = 1.0;
const AIR: f64 = 2.0;

#[derive(Default)]
pub struct Movement;

/// Pass-through for timing the hand-off: same validation and buffers, no movement.
#[derive(Default)]
pub struct Pass;

impl Slice for Movement {
    fn step(&mut self, inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        let input = Input::parse(inputs)?;
        let mut out = Output::new(input.ids.len());
        for i in 0..input.ids.len() {
            out.push(advance(&input, i));
        }
        Ok(out.into_buffers())
    }
}

impl Slice for Pass {
    fn step(&mut self, inputs: &[Buffer]) -> Result<Vec<Buffer>, String> {
        let input = Input::parse(inputs)?;
        let n = input.ids.len();
        Ok(vec![
            Buffer::F64(input.x.to_vec()),
            Buffer::F64(input.y.to_vec()),
            Buffer::F64(input.hx.to_vec()),
            Buffer::F64(input.hy.to_vec()),
            Buffer::F64(input.speed.to_vec()),
            Buffer::I32(vec![0; n]),
            Buffer::U8(vec![0; n]),
        ])
    }
}

struct Input<'a> {
    ids: &'a [i64],
    kind: &'a [i32],
    x: &'a [f64],
    y: &'a [f64],
    hx: &'a [f64],
    hy: &'a [f64],
    speed: &'a [f64],
    move_after: &'a [i64],
    length: &'a [i32],
    wx: &'a [f64],
    wy: &'a [f64],
    starts: Vec<usize>,
    tick: i64,
    kinds: &'a [f64],
}

fn f64s<'a>(b: &'a Buffer, name: &str) -> Result<&'a [f64], String> {
    if let Buffer::F64(v) = b { Ok(v) } else { Err(format!("move: {name} must be F64")) }
}
fn i64s<'a>(b: &'a Buffer, name: &str) -> Result<&'a [i64], String> {
    if let Buffer::I64(v) = b { Ok(v) } else { Err(format!("move: {name} must be I64")) }
}
fn i32s<'a>(b: &'a Buffer, name: &str) -> Result<&'a [i32], String> {
    if let Buffer::I32(v) = b { Ok(v) } else { Err(format!("move: {name} must be I32")) }
}

impl<'a> Input<'a> {
    fn parse(b: &'a [Buffer]) -> Result<Self, String> {
        if b.len() != INPUTS {
            return Err(format!("move: expected {INPUTS} inputs, got {}", b.len()));
        }
        let ids = i64s(&b[0], "ids")?;
        let n = ids.len();
        let count = i32s(&b[8], "count")?;
        let mut input = Input {
            ids,
            kind: i32s(&b[1], "kind")?,
            x: f64s(&b[2], "x")?,
            y: f64s(&b[3], "y")?,
            hx: f64s(&b[4], "heading_x")?,
            hy: f64s(&b[5], "heading_y")?,
            speed: f64s(&b[6], "speed")?,
            move_after: i64s(&b[7], "move_after")?,
            length: i32s(&b[9], "length")?,
            wx: f64s(&b[10], "waypoint_x")?,
            wy: f64s(&b[11], "waypoint_y")?,
            starts: Vec::with_capacity(n + 1),
            tick: 0,
            kinds: f64s(&b[13], "kinds")?,
        };
        let rows = [input.kind.len(), input.x.len(), input.y.len(), input.hx.len(), input.hy.len(), input.speed.len()];
        if rows.iter().chain([input.move_after.len(), count.len(), input.length.len()].iter()).any(|&len| len != n) {
            return Err(format!("move: a per-row buffer is not {n} long"));
        }
        let tick = i64s(&b[12], "tick")?;
        input.tick = *tick.first().filter(|_| tick.len() == 1).ok_or("move: tick must hold one value")?;
        if !input.kinds.len().is_multiple_of(KIND_COLUMNS) {
            return Err("move: kind table is not a multiple of 7".into());
        }
        let kinds = input.kinds.len() / KIND_COLUMNS;
        if let Some(k) = input.kinds.chunks(KIND_COLUMNS).position(|c| c[1] != 0.0 && c[1] != WHEELS && c[1] != AIR) {
            return Err(format!("move: kind {k} has an unknown locomotor"));
        }
        let mut start = 0usize;
        for (i, (&kind, (&sent, &length))) in input.kind.iter().zip(count.iter().zip(input.length)).enumerate() {
            if kind < 0 || kind as usize >= kinds {
                return Err(format!("move: row {i} kind {kind} outside the table"));
            }
            if sent < 0 || sent > length {
                return Err(format!("move: row {i} sends {sent} of {length} waypoints"));
            }
            input.starts.push(start);
            start += sent as usize;
        }
        input.starts.push(start);
        if input.wx.len() != start || input.wy.len() != start {
            return Err(format!("move: waypoint buffers hold {} and {}, counts sum to {start}", input.wx.len(), input.wy.len()));
        }
        Ok(input)
    }

    fn kind(&self, i: usize) -> Kind {
        let c = &self.kinds[self.kind[i] as usize * KIND_COLUMNS..][..KIND_COLUMNS];
        Kind { speed: c[0], locomotor: c[1], accel: c[2], brake: c[3], turn_cos: c[4], turn_sin: c[5], min_turn_speed: c[6] }
    }

    fn route(&self, i: usize) -> Route<'_> {
        let span = self.starts[i]..self.starts[i + 1];
        Route { x: &self.wx[span.clone()], y: &self.wy[span], length: self.length[i] as usize }
    }
}

struct Kind {
    speed: f64,
    locomotor: f64,
    accel: f64,
    brake: f64,
    turn_cos: f64,
    turn_sin: f64,
    min_turn_speed: f64,
}

/// The kernel asked for a waypoint beyond the prefix it was sent; GDScript moves that unit instead.
struct NeedMore;

struct Route<'a> {
    x: &'a [f64],
    y: &'a [f64],
    length: usize,
}

impl Route<'_> {
    fn at(&self, j: usize) -> Result<Option<(f64, f64)>, NeedMore> {
        if j < self.x.len() {
            Ok(Some((self.x[j], self.y[j])))
        } else if j < self.length {
            Err(NeedMore)
        } else {
            Ok(None)
        }
    }
}

struct Unit {
    x: f64,
    y: f64,
    hx: f64,
    hy: f64,
    speed: f64,
    move_after: i64,
}

#[derive(Default)]
struct Row {
    x: f64,
    y: f64,
    hx: f64,
    hy: f64,
    speed: f64,
    consumed: i32,
    flags: u8,
}

struct Output {
    x: Vec<f64>,
    y: Vec<f64>,
    hx: Vec<f64>,
    hy: Vec<f64>,
    speed: Vec<f64>,
    consumed: Vec<i32>,
    flags: Vec<u8>,
}

impl Output {
    fn new(n: usize) -> Self {
        let f = || Vec::with_capacity(n);
        Output { x: f(), y: f(), hx: f(), hy: f(), speed: f(), consumed: Vec::with_capacity(n), flags: Vec::with_capacity(n) }
    }

    fn push(&mut self, row: Row) {
        self.x.push(row.x);
        self.y.push(row.y);
        self.hx.push(row.hx);
        self.hy.push(row.hy);
        self.speed.push(row.speed);
        self.consumed.push(row.consumed);
        self.flags.push(row.flags);
    }

    fn into_buffers(self) -> Vec<Buffer> {
        vec![
            Buffer::F64(self.x),
            Buffer::F64(self.y),
            Buffer::F64(self.hx),
            Buffer::F64(self.hy),
            Buffer::F64(self.speed),
            Buffer::I32(self.consumed),
            Buffer::U8(self.flags),
        ]
    }
}

// Godot's MIN and MAX, not f64::min/max, so ties and signed zeros pick the same operand.
fn minf(a: f64, b: f64) -> f64 {
    if a < b { a } else { b }
}
fn maxf(a: f64, b: f64) -> f64 {
    if a > b { a } else { b }
}

type Vec2 = (f32, f32);

fn is_zero(v: Vec2) -> bool {
    v.0 == 0.0 && v.1 == 0.0
}

fn advance(input: &Input, i: usize) -> Row {
    let route = input.route(i);
    let mut unit = Unit {
        x: input.x[i],
        y: input.y[i],
        hx: input.hx[i],
        hy: input.hy[i],
        speed: input.speed[i],
        move_after: input.move_after[i],
    };
    match walk(&mut unit, &input.kind(i), input.tick, &route) {
        Ok(consumed) => {
            let arrived = consumed == route.length;
            Row {
                x: unit.x,
                y: unit.y,
                hx: unit.hx,
                hy: unit.hy,
                speed: if arrived { 0.0 } else { unit.speed },
                consumed: consumed as i32,
                flags: if arrived { ARRIVED } else { 0 },
            }
        }
        Err(NeedMore) => Row { flags: FALLBACK, ..Row::default() },
    }
}

/// `Simulation._advance` without its GDScript-only arrival rules; returns the waypoints consumed.
fn walk(unit: &mut Unit, kind: &Kind, tick: i64, route: &Route) -> Result<usize, NeedMore> {
    let mut remaining = locomote(unit, kind, tick, route)?;
    let (mut x, mut y) = (unit.x, unit.y);
    let mut consumed = 0;
    while let Some((wx, wy)) = route.at(consumed)? {
        let dx = wx - x;
        let dy = wy - y;
        let distance = (dx * dx + dy * dy).sqrt();
        if distance <= remaining + 1e-5 {
            x = wx;
            y = wy;
            remaining = maxf(0.0, remaining - distance);
            consumed += 1;
        } else {
            x += dx / distance * remaining;
            y += dy / distance * remaining;
            break;
        }
    }
    unit.x = x;
    unit.y = y;
    Ok(consumed)
}

/// `Locomotion.step`: updates heading and speed, returns the distance to move this tick.
fn locomote(unit: &mut Unit, kind: &Kind, tick: i64, route: &Route) -> Result<f64, NeedMore> {
    let cap = kind.speed;
    let desired = desired(unit, route)?;
    if kind.locomotor == AIR {
        if !is_zero(desired) {
            unit.hx = desired.0 as f64;
            unit.hy = desired.1 as f64;
        }
        return Ok(cap / 30.0);
    }
    let mut factor = 1.0;
    if !is_zero(desired) && (desired.0 as f64 != unit.hx || desired.1 as f64 != unit.hy) {
        let heading = (unit.hx as f32, unit.hy as f32);
        factor = heading_factor(kind, angle_between(heading, desired));
        let turned = if kind.locomotor == WHEELS {
            wheel_turn(heading, desired, unit.speed, kind)
        } else {
            turn(heading, desired, kind.turn_cos, kind.turn_sin)
        };
        unit.hx = turned.0 as f64;
        unit.hy = turned.1 as f64;
    }
    if tick < unit.move_after {
        return Ok(0.0);
    }
    let remaining = route_length_until(unit, route, 2.0 * kind.brake, cap * cap, cap / 30.0)?;
    let stoppable = (2.0 * kind.brake * remaining).sqrt();
    unit.speed = minf(minf(unit.speed + kind.accel / 30.0, cap * factor), stoppable);
    Ok(minf(unit.speed / 30.0, remaining))
}

fn desired(unit: &Unit, route: &Route) -> Result<Vec2, NeedMore> {
    let Some((wx, wy)) = route.at(0)? else { return Ok((0.0, 0.0)) };
    let dx = wx - unit.x;
    let dy = wy - unit.y;
    let length = (dx * dx + dy * dy).sqrt();
    if length < 1e-9 {
        return Ok((0.0, 0.0));
    }
    Ok(((dx / length) as f32, (dy / length) as f32))
}

fn wheel_turn(heading: Vec2, desired: Vec2, speed: f64, kind: &Kind) -> Vec2 {
    let k = minf(speed / maxf(kind.min_turn_speed, kind.speed / 4.0), 1.0);
    let sin_step = kind.turn_sin * k;
    turn(heading, desired, (1.0 - sin_step * sin_step).sqrt(), sin_step)
}

// Literals exactly as in locomotion.gd, so both languages parse the same text.
#[allow(clippy::approx_constant, clippy::excessive_precision)]
fn angle_between(a: Vec2, b: Vec2) -> f64 {
    let (ax, ay, bx, by) = (a.0 as f64, a.1 as f64, b.0 as f64, b.1 as f64);
    let dot = ax * bx + ay * by;
    let x = dot.abs();
    let y = (ax * by - ay * bx).abs();
    let high = maxf(x, y);
    if high == 0.0 {
        return 0.0;
    }
    let z = minf(x, y) / high;
    let z2 = z * z;
    let mut t = z * (0.99997726 + z2 * (-0.33262347 + z2 * (0.19354346 + z2 * (-0.11643287 + z2 * (0.05265332 - 0.01172120 * z2)))));
    if y > x {
        t = 1.5707963267948966 - t;
    }
    if dot < 0.0 {
        t = 3.141592653589793 - t;
    }
    t * 57.295779513082323
}

fn turn(heading: Vec2, desired: Vec2, cos_step: f64, sin_step: f64) -> Vec2 {
    let (hx, hy, dx, dy) = (heading.0 as f64, heading.1 as f64, desired.0 as f64, desired.1 as f64);
    if hx * dx + hy * dy >= cos_step {
        return desired;
    }
    let sign = if hx * dy - hy * dx < 0.0 { -1.0 } else { 1.0 };
    let tx = (hx * cos_step - sign * hy * sin_step) as f32;
    let ty = (sign * hx * sin_step + hy * cos_step) as f32;
    // Vector2::operator/(real_t): the float64 length is narrowed to float32 first.
    let length = ((tx as f64) * (tx as f64) + (ty as f64) * (ty as f64)).sqrt() as f32;
    (tx / length, ty / length)
}

fn heading_factor(kind: &Kind, angle: f64) -> f64 {
    if kind.locomotor == WHEELS {
        if angle <= 9.0 {
            return 1.0;
        }
        return maxf(kind.min_turn_speed, kind.speed / 4.0) / kind.speed;
    }
    maxf(0.0, 1.0 - angle / 45.0)
}

fn route_length_until(unit: &Unit, route: &Route, two_brake: f64, cap_squared: f64, step_cap: f64) -> Result<f64, NeedMore> {
    let (mut x, mut y) = (unit.x, unit.y);
    let mut total = 0.0;
    let mut j = 0;
    while let Some((wx, wy)) = route.at(j)? {
        let dx = wx - x;
        let dy = wy - y;
        total += (dx * dx + dy * dy).sqrt();
        if two_brake * total >= cap_squared && total >= step_cap {
            return Ok(total);
        }
        x = wx;
        y = wy;
        j += 1;
    }
    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    const RIFLE: [f64; 7] = [0.8, 0.0, 4.0, 4.0, 0.9579895123154889, 0.28680323271109026, 0.0];
    const SCOUT: [f64; 7] = [2.4, WHEELS, 40.0, 40.0, 0.9945218953682733, 0.10452846326765347, 0.8];
    const HELI: [f64; 7] = [6.0, AIR, 0.0, 0.0, 0.0, 0.0, 0.0];

    struct Case {
        kind: [f64; 7],
        pos: (f64, f64),
        heading: (f64, f64),
        speed: f64,
        move_after: i64,
        route: Vec<(f64, f64)>,
        sent: usize,
        tick: i64,
    }

    impl Case {
        fn new(kind: [f64; 7], route: Vec<(f64, f64)>) -> Self {
            let sent = route.len();
            Case { kind, pos: (0.0, 0.0), heading: (1.0, 0.0), speed: 0.0, move_after: 0, route, sent, tick: 10 }
        }

        fn inputs(&self) -> Vec<Buffer> {
            let sent = &self.route[..self.sent];
            vec![
                Buffer::I64(vec![7]),
                Buffer::I32(vec![0]),
                Buffer::F64(vec![self.pos.0]),
                Buffer::F64(vec![self.pos.1]),
                Buffer::F64(vec![self.heading.0]),
                Buffer::F64(vec![self.heading.1]),
                Buffer::F64(vec![self.speed]),
                Buffer::I64(vec![self.move_after]),
                Buffer::I32(vec![self.sent as i32]),
                Buffer::I32(vec![self.route.len() as i32]),
                Buffer::F64(sent.iter().map(|p| p.0).collect()),
                Buffer::F64(sent.iter().map(|p| p.1).collect()),
                Buffer::I64(vec![self.tick]),
                Buffer::F64(self.kind.to_vec()),
            ]
        }

        fn run(&self) -> (Row, Vec<Buffer>) {
            let out = Movement.step(&self.inputs()).unwrap();
            let f = |b: usize| if let Buffer::F64(v) = &out[b] { v[0] } else { panic!() };
            let consumed = if let Buffer::I32(v) = &out[5] { v[0] } else { panic!() };
            let flags = if let Buffer::U8(v) = &out[6] { v[0] } else { panic!() };
            (Row { x: f(0), y: f(1), hx: f(2), hy: f(3), speed: f(4), consumed, flags }, out)
        }
    }

    #[test]
    fn passes_several_waypoints_in_one_tick() {
        let mut case = Case::new(HELI, vec![(0.05, 0.0), (0.1, 0.0), (0.15, 0.0), (5.0, 0.0)]);
        case.speed = 6.0;
        let (row, _) = case.run();
        assert_eq!((row.consumed, row.flags), (3, 0));
        assert!(row.x > 0.15 && row.x < 0.2 + 1e-9, "the rest of the step goes towards the fourth waypoint");
    }

    #[test]
    fn arrives_within_the_tolerance() {
        let mut case = Case::new(HELI, vec![(0.2 + 0.9e-5, 0.0)]);
        case.speed = 6.0;
        let (row, _) = case.run();
        assert_eq!((row.consumed, row.flags, row.speed), (1, ARRIVED, 0.0));
        assert_eq!(row.x, 0.2 + 0.9e-5);
        case.route = vec![(0.2 + 1.1e-5, 0.0)];
        assert_eq!(case.run().0.flags, 0);
    }

    #[test]
    fn zero_length_step_keeps_heading_and_arrives() {
        let mut case = Case::new(RIFLE, vec![(0.0, 0.0)]);
        case.heading = (0.0, 1.0);
        let (row, _) = case.run();
        assert_eq!((row.hx, row.hy), (0.0, 1.0));
        assert_eq!((row.consumed, row.flags), (1, ARRIVED));
    }

    #[test]
    fn waits_before_move_after_but_turns() {
        let mut case = Case::new(RIFLE, vec![(0.0, 3.0)]);
        case.move_after = 11;
        let (row, _) = case.run();
        assert_eq!((row.x, row.y, row.speed, row.consumed), (0.0, 0.0, 0.0, 0));
        assert!(row.hy > 0.0 && row.hx < 1.0, "turned towards the waypoint");
        assert_eq!(row.hx, (row.hx as f32) as f64, "heading holds float32 values");
    }

    #[test]
    fn air_snaps_heading_and_moves_at_cap() {
        let case = Case::new(HELI, vec![(0.0, 3.0)]);
        let (row, _) = case.run();
        assert_eq!((row.hx, row.hy), (0.0, 1.0));
        assert_eq!(row.y, 6.0 / 30.0);
        assert_eq!(row.speed, 0.0, "air keeps its stored speed");
    }

    #[test]
    fn wheels_below_turn_speed_turn_slower() {
        let mut slow = Case::new(SCOUT, vec![(0.0, 3.0)]);
        slow.speed = 0.2;
        let mut fast = Case::new(SCOUT, vec![(0.0, 3.0)]);
        fast.speed = 2.0;
        assert!(slow.run().0.hy < fast.run().0.hy);
        assert!(slow.run().0.hy > 0.0);
    }

    #[test]
    fn short_prefix_falls_back() {
        let mut case = Case::new(HELI, vec![(0.05, 0.0), (0.1, 0.0), (0.15, 0.0), (5.0, 0.0)]);
        case.sent = 2;
        let (row, _) = case.run();
        assert_eq!((row.flags, row.consumed, row.x), (FALLBACK, 0, 0.0));
        case.sent = 4;
        assert_eq!(case.run().0.flags, 0);
    }

    #[test]
    fn empty_route_arrives_in_place() {
        let mut case = Case::new(RIFLE, vec![]);
        case.pos = (2.5, 3.5);
        case.speed = 0.5;
        let (row, _) = case.run();
        assert_eq!((row.x, row.y, row.speed, row.consumed, row.flags), (2.5, 3.5, 0.0, 0, ARRIVED));
    }

    #[test]
    fn no_rows_gives_empty_outputs() {
        let mut case = Case::new(RIFLE, vec![]);
        let mut inputs = case.inputs();
        for b in [0usize, 1, 2, 3, 4, 5, 6, 7, 8, 9] {
            inputs[b] = match &inputs[b] {
                Buffer::I64(_) => Buffer::I64(vec![]),
                Buffer::I32(_) => Buffer::I32(vec![]),
                _ => Buffer::F64(vec![]),
            };
        }
        let out = Movement.step(&inputs).unwrap();
        assert!(out.len() == 7 && out.iter().all(Buffer::is_empty));
        case.sent = 0;
        assert!(Pass.step(&case.inputs()).unwrap().len() == 7);
    }

    #[test]
    fn rejects_bad_input() {
        let case = Case::new(RIFLE, vec![(1.0, 0.0)]);
        let mut bad = case.inputs();
        bad[1] = Buffer::I32(vec![1]);
        assert!(Movement.step(&bad).unwrap_err().contains("outside the table"));
        let mut bad = case.inputs();
        bad[10] = Buffer::F64(vec![]);
        assert!(Movement.step(&bad).unwrap_err().contains("counts sum"));
        let mut bad = case.inputs();
        bad[8] = Buffer::I32(vec![2]);
        assert!(Movement.step(&bad).unwrap_err().contains("sends 2 of 1"));
        assert!(Movement.step(&[]).unwrap_err().contains("expected 14 inputs"));
        assert!(Pass.step(&case.inputs()[..13]).is_err());
    }

    #[test]
    fn pass_copies_without_moving() {
        let mut case = Case::new(RIFLE, vec![(1.0, 0.0)]);
        case.pos = (0.5, 0.25);
        let out = Pass.step(&case.inputs()).unwrap();
        assert!(crate::first_difference(&out[..2], &[Buffer::F64(vec![0.5]), Buffer::F64(vec![0.25])]).is_none());
    }
}
