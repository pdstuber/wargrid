use godot::prelude::*;

// Stub until T7 (browser and snapshot probes).
#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WargridProbe {}

#[godot_api]
impl WargridProbe {
    #[func]
    fn version(&self) -> GString {
        concat!("wargrid_native ", env!("CARGO_PKG_VERSION")).into()
    }
}
