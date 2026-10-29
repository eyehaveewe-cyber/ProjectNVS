extends RefCounted
## Chapter two owns its quest inventory and never rewrites the first valley save.
const Layout = preload("res://scripts/secondwood_layout.gd")
const FINAL_PHRASE: Array[int] = [60,64,67,69,67,64,60]
var player: Dictionary = {"x":Layout.ENTRY.x,"z":Layout.ENTRY.y,"yaw":0.0}
var inventory: Array[String] = []
var healed: Array[String] = []
var won: bool = false
var elapsed: float = 0.0
var phrase: Array[int] = []

func position2() -> Vector2:
	return Vector2(float(player.x),float(player.z))

func collect_item(id: String) -> bool:
	if not Layout.ITEMS.has(id) or inventory.has(id): return false
	var item: Dictionary = Layout.ITEMS[id]
	if position2().distance_to(item.position)>1.25: return false
	if not Layout.requirements_met(str(item.get("requires","")),healed): return false
	inventory.append(id)
	return true

func try_heal(id: String) -> Dictionary:
	if not Layout.SITES.has(id): return {"type":"unknown"}
	var site: Dictionary = Layout.SITES[id]
	if position2().distance_to(site.position)>3.5: return {"type":"far","site":id}
	if healed.has(id): return {"type":"already","site":id}
	if not inventory.has(str(site.item)): return {"type":"missing","site":id,"item":site.item}
	healed.append(id)
	phrase.clear()
	return {"type":"healed","site":id,"item":site.item}

func play_pitch(pitch: int) -> bool:
	if won or healed.size()!=Layout.SITES.size() or position2().distance_to(Layout.FINAL)>4.0:
		phrase.clear()
		return false
	var note: int = 60+posmod(pitch-60,12)
	phrase.append(note)
	while phrase.size()>FINAL_PHRASE.size(): phrase.pop_front()
	# Keep any prefix at the tail of a wrong phrase, so retries stay forgiving.
	while not phrase.is_empty():
		var valid: bool = true
		for i in phrase.size():
			if phrase[i]!=FINAL_PHRASE[i]: valid = false; break
		if valid: break
		phrase.pop_front()
	if phrase==FINAL_PHRASE:
		won = true
		phrase.clear()
		return true
	return false

func objective() -> String:
	if won: return "The branching wood is breathing again. Walk its reopened loops and play freely."
	if not inventory.has("vessel"): return "A dry spring and a sealed northern walk. Follow the long western curl to find the Spring Vessel."
	if not healed.has("source"): return "Carry the Spring Vessel back to the dry source. Press E there to let the water return."
	if not inventory.has("spore"): return "The source has opened a northern trail. A Living Spore waits along the eastern coil for the wounded hollow."
	if not healed.has("hollow"): return "Return with the Living Spore to the hollow. Its living roots can reconnect the eastern shortcut."
	if not inventory.has("spindle"): return "Follow the newly opened northern spiral to the Rootheart Spindle. Remember the ash scar on your way back."
	if not healed.has("ash"): return "Bring the Rootheart Spindle back to the ash scar. New roots will reconnect the last shortcut."
	return "All three lands have healed. Follow the open paths to the final grove and play Q E U I U E Q."

func serialize() -> Dictionary:
	return {"version":1,"player":player.duplicate(),"inventory":inventory.duplicate(),"healed":healed.duplicate(),"won":won,"elapsed":elapsed}

func restore(value: Variant) -> void:
	if not value is Dictionary: return
	var record: Variant = value.get("player",{})
	if record is Dictionary:
		for key in player:
			var number: Variant = record.get(key,player[key])
			if (number is int or number is float) and is_finite(float(number)):
				player[key] = clampf(float(number),-10000.0,10000.0) if key=="yaw" else clampf(float(number),-Layout.BOUNDS,Layout.BOUNDS)
	if value.get("inventory",[]) is Array:
		for id in value.inventory:
			if id is String and Layout.ITEMS.has(id) and not inventory.has(id): inventory.append(id)
	if value.get("healed",[]) is Array:
		for id in value.healed:
			if id is String and Layout.SITES.has(id) and inventory.has(str(Layout.SITES[id].item)) and not healed.has(id): healed.append(id)
	# The northern spindle cannot be acquired before its source route opens.
	if inventory.has("spindle") and not healed.has("source"):
		inventory.erase("spindle")
		healed.erase("ash")
	var seconds: Variant = value.get("elapsed",0.0)
	if (seconds is int or seconds is float) and is_finite(float(seconds)): elapsed = clampf(float(seconds),0.0,1000000000.0)
	won = value.get("won",false)==true and healed.size()==Layout.SITES.size()
