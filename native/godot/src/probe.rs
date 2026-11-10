//! Browser and snapshot probes: feasibility only, no rules.

use godot::prelude::*;

const ROUTE_LEN: usize = 60;
const STATUS: [&str; 3] = ["moving", "idle", "attacking"];
const KINDS: [&str; 2] = ["china_rifle_infantry", "usa_rifle_infantry"];

struct Rec {
    id: i32,
    owner: i32,
    pos: [f64; 2],
    status: u8,
    route: Vec<[f64; 2]>,
    kind: u8,
    hp: i32,
    speed: f64,
    move_after: i32,
}

fn make_recs(n: usize) -> Vec<Rec> {
    (0..n)
        .map(|i| Rec {
            id: i as i32 + 1,
            owner: (i % 2) as i32 + 1,
            pos: [6.5 + (i % 40) as f64 * 0.125, 10.5 + (i / 40) as f64],
            status: (i % 3) as u8,
            route: (0..ROUTE_LEN).map(|k| [7.5 + k as f64, 10.5]).collect(),
            kind: (i % 2) as u8,
            hp: 120_000,
            speed: 1.0,
            move_after: 2,
        })
        .collect()
}

fn pair(p: [f64; 2]) -> Variant {
    varray![p[0], p[1]].to_variant()
}

fn put(d: &mut VarDictionary, key: impl ToGodot, value: impl ToGodot) {
    d.set(&key.to_variant(), &value.to_variant());
}

fn dict_of(r: &Rec) -> VarDictionary {
    let mut route = VarArray::new();
    for p in &r.route {
        route.push(&pair(*p));
    }
    let mut order = VarDictionary::new();
    put(&mut order, "type", "move");
    put(&mut order, "target", pair([60.5, 24.5]));
    let mut combat = VarDictionary::new();
    put(&mut combat, "mode", "attack_move");
    put(&mut combat, "target_id", Variant::nil());
    put(&mut combat, "goal", pair([60.5, 24.5]));
    for (k, v) in [("next_fire_tick", 0), ("shots_left", 0), ("repath_tick", 103)] {
        put(&mut combat, k, v);
    }
    put(&mut combat, "retarget", false);
    put(&mut combat, "until", 0);
    put(&mut combat, StringName::from("horde"), 1);
    put(&mut combat, StringName::from("horde_tick"), 127);
    let mut d = VarDictionary::new();
    put(&mut d, "id", r.id);
    put(&mut d, "owner", r.owner);
    put(&mut d, "position", pair(r.pos));
    put(&mut d, "order", order);
    put(&mut d, "status", STATUS[r.status as usize]);
    put(&mut d, "route", route);
    put(&mut d, "destination", pair([60.5, 24.5]));
    put(&mut d, "kind", KINDS[r.kind as usize]);
    put(&mut d, "hp", r.hp);
    put(&mut d, "max_hp", r.hp);
    put(&mut d, "combat", combat);
    put(&mut d, "speed", r.speed);
    put(&mut d, "move_after", r.move_after);
    put(&mut d, "heading", pair([1.0, 0.0]));
    put(&mut d, "construction_id", Variant::nil());
    put(&mut d, "collection", Variant::nil());
    d
}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WargridProbe {
    recs: Vec<Rec>,
}

#[godot_api]
impl WargridProbe {
    #[func]
    fn version(&self) -> GString {
        concat!("wargrid_native ", env!("CARGO_PKG_VERSION")).into()
    }

    #[func]
    fn echo(&self, input: PackedFloat64Array) -> PackedFloat64Array {
        input.as_slice().iter().map(|x| x * 2.0 + 1.0).collect()
    }

    #[func]
    fn load_records(&mut self, n: i64) {
        self.recs = make_recs(n.max(0) as usize);
    }

    #[func]
    fn snapshot_dicts(&self, n: i64) -> Array<VarDictionary> {
        self.recs.iter().take(n.max(0) as usize).map(dict_of).collect()
    }

    // Column per field: the packed shape a presentation reader would take instead of dictionaries.
    #[func]
    fn snapshot_packed(&self, n: i64) -> VarArray {
        let rs = self.recs.iter().take(n.max(0) as usize);
        let mut ids = Vec::new();
        let (mut owners, mut hp, mut move_after, mut route_len) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
        let (mut pos, mut speed, mut route) = (Vec::new(), Vec::new(), Vec::new());
        let (mut status, mut kind) = (Vec::new(), Vec::new());
        for r in rs {
            ids.push(r.id);
            owners.push(r.owner);
            hp.push(r.hp);
            move_after.push(r.move_after);
            route_len.push(r.route.len() as i32);
            pos.extend_from_slice(&r.pos);
            speed.push(r.speed);
            route.extend(r.route.iter().flatten());
            status.push(r.status);
            kind.push(r.kind);
        }
        let mut out = VarArray::new();
        out.push(&PackedInt32Array::from(ids).to_variant());
        out.push(&PackedInt32Array::from(owners).to_variant());
        out.push(&PackedFloat64Array::from(pos).to_variant());
        out.push(&PackedInt32Array::from(hp).to_variant());
        out.push(&PackedFloat64Array::from(speed).to_variant());
        out.push(&PackedInt32Array::from(move_after).to_variant());
        out.push(&PackedInt32Array::from(route_len).to_variant());
        out.push(&PackedFloat64Array::from(route).to_variant());
        out.push(&PackedByteArray::from(status).to_variant());
        out.push(&PackedByteArray::from(kind).to_variant());
        out
    }

    // Touches every page so linear memory really grows while the caller holds a packed array.
    #[func]
    fn grow(&self, megabytes: i64) -> i64 {
        let mut block = vec![0u8; megabytes.max(0) as usize * 1_048_576];
        for (i, b) in block.iter_mut().enumerate().step_by(4096) {
            *b = (i >> 12) as u8;
        }
        std::hint::black_box(block.iter().step_by(4096).map(|&b| b as i64).sum())
    }

    #[func]
    fn panic_now(&self) {
        panic!("probe panic");
    }
}
