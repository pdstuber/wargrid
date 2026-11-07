extends SceneTree

# Derives every logo size from the 32x32 master; nearest-neighbour keeps the pixel art sharp.
# usage: godot --headless --script "$PWD/tools/logo_sizes.gd" -- REPO_ROOT

const CARD := Color("4d4d4d")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --headless --script tools/logo_sizes.gd -- REPO_ROOT")
		quit(1)
		return
	var root: String = args[0]
	var icon: Image = Image.load_from_file(root + "/game/art/logo-32.png")
	if icon == null:
		printerr("cannot load ", root, "/game/art/logo-32.png")
		quit(1)
		return
	icon.resize(512, 512, Image.INTERPOLATE_NEAREST)
	var ok: bool = _save(icon, root + "/game/icon.png")
	ok = _save(_card(icon, Vector2i(512, 512)), root + "/web/og.png") and ok
	ok = _save(_card(icon, Vector2i(1280, 640)), root + "/docs/images/social.png") and ok
	quit(0 if ok else 1)


func _card(icon: Image, size: Vector2i) -> Image:
	var card: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	card.fill(CARD)
	card.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), (size - icon.get_size()) / 2)
	card.convert(Image.FORMAT_RGB8)
	return card


func _save(image: Image, path: String) -> bool:
	var error: Error = image.save_png(path)
	if error != OK:
		printerr("cannot write ", path, ": ", error_string(error))
	return error == OK
