extends RefCounted
## Computer instrument layout adapted from MBean1-Astra piano-performance.js.
## Keep these unusual row positions: they are the user's established instrument.
## https://github.com/eyehaveewe-cyber/MBean1/blob/MBean1-Astra/piano-performance.js
const DEFAULT_OCTAVE: int = 3
const OFFSETS: Dictionary = {
	KEY_A:0, KEY_S:2, KEY_D:4, KEY_F:5, KEY_J:7, KEY_K:9, KEY_L:11,
	KEY_Q:12, KEY_W:14, KEY_E:16, KEY_R:17, KEY_U:19, KEY_I:21, KEY_O:23,
	KEY_Z:-12, KEY_X:-10, KEY_C:-8, KEY_V:-7, KEY_M:-5, KEY_COMMA:-3, KEY_PERIOD:-1,
	KEY_T:24, KEY_Y:26, KEY_B:-24, KEY_N:-22
}
const ROWS: Array = [
	[KEY_Q,KEY_W,KEY_E,KEY_R,KEY_U,KEY_I,KEY_O],
	[KEY_A,KEY_S,KEY_D,KEY_F,KEY_J,KEY_K,KEY_L],
	[KEY_Z,KEY_X,KEY_C,KEY_V,KEY_M,KEY_COMMA,KEY_PERIOD],
	[KEY_T,KEY_Y,KEY_B,KEY_N]
]
const ROW_NAMES: Array[String] = ["Upper +1", "Current", "Lower -1", "Outer +2 / -2"]
const PITCH_NAMES: Array[String] = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

static func pitch_for_key(keycode: int, octave: int = DEFAULT_OCTAVE, sharp: bool = false) -> int:
	if not OFFSETS.has(keycode):
		return -1
	var natural: int = (octave+1)*12+int(OFFSETS[keycode])
	var pitch: int = natural+(1 if sharp and posmod(natural,12) in [0,2,5,7,9] else 0)
	return pitch if pitch>=0 and pitch<=127 else -1

static func note_name(pitch: int) -> String:
	return PITCH_NAMES[posmod(pitch,12)]+str(floori(float(pitch)/12.0)-1)

static func key_name(keycode: int) -> String:
	if keycode == KEY_COMMA: return ","
	if keycode == KEY_PERIOD: return "."
	return OS.get_keycode_string(keycode)

static func label_for_pitch(pitch: int, octave: int = DEFAULT_OCTAVE) -> String:
	for keycode: int in OFFSETS:
		if pitch_for_key(keycode,octave) == pitch:
			return key_name(keycode)
	for keycode: int in OFFSETS:
		if pitch_for_key(keycode,octave,true) == pitch:
			return "Space+"+key_name(keycode)
	return note_name(pitch)

static func rows(octave: int = DEFAULT_OCTAVE, sharp: bool = false) -> Array:
	var result: Array = []
	for index in ROWS.size():
		var entries: Array = []
		for keycode: int in ROWS[index]:
			var pitch: int = pitch_for_key(keycode,octave,sharp)
			entries.append({"keycode":keycode,"key":key_name(keycode),"pitch":pitch,"note":note_name(pitch) if pitch>=0 else "—"})
		result.append({"name":ROW_NAMES[index],"keys":entries})
	return result

static func octave_for_modifier(keycode: int, location: int = 0) -> int:
	# InputEventKey.location is 2 for the right-hand key, 1 for the left.
	if keycode == KEY_CTRL: return 1 if location==2 else 4
	if keycode == KEY_SHIFT: return 2 if location==2 else 5
	if keycode == KEY_CAPSLOCK: return 6
	if keycode == KEY_TAB: return 7
	return -1
