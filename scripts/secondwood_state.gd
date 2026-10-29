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
var artemis_accepted: bool = false
var relic_attunements: Array[String] = []
var crossings_complete: Array[String] = []
var repair_anchors: Dictionary = {}
var acorn_state: String = "absent"
var artemis_finale_done: bool = false
# Focus and hold progress are deliberately ephemeral.
var lens_focused: bool = false
var lens_progress: float = 0.0

func flags() -> Array:
	var result: Array = healed.duplicate()
	result.append_array(inventory)
	result.append_array(crossings_complete)
	if acorn_state=="planted": result.append("planted")
	return result

func reset_lens() -> void:
	lens_focused = false
	lens_progress = 0.0

func accept_artemis_quest() -> Dictionary:
	if position2().distance_to(Layout.ARTEMIS)>5.5: return {"type":"far"}
	artemis_accepted = true
	if can_carry_acorn() and acorn_state=="absent":
		acorn_state = "carried"
		return {"type":"acorn","text":"Artemis: Carry this dormant acorn to Crown Clearing. Plant it with the Rootheart Spindle, then return to me by the young roots."}
	return {"type":"artemis","text":"Artemis: "+objective()}

func can_carry_acorn() -> bool:
	return artemis_accepted and healed.size()==3 and crossings_complete.has("west-ridge-roots") and crossings_complete.has("east-root-bridge")

func activate_relic_target(id: String) -> Dictionary:
	if id=="attune":
		if position2().distance_to(Layout.SITES.source.position)>3.5: return {"type":"far"}
		if not inventory.has("lens") or not healed.has("source"): return {"type":"blocked","text":"The Moon Lens needs the restored spring and the Spring Vessel."}
		if not relic_attunements.has("lens"): relic_attunements.append("lens")
		return {"type":"attuned","text":"Clean spring water clarifies the Moon Lens. Return to the western Moon Plinth; focus it and sustain D."}
	if not Layout.TARGETS.has(id): return {"type":"unknown"}
	if position2().distance_to(Layout.TARGETS[id].position)>3.5: return {"type":"far"}
	if crossings_complete.has(id): return {"type":"already","text":"This crossing stays open. Your relic remains in your pack."}
	match id:
		"west-sluice":
			if not inventory.has("vessel"): return {"type":"blocked","text":"Return with the reusable Spring Vessel to fill this sluice."}
			crossings_complete.append(id)
			return {"type":"opened","text":"Water lifts the sluice roots. The wetland now returns directly to the Dry Source."}
		"west-ridge-roots":
			if not relic_attunements.has("lens"): return {"type":"blocked","text":"Find the Moon Lens here with the Spring Vessel, then attune it at the restored Dry Source."}
			lens_focused = true
			lens_progress = 0.0
			return {"type":"focused","text":"Moon Lens focused. Raise pipes and sustain natural D for 1.5 seconds, or use the Hold D toggle."}
		"east-root-bridge","ash-east-cut":
			if not inventory.has("spool"): return {"type":"blocked","text":"The Root Spool sleeps in the eastern Cinder Loom. Bring the Living Spore."}
			if id=="ash-east-cut" and not healed.has("ash"): return {"type":"blocked","text":"Heal the Ash Scar with the Rootheart Spindle first."}
			if not repair_anchors.has(id): repair_anchors[id] = []
			return {"type":"repair","text":"Bind each of the three marked stumps with E. The next unbound anchor shines gold; your work is saved."}
		"south-return":
			crossings_complete.append(id)
			return {"type":"opened","text":"The southern latch releases. Both outer branches now join along the southern walk."}
	return {"type":"unknown"}

func bind_anchor(id: String, anchor: int) -> Dictionary:
	if not Layout.ANCHORS.has(id) or anchor<0 or anchor>=3: return {"type":"unknown"}
	if not repair_anchors.has(id) or not inventory.has("spool"): return {"type":"blocked"}
	if position2().distance_to(Layout.ANCHORS[id][anchor])>1.6: return {"type":"far"}
	if repair_anchors[id].has(anchor): return {"type":"already","text":"This stump is bound. Follow the next gold anchor."}
	repair_anchors[id].append(anchor)
	if repair_anchors[id].size()==3:
		if not crossings_complete.has(id): crossings_complete.append(id)
		return {"type":"opened","text":"The third root catches. A living bridge reconnects the two paths."}
	return {"type":"bound","text":"Root anchor bound · %d / 3. The Root Spool remains reusable." % repair_anchors[id].size()}

func hold_lens(delta: float, pitches: Array, allowed: bool = true) -> Dictionary:
	if not lens_focused: return {}
	if not allowed or position2().distance_to(Layout.TARGETS["west-ridge-roots"].position)>3.5:
		reset_lens()
		return {}
	var correct: bool = not pitches.is_empty()
	for pitch in pitches:
		if posmod(int(pitch),12)!=2: correct = false
	lens_progress = minf(1.5,lens_progress+maxf(0.0,delta)) if correct else 0.0
	if lens_progress<1.5: return {}
	if not crossings_complete.has("west-ridge-roots"): crossings_complete.append("west-ridge-roots")
	reset_lens()
	return {"type":"opened","text":"Moonlight traces buried roots. The western ridge crossing remains revealed."}

func plant_acorn() -> Dictionary:
	if position2().distance_to(Layout.CROWN)>3.5: return {"type":"far"}
	if acorn_state=="planted": return {"type":"already","text":"The young canopy is growing. Follow the new descent back to Artemis."}
	if acorn_state!="carried" or not inventory.has("spindle") or not can_carry_acorn(): return {"type":"blocked","text":"Artemis holds a dormant acorn for the one who heals three lands and mends both relic crossings. Bring the Rootheart Spindle."}
	acorn_state = "planted"
	return {"type":"planted","text":"The spindle settles the acorn among living roots. A young canopy rises and opens the ridge descent. Return to Artemis."}


func position2() -> Vector2:
	return Vector2(float(player.x),float(player.z))

func collect_item(id: String) -> bool:
	if not Layout.ITEMS.has(id) or inventory.has(id): return false
	var item: Dictionary = Layout.ITEMS[id]
	if position2().distance_to(item.position)>1.25: return false
	if not Layout.requirements_met(item.get("requires",[]),flags()): return false
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
	var artemis_song: bool = acorn_state=="planted" and artemis_accepted and not artemis_finale_done and position2().distance_to(Layout.ARTEMIS)<=5.5
	var grove_song: bool = not won and healed.size()==3 and position2().distance_to(Layout.FINAL)<=4.0
	if not artemis_song and not grove_song:
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
		if artemis_song: artemis_finale_done = true
		else: won = true
		phrase.clear()
		return true
	return false

func objective() -> String:
	if not artemis_accepted: return "Artemis waits in the Turning Glade. Press E beside the giant deer to hear her request."
	if artemis_finale_done: return "The young canopy shelters returning creatures. Wander the nine reopened shortcuts and play freely."
	if acorn_state=="planted": return "Return by the ridge descent to Artemis. Raise pipes beside her and play Q E U I U E Q."
	if acorn_state=="carried": return "Carry Artemis's acorn to Crown Clearing on the northern ridge. Press E to plant with the Rootheart Spindle."
	if can_carry_acorn(): return "Return to Artemis at the Turning Glade. She has a dormant acorn for the recovered ridge."
	if healed.size()==3:
		if not inventory.has("lens") or not inventory.has("spool"): return "Artemis: Find the Moon Lens in the western wetlands with the Vessel, and wake the eastern Root Spool with the Spore. Either branch can come first."
		if not relic_attunements.has("lens"): return "Seat the Moon Lens at the restored Dry Source with E. Then revisit the western Moon Plinth."
		return "Mend both ridge crossings: focus the western Moon Plinth with D, and bind the three eastern root anchors with the Root Spool."
	if won: return "The branching wood is breathing again. Walk its reopened loops and play freely."
	if not inventory.has("vessel"): return "A dry spring and a sealed northern walk. Follow the long western curl to find the Spring Vessel."
	if not healed.has("source"): return "Carry the Spring Vessel back to the dry source. Press E there to let the water return."
	if not inventory.has("spore"): return "The source has opened a northern trail. A Living Spore waits along the eastern coil for the wounded hollow."
	if not healed.has("hollow"): return "Return with the Living Spore to the hollow. Its living roots can reconnect the eastern shortcut."
	if not inventory.has("spindle"): return "Follow the newly opened northern spiral to the Rootheart Spindle. Remember the ash scar on your way back."
	if not healed.has("ash"): return "Bring the Rootheart Spindle back to the ash scar. New roots will reconnect the last shortcut."
	return "All three lands have healed. Follow the open paths to the final grove and play Q E U I U E Q."

func serialize() -> Dictionary:
	return {"version":2,"player":player.duplicate(),"inventory":inventory.duplicate(),"healed":healed.duplicate(),"won":won,"elapsed":elapsed,"artemis_accepted":artemis_accepted,"relic_attunements":relic_attunements.duplicate(),"crossings_complete":crossings_complete.duplicate(),"repair_anchors":repair_anchors.duplicate(true),"acorn_state":acorn_state,"artemis_finale_done":artemis_finale_done}

func restore(value: Variant) -> void:
	if not value is Dictionary: return
	player = {"x":Layout.ENTRY.x,"z":Layout.ENTRY.y,"yaw":0.0}
	elapsed = 0.0
	phrase.clear()
	inventory.clear()
	healed.clear()
	relic_attunements.clear()
	crossings_complete.clear()
	repair_anchors.clear()
	acorn_state = "absent"
	reset_lens()
	var record: Variant = value.get("player",{})
	if record is Dictionary:
		for key in player:
			var number: Variant = record.get(key,player[key])
			if (number is int or number is float) and is_finite(float(number)):
				player[key] = clampf(float(number),-10000.0,10000.0) if key=="yaw" else clampf(float(number),-Layout.BOUNDS,Layout.BOUNDS)
	if value.get("inventory",[]) is Array:
		for id in value.get("inventory",[]):
			if id is String and Layout.ITEMS.has(id) and not inventory.has(id): inventory.append(id)
	if value.get("healed",[]) is Array:
		for id in value.get("healed",[]):
			if id is String and Layout.SITES.has(id) and inventory.has(str(Layout.SITES[id].item)) and not healed.has(id): healed.append(id)
	if inventory.has("lens") and not inventory.has("vessel"): inventory.erase("lens")
	if inventory.has("spool") and not inventory.has("spore"): inventory.erase("spool")
	# The northern spindle cannot be acquired before its source route opens.
	if inventory.has("spindle") and not healed.has("source"):
		inventory.erase("spindle")
		healed.erase("ash")
	var seconds: Variant = value.get("elapsed",0.0)
	if (seconds is int or seconds is float) and is_finite(float(seconds)): elapsed = clampf(float(seconds),0.0,1000000000.0)
	won = value.get("won",false)==true and healed.size()==Layout.SITES.size()

	# Version 1 has none of these fields. Its old completion remains independent.
	artemis_accepted = value.get("artemis_accepted",false)==true
	if value.get("relic_attunements",[]) is Array and inventory.has("lens") and healed.has("source"):
		if value.get("relic_attunements",[]).has("lens"): relic_attunements.append("lens")
	var repairs: Variant = value.get("repair_anchors",{})
	if repairs is Dictionary and inventory.has("spool"):
		for id: String in Layout.ANCHORS:
			if not repairs.get(id,[]) is Array: continue
			if id=="ash-east-cut" and not healed.has("ash"): continue
			repair_anchors[id] = []
			for anchor in repairs.get(id,[]):
				if (anchor is int or anchor is float) and is_finite(float(anchor)):
					if float(anchor)==int(anchor) and int(anchor) in [0,1,2] and not repair_anchors[id].has(int(anchor)): repair_anchors[id].append(int(anchor))
			if repair_anchors[id].size()==3: crossings_complete.append(id)
	var crossings: Variant = value.get("crossings_complete",[])
	if crossings is Array:
		for id in crossings:
			if id=="south-return" or (id=="west-sluice" and inventory.has("vessel")) or (id=="west-ridge-roots" and relic_attunements.has("lens")):
				if not crossings_complete.has(id): crossings_complete.append(id)
	if can_carry_acorn() and value.get("acorn_state","") in ["carried","planted"]: acorn_state = value.acorn_state
	artemis_finale_done = value.get("artemis_finale_done",false)==true and acorn_state=="planted"
	var safe: Vector2 = Layout.nearest_safe(position2(),flags())
	player.x = safe.x
	player.z = safe.y
