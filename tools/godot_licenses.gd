extends SceneTree

# Writes the running engine's license and third-party notices, which every distributed build must carry.
# usage: godot --headless --script "$PWD/tools/godot_licenses.gd" -- OUT_PATH


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: godot --headless --script tools/godot_licenses.gd -- OUT_PATH")
		quit(1)
		return
	var out: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		printerr("cannot write ", args[0], ": ", error_string(FileAccess.get_open_error()))
		quit(1)
		return
	out.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n" + Engine.get_license_text() + "\n")
	for entry: Dictionary in Engine.get_copyright_info():
		out.store_string("\n- " + str(entry.name) + "\n")
		for part: Dictionary in entry.parts:
			out.store_string("  files: " + ", ".join(part.files) + "\n")
			out.store_string("  copyright: " + "; ".join(part.copyright) + "\n")
			out.store_string("  license: " + str(part.license) + "\n")
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for name: Variant in names:
		out.store_string("\n" + str(name) + "\n\n" + str(licenses[name]) + "\n")
	out.close()
	quit(0)
