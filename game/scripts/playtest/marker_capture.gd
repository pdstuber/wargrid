extends RefCounted

const KINDS: Array[String] = ["good", "bad", "confusing"]
const MAX_WIDTH: int = 640
const QUALITY: float = 0.6
const FALLBACK_QUALITY: float = 0.3
const MAX_JPG_BYTES: int = 98304

static func jpg_base64(image: Image) -> String:
	if image == null or image.is_empty(): return ""
	var copy: Image = image.duplicate()
	if copy.is_compressed() and copy.decompress() != OK: return ""
	if copy.get_width() > MAX_WIDTH:
		copy.resize(MAX_WIDTH, maxi(1, roundi(float(copy.get_height()) * MAX_WIDTH / copy.get_width())))
	for quality: float in [QUALITY, FALLBACK_QUALITY]:
		var bytes: PackedByteArray = copy.save_jpg_to_buffer(quality)
		if not bytes.is_empty() and bytes.size() <= MAX_JPG_BYTES: return Marshalls.raw_to_base64(bytes)
	return ""

static func marker(kind: String, text: String, context: Dictionary, jpg: String) -> Dictionary:
	return {"tick": context.get("tick", 0), "kind": kind, "text": text, "camera": context.get("camera", []), "selected": context.get("selected", []), "comment": "", "jpg": jpg}
