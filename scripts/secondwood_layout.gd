extends RefCounted
## The second woodland is a network of bordered walks. Place names and route
## shapes are implementation choices for the requested branching return level.
const BOUNDS: float = 90.0
const CORRIDOR_RADIUS: float = 2.6
const ENTRY := Vector2(0,65)
const HUB := Vector2(0,40)
const FINAL := Vector2(54,-63)
const ITEMS: Dictionary = {
	"vessel":{"name":"Spring Vessel","position":Vector2(-57,-1),"description":"Carries clean spring water. Return it to the dry source.","requires":""},
	"spore":{"name":"Living Spore","position":Vector2(57,-2),"description":"Coaxes roots through poisoned ground. Return to the sealed hollow.","requires":""},
	"spindle":{"name":"Rootheart Spindle","position":Vector2(5,-60),"description":"Binds living roots beneath ash. Return to the ash scar.","requires":"source"}
}
const SITES: Dictionary = {
	"source":{"name":"The Dry Source","position":Vector2(-15,25),"item":"vessel","description":"The channel has run dry. A Spring Vessel can bring its water back."},
	"hollow":{"name":"The Sealed Hollow","position":Vector2(18,20),"item":"spore","description":"Old roots lie sick beneath the path. A Living Spore can wake them."},
	"ash":{"name":"The Ash Scar","position":Vector2(0,-5),"item":"spindle","description":"The soil has burned loose. A Rootheart Spindle can bind it again."}
}
const PATHS: Array = [
	{"id":"arrival","points":[ENTRY,Vector2(6,58),Vector2(4,49),HUB],"requires":""},
	{"id":"source-approach","points":[HUB,Vector2(-8,32),Vector2(-15,25)],"requires":""},
	{"id":"hollow-approach","points":[HUB,Vector2(10,31),Vector2(18,20)],"requires":""},
	{"id":"ash-approach","points":[HUB,Vector2(0,21),Vector2(-4,9),Vector2(0,-5)],"requires":""},
	{"id":"western-curl","points":[HUB,Vector2(-12,42),Vector2(-30,45),Vector2(-50,57),Vector2(-70,50),Vector2(-78,30),Vector2(-76,5),Vector2(-65,-14),Vector2(-43,-12),Vector2(-37,4),Vector2(-48,15),Vector2(-60,6),Vector2(-57,-1)],"requires":""},
	{"id":"eastern-curl","points":[HUB,Vector2(17,45),Vector2(40,55),Vector2(68,52),Vector2(79,32),Vector2(76,8),Vector2(60,-10),Vector2(38,-14),Vector2(30,1),Vector2(42,14),Vector2(56,10),Vector2(57,-2)],"requires":""},
	{"id":"northern-spiral","points":[Vector2(0,-5),Vector2(-8,-24),Vector2(-30,-38),Vector2(-45,-56),Vector2(-35,-74),Vector2(-12,-82),Vector2(13,-77),Vector2(31,-62),Vector2(30,-43),Vector2(14,-35),Vector2(2,-44),Vector2(5,-60)],"requires":"source"},
	{"id":"final-curl","points":[Vector2(18,20),Vector2(20,-3),Vector2(41,-30),Vector2(63,-45),Vector2(72,-65),Vector2(55,-79),Vector2(38,-77),Vector2(42,-65),FINAL],"requires":"all"}
]
const SHORTCUTS: Array = [
	{"id":"source-cut","points":[Vector2(-15,25),Vector2(-28,23),Vector2(-38,17),Vector2(-48,15)],"requires":"source"},
	{"id":"hollow-cut","points":[Vector2(18,20),Vector2(26,13),Vector2(34,10),Vector2(42,14)],"requires":"hollow"},
	{"id":"ash-cut","points":[Vector2(0,-5),Vector2(2,-20),Vector2(9,-30),Vector2(14,-35)],"requires":"ash"}
]
const CLEARINGS: Array = [
	{"id":"entry","name":"THE SECOND WOOD","position":ENTRY,"radius":6.0,"requires":""},
	{"id":"hub","name":"THE TURNING GLADE","position":HUB,"radius":7.0,"requires":""},
	{"id":"source","name":"THE DRY SOURCE","position":Vector2(-15,25),"radius":5.6,"requires":""},
	{"id":"hollow","name":"THE SEALED HOLLOW","position":Vector2(18,20),"radius":5.6,"requires":""},
	{"id":"ash","name":"THE ASH SCAR","position":Vector2(0,-5),"radius":5.6,"requires":""},
	{"id":"vessel","name":"THE SPRING SHELF","position":Vector2(-57,-1),"radius":5.0,"requires":""},
	{"id":"spore","name":"THE SPORE BOWER","position":Vector2(57,-2),"radius":5.0,"requires":""},
	{"id":"spindle","name":"THE ROOTHEART","position":Vector2(5,-60),"radius":5.6,"requires":"source"},
	{"id":"final","name":"THE JOINED GROVE","position":FINAL,"radius":6.5,"requires":"all"}
]

static func requirements_met(requirement: String, healed: Array) -> bool:
	if requirement.is_empty(): return true
	if requirement == "all": return healed.has("source") and healed.has("hollow") and healed.has("ash")
	return healed.has(requirement)

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
		if requirements_met(str(clearing.requires),healed) and point.distance_to(clearing.position)<=float(clearing.radius): return true
	for route: Dictionary in all_routes():
		if requirements_met(str(route.requires),healed) and route_distance(point,route.points)<=CORRIDOR_RADIUS: return true
	return false

static func route_length(points: Array) -> float:
	var length: float = 0.0
	for i in range(1,points.size()): length += Vector2(points[i-1]).distance_to(points[i])
	return length
