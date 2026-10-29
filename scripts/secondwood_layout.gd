extends RefCounted
## The second woodland is a network of bordered walks. Place names and route
## shapes are implementation choices for the requested branching return level.
const BOUNDS: float = 156.0
const CORRIDOR_RADIUS: float = 2.6
const ENTRY := Vector2(0,65)
const HUB := Vector2(0,40)
const FINAL := Vector2(54,-63)
const ARTEMIS := HUB+Vector2(3.5,-1.0)
const CROWN := Vector2(0,-130)
const LENS := Vector2(-122,10)
const SPOOL := Vector2(122,-15)
const ITEMS: Dictionary = {
	"vessel":{"name":"Spring Vessel","position":Vector2(-57,-1),"description":"Carries clean spring water. Return it to the dry source.","requires":[]},
	"spore":{"name":"Living Spore","position":Vector2(57,-2),"description":"Coaxes roots through poisoned ground. Return to the sealed hollow.","requires":[]},
	"spindle":{"name":"Rootheart Spindle","position":Vector2(5,-60),"description":"Binds living roots beneath ash. Return to the ash scar.","requires":["source"]},
	"lens":{"name":"Moon Lens","position":LENS,"description":"Clean with the Spring Vessel. Attune at the restored source, then focus the western plinth with D.","requires":["vessel"]},
	"spool":{"name":"Root Spool","position":SPOOL,"description":"Wake with the Living Spore. Bind three stumps at each severed root bridge.","requires":["spore"]}
}
const SITES: Dictionary = {
	"source":{"name":"The Dry Source","position":Vector2(-15,25),"item":"vessel","description":"The channel has run dry. A Spring Vessel can bring its water back."},
	"hollow":{"name":"The Sealed Hollow","position":Vector2(18,20),"item":"spore","description":"Old roots lie sick beneath the path. A Living Spore can wake them."},
	"ash":{"name":"The Ash Scar","position":Vector2(0,-5),"item":"spindle","description":"The soil has burned loose. A Rootheart Spindle can bind it again."}
}
const PATHS: Array = [
	{"id":"arrival","points":[ENTRY,Vector2(6,58),Vector2(4,49),HUB],"requires":[]},
	{"id":"source-approach","points":[HUB,Vector2(-8,32),Vector2(-15,25)],"requires":[]},
	{"id":"hollow-approach","points":[HUB,Vector2(10,31),Vector2(18,20)],"requires":[]},
	{"id":"ash-approach","points":[HUB,Vector2(0,21),Vector2(-4,9),Vector2(0,-5)],"requires":[]},
	{"id":"western-curl","points":[HUB,Vector2(-12,42),Vector2(-30,45),Vector2(-50,57),Vector2(-70,50),Vector2(-78,30),Vector2(-76,5),Vector2(-65,-14),Vector2(-43,-12),Vector2(-37,4),Vector2(-48,15),Vector2(-60,6),Vector2(-57,-1)],"requires":[]},
	{"id":"eastern-curl","points":[HUB,Vector2(17,45),Vector2(40,55),Vector2(68,52),Vector2(79,32),Vector2(76,8),Vector2(60,-10),Vector2(38,-14),Vector2(30,1),Vector2(42,14),Vector2(56,10),Vector2(57,-2)],"requires":[]},
	{"id":"northern-spiral","points":[Vector2(0,-5),Vector2(-8,-24),Vector2(-30,-38),Vector2(-45,-56),Vector2(-35,-74),Vector2(-12,-82),Vector2(13,-77),Vector2(31,-62),Vector2(30,-43),Vector2(14,-35),Vector2(2,-44),Vector2(5,-60)],"requires":["source"]},
	{"id":"final-curl","points":[Vector2(18,20),Vector2(20,-3),Vector2(41,-30),Vector2(63,-45),Vector2(72,-65),Vector2(55,-79),Vector2(38,-77),Vector2(42,-65),FINAL],"requires":["source","hollow","ash"]},
	{"id":"wetland-curl","points":[Vector2(-70,50),Vector2(-98,64),Vector2(-126,72),Vector2(-146,52),Vector2(-146,10),Vector2(-140,-28),Vector2(-118,-40),Vector2(-96,-24),Vector2(-100,4),Vector2(-122,10)],"requires":[]},
	{"id":"cinder-curl","points":[Vector2(79,32),Vector2(100,60),Vector2(130,68),Vector2(147,40),Vector2(147,2),Vector2(141,-32),Vector2(120,-52),Vector2(98,-35),Vector2(100,-12),Vector2(122,-15)],"requires":[]},
	{"id":"west-ridge","points":[Vector2(-140,-28),Vector2(-145,-60),Vector2(-130,-93),Vector2(-95,-108),Vector2(-105,-138),Vector2(-78,-148),Vector2(-58,-130),Vector2(-70,-98),Vector2(-64,-115),Vector2(-40,-142),Vector2(0,-146),Vector2(30,-130),Vector2(0,-130)],"requires":[]},
	{"id":"east-ridge","points":[Vector2(141,-32),Vector2(147,-70),Vector2(123,-100),Vector2(90,-112),Vector2(60,-98),Vector2(50,-120),Vector2(30,-130)],"requires":[]},
	{"id":"south-west","points":[Vector2(-126,72),Vector2(-142,96),Vector2(-130,125),Vector2(-100,143),Vector2(-64,142),Vector2(-32,122),Vector2(0,120)],"requires":[]},
	{"id":"south-east","points":[Vector2(130,68),Vector2(143,94),Vector2(128,125),Vector2(100,143),Vector2(63,144),Vector2(40,124),Vector2(20,120)],"requires":[]}
]
const SHORTCUTS: Array = [
	{"id":"source-cut","points":[Vector2(-15,25),Vector2(-28,23),Vector2(-38,17),Vector2(-48,15)],"requires":["source"]},
	{"id":"hollow-cut","points":[Vector2(18,20),Vector2(26,13),Vector2(34,10),Vector2(42,14)],"requires":["hollow"]},
	{"id":"ash-cut","points":[Vector2(0,-5),Vector2(2,-20),Vector2(9,-30),Vector2(14,-35)],"requires":["ash"]},
	{"id":"west-sluice","points":[Vector2(-122,10),Vector2(-110,35),Vector2(-94,45),Vector2(-70,35),Vector2(-50,30),Vector2(-15,25)],"requires":["west-sluice"]},
	{"id":"west-ridge-roots","points":[Vector2(-122,10),Vector2(-110,-15),Vector2(-85,-55),Vector2(-70,-98)],"requires":["west-ridge-roots"]},
	{"id":"east-root-bridge","points":[Vector2(122,-15),Vector2(110,-55),Vector2(88,-85),Vector2(60,-98)],"requires":["east-root-bridge"]},
	{"id":"ash-east-cut","points":[Vector2(0,-5),Vector2(35,-26),Vector2(65,-25),Vector2(98,-35)],"requires":["ash","ash-east-cut"]},
	{"id":"south-return","points":[Vector2(0,120),Vector2(20,120)],"requires":["south-return"]},
	{"id":"ridge-descent","points":[Vector2(0,-130),Vector2(0,-105),Vector2(-5,-90),Vector2(-12,-82)],"requires":["planted"]}
]
const CLEARINGS: Array = [
	{"id":"entry","name":"THE SECOND WOOD","position":ENTRY,"radius":6.0,"requires":[]},
	{"id":"hub","name":"THE TURNING GLADE","position":HUB,"radius":7.0,"requires":[]},
	{"id":"source","name":"THE DRY SOURCE","position":Vector2(-15,25),"radius":5.6,"requires":[]},
	{"id":"hollow","name":"THE SEALED HOLLOW","position":Vector2(18,20),"radius":5.6,"requires":[]},
	{"id":"ash","name":"THE ASH SCAR","position":Vector2(0,-5),"radius":5.6,"requires":[]},
	{"id":"vessel","name":"THE SPRING SHELF","position":Vector2(-57,-1),"radius":5.0,"requires":[]},
	{"id":"spore","name":"THE SPORE BOWER","position":Vector2(57,-2),"radius":5.0,"requires":[]},
	{"id":"spindle","name":"THE ROOTHEART","position":Vector2(5,-60),"radius":5.6,"requires":["source"]},
	{"id":"final","name":"THE JOINED GROVE","position":FINAL,"radius":6.5,"requires":["source","hollow","ash"]},
	{"id":"lens","name":"THE MIRROR WETLAND","position":Vector2(-122,10),"radius":6.0,"requires":[]},
	{"id":"spool","name":"THE CINDER LOOM","position":Vector2(122,-15),"radius":6.0,"requires":[]},
	{"id":"crown","name":"CROWN CLEARING","position":Vector2(0,-130),"radius":7.0,"requires":[]},
	{"id":"west-crossing","name":"THE MOON PLINTH","position":Vector2(-122,16),"radius":4.0,"requires":[]},
	{"id":"east-crossing","name":"THE SEVERED BRIDGE","position":Vector2(122,-21),"radius":7.0,"requires":[]},
	{"id":"ash-crossing","name":"THE ASH WEAVE","position":Vector2(0,-11),"radius":7.0,"requires":["ash"]},
	{"id":"latch","name":"THE SOUTHERN LATCH","position":Vector2(20,120),"radius":4.0,"requires":[]}
]

const TARGETS: Dictionary = {
	"west-sluice":{"position":LENS,"name":"Fill the wetland sluice"},
	"west-ridge-roots":{"position":Vector2(-122,16),"name":"Focus the Moon Lens · sustain D"},
	"east-root-bridge":{"position":Vector2(122,-21),"name":"Begin root bridge repair"},
	"ash-east-cut":{"position":Vector2(0,-11),"name":"Begin ash crossing repair"},
	"south-return":{"position":Vector2(20,120),"name":"Release the southern latch"}
}
const ANCHORS: Dictionary = {
	"east-root-bridge":[Vector2(122,-21),Vector2(120,-23),Vector2(119,-26)],
	"ash-east-cut":[Vector2(0,-11),Vector2(3,-8),Vector2(5,-8)]
}

static func requirements_met(requirements: Array, flags: Array) -> bool:
	for flag in requirements:
		if not flags.has(flag): return false
	return true

static func all_flags() -> Array:
	return ["source","hollow","ash","vessel","spore","spindle","lens","spool","west-sluice","west-ridge-roots","east-root-bridge","ash-east-cut","south-return","planted"]

static func nearest_safe(point: Vector2, flags: Array) -> Vector2:
	if is_walkable(point,flags): return point
	var best: Vector2 = ENTRY
	for route: Dictionary in all_routes():
		if not requirements_met(route.requires,flags): continue
		for vertex: Vector2 in route.points:
			if point.distance_squared_to(vertex)<point.distance_squared_to(best): best = vertex
	return best

static func segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var length: float = (b-a).length_squared()
	if length <= 0.00001: return point.distance_to(a)
	return point.distance_to(a.lerp(b,clampf((point-a).dot(b-a)/length,0.0,1.0)))

static func route_distance(point: Vector2, route: Array) -> float:
	var closest: float = INF
	for i in range(1,route.size()):
		closest = minf(closest,segment_distance(point,route[i-1],route[i]))
	return closest

static func all_routes() -> Array:
	return PATHS+SHORTCUTS

static func is_walkable(point: Vector2, healed: Array) -> bool:
	if maxf(absf(point.x),absf(point.y))>BOUNDS: return false
	for clearing: Dictionary in CLEARINGS:
		if requirements_met(clearing.requires,healed) and point.distance_to(clearing.position)<=float(clearing.radius): return true
	for route: Dictionary in all_routes():
		if requirements_met(route.requires,healed) and route_distance(point,route.points)<=CORRIDOR_RADIUS: return true
	return false

static func route_length(points: Array) -> float:
	var length: float = 0.0
	for i in range(1,points.size()): length += Vector2(points[i-1]).distance_to(points[i])
	return length
