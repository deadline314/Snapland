extends RefCounted
## Entry stands of the arcade minigames in regions whose world files change
## often. A region world calls `ArcadeStands.build(self, "<region>")` once from
## its geometry build; everything else about a stand lives here, so moving one
## is a single edit in the table below. Each stand is one merged mesh, one
## collision box, one name label and one interaction point.

const Kit := preload("res://game/world/scenery_kit.gd")
## Where each stand is and where the visitor stands to play: region -> rows.
## `stand` is the centre of the booth on the ground; `point` must be walkable and
## sits to one side, so the visitor does not hide the counter.
const STANDS := {
	"toy": [
		{"id": "game-061", "title": "發條衝刺", "prompt": "發條衝刺 · 連打上發條",
			"stand": Vector3(-2.9, 0.2, 1.0), "point": Vector3(-1.95, 0.2, 2.45), "prop": "windup", "paint": Color("#ad6356")},
		{"id": "game-062", "title": "整點咕咕", "prompt": "整點咕咕 · 數滴答開門",
			"stand": Vector3(-2.4, 0.2, -5.2), "point": Vector3(-1.3, 0.2, -3.75), "prop": "cuckoo", "paint": Color("#567f77")},
		{"id": "game-063", "title": "磁鐵搬家", "prompt": "磁鐵搬家 · 吸起鐵皮玩具",
			"stand": Vector3(10.5, 0.2, 6.2), "point": Vector3(9.4, 0.2, 7.55), "prop": "magnet", "paint": Color("#b5553c")},
		{"id": "game-064", "title": "積木拱橋", "prompt": "積木拱橋 · 看準了放下積木",
			"stand": Vector3(7.6, 0.2, 6.1), "point": Vector3(6.35, 0.2, 7.5), "prop": "bridge", "paint": Color("#4f8f86")},
		{"id": "game-065", "title": "彈簧青蛙", "prompt": "彈簧青蛙 · 按住上發條跳積木",
			"stand": Vector3(-6.2, 0.2, -2.5), "point": Vector3(-7.15, 0.2, -1.05), "prop": "frog", "paint": Color("#5f7d4a")},
		{"id": "game-066", "title": "軌道換軌", "prompt": "軌道換軌 · 扳道岔送火車回站",
			"stand": Vector3(2.9, 0.2, -6.4), "point": Vector3(1.85, 0.2, -5.0), "prop": "rails", "paint": Color("#4f79a8")},
		{"id": "game-067", "title": "木偶牽線", "prompt": "木偶牽線 · 跟著拍子拉線",
			"stand": Vector3(3.3, 0.2, 2.4), "point": Vector3(2.3, 0.2, 3.8), "prop": "puppet", "paint": Color("#7a2a3c")},
		{"id": "game-068", "title": "陀螺相撲", "prompt": "陀螺相撲 · 方向鍵撞陀螺",
			"stand": Vector3(-7.3, 0.2, 5.7), "point": Vector3(-6.15, 0.2, 6.85), "prop": "tops", "paint": Color("#8a4a3e")},
		{"id": "game-069", "title": "骰塔改道", "prompt": "骰塔改道 · 傾斜骰塔送骰子進杯",
			"stand": Vector3(-5.6, 0.2, -5.6), "point": Vector3(-4.4, 0.2, -4.3), "prop": "dice", "paint": Color("#3f6f5a")},
		{"id": "game-070", "title": "敲敲玩具兵", "prompt": "敲敲玩具兵 · 方向鍵敲回去",
			"stand": Vector3(-6.0, 0.2, 1.6), "point": Vector3(-4.95, 0.2, 3.0), "prop": "soldier", "paint": Color("#5b6f9a")},
		{"id": "game-071", "title": "紙盒變車", "prompt": "紙盒變車 · 空中扶正紙箱車",
			"stand": Vector3(-2.6, 0.2, 7.9), "point": Vector3(-1.5, 0.2, 6.6), "prop": "kart", "paint": Color("#c99a62")},
		{"id": "game-072", "title": "音盒補拍", "prompt": "音盒補拍 · 針孔到音梳時按下",
			"stand": Vector3(2.6, 0.2, 7.9), "point": Vector3(1.5, 0.2, 6.6), "prop": "musicbox", "paint": Color("#6e4630")},
	],
	"garden": [
		{"id": "game-073", "title": "螢火蟲長曝光", "prompt": "螢火蟲長曝光 · 忍住別按",
			"stand": Vector3(-9.6, 0.2, 5.6), "point": Vector3(-8.5, 0.2, 6.9), "prop": "camera", "paint": Color("#38534e")},
		{"id": "game-074", "title": "露珠牽橋", "prompt": "露珠牽橋 · 傾斜葉子滾露珠",
			"stand": Vector3(-6.6, 0.2, 6.2), "point": Vector3(-5.5, 0.2, 7.5), "prop": "dew", "paint": Color("#4f7f5a")},
		{"id": "game-075", "title": "藤蔓編路", "prompt": "藤蔓編路 · 引導藤蔓穿棚架",
			"stand": Vector3(8.2, 0.2, -10.6), "point": Vector3(7.1, 0.2, -9.3), "prop": "vine", "paint": Color("#5a7a3a")},
		{"id": "game-076", "title": "蒲公英落郵", "prompt": "蒲公英落郵 · 按住往上飄去投信",
			"stand": Vector3(-7.0, 0.2, -6.6), "point": Vector3(-5.6, 0.2, -5.4), "prop": "post", "paint": Color("#b5553c")},
		{"id": "game-077", "title": "睡蓮踏浪", "prompt": "睡蓮踏浪 · 踩葉過池",
			"stand": Vector3(-2.6, 0.2, -7.7), "point": Vector3(-1.55, 0.2, -6.35), "prop": "lily", "paint": Color("#3f6f5a")},
		{"id": "game-078", "title": "蜂巢調音", "prompt": "蜂巢調音 · 繞到後面趕蜂回巢",
			"stand": Vector3(5.95, 1.12, -7.1), "point": Vector3(6.1, 1.12, -5.8), "prop": "bee", "paint": Color("#b07a2a")},
		{"id": "game-079", "title": "蘑菇撐傘", "prompt": "蘑菇撐傘 · 替幼苗接雨",
			"stand": Vector3(7.0, 0.2, 6.0), "point": Vector3(5.85, 0.2, 7.35), "prop": "mushroom", "paint": Color("#8a4a3a")},
		{"id": "game-080", "title": "螢火蟲對暗號", "prompt": "螢火蟲對暗號 · 照閃光按回去",
			"stand": Vector3(2.6, 0.2, -7.7), "point": Vector3(1.55, 0.2, -6.35), "prop": "code", "paint": Color("#3a3f5c")},
		{"id": "game-081", "title": "根系蓄水", "prompt": "根系蓄水 · 按住澆到刻線",
			"stand": Vector3(8.45, 0.86, -3.1), "point": Vector3(7.75, 0.86, -1.95), "prop": "roots", "paint": Color("#4f7f6a")},
		{"id": "game-082", "title": "葉舟搬家", "prompt": "葉舟搬家 · 左右划槳載螞蟻",
			"stand": Vector3(8.45, 1.12, -7.0), "point": Vector3(8.1, 1.12, -5.6), "prop": "leafboat", "paint": Color("#3f7f8a")},
		{"id": "game-083", "title": "花粉拓印", "prompt": "花粉拓印 · 看準時機蓋印章",
			"stand": Vector3(-9.6, 0.2, -10.0), "point": Vector3(-8.3, 0.2, -8.9), "prop": "stamp", "paint": Color("#a8486a")},
	],
	# Hotel stands use the kept sites in hotel_world.STAND_SITES (stand and point copied).
	"hotel": [
		{"id": "game-085", "title": "折頁走廊", "prompt": "折頁走廊 · 書頁闔上時跳起來",
			"stand": Vector3(-3.6, 0.2, 4.6), "point": Vector3(-2.65, 0.2, 5.95), "prop": "book", "paint": Color("#5b3f74")},
		{"id": "game-086", "title": "被單滑梯", "prompt": "被單滑梯 · 左右傾身撿枕頭",
			"stand": Vector3(10.8, 0.2, 3.6), "point": Vector3(11.75, 0.2, 4.95), "prop": "slide", "paint": Color("#7a5aa8")},
		{"id": "game-087", "title": "回聲鑰匙", "prompt": "回聲鑰匙 · 缺口對準時轉鑰匙",
			"stand": Vector3(-14.6, 0.2, 4.4), "point": Vector3(-13.65, 0.2, 5.75), "prop": "lock", "paint": Color("#6a4058")},
		{"id": "game-088", "title": "夢泡搬運", "prompt": "夢泡搬運 · 頂著泡泡慢慢走",
			"stand": Vector3(14.8, 0.2, 3.6), "point": Vector3(15.75, 0.2, 4.95), "prop": "bubble", "paint": Color("#4f6f9a")},
		{"id": "game-089", "title": "鬼影擦窗", "prompt": "鬼影擦窗 · 把小鬼擦出來",
			"stand": Vector3(3.6, 0.2, 3.4), "point": Vector3(4.55, 0.2, 4.75), "prop": "window", "paint": Color("#4f8f86")},
		{"id": "game-090", "title": "電梯借重", "prompt": "電梯借重 · 剎車停在樓層",
			"stand": Vector3(-11.0, 0.2, 5.6), "point": Vector3(-10.05, 0.2, 6.95), "prop": "lift", "paint": Color("#8a6030")},
		{"id": "game-091", "title": "枕頭靜步", "prompt": "枕頭靜步 · 打呼時才能走",
			"stand": Vector3(12.8, 0.2, 7.0), "point": Vector3(13.75, 0.2, 8.35), "prop": "sleeper", "paint": Color("#c0485e")},
		{"id": "game-092", "title": "窗簾星圖", "prompt": "窗簾星圖 · 數真的羊",
			"stand": Vector3(7.4, 0.2, 3.4), "point": Vector3(8.35, 0.2, 4.75), "prop": "sheep", "paint": Color("#3e4380")},
	],
	# Sky stands use the kept sites in sky_world.STAND_SITES (stand and point copied).
	"sky": [
		{"id": "game-097", "title": "雲梯換層", "prompt": "雲梯換層 · 一樣高時跳過去",
			"stand": Vector3(-12.6, 0.75, -6.0), "point": Vector3(-11.65, 0.75, -4.65), "prop": "cloudhop", "paint": Color("#5a8ac0")},
		{"id": "game-103", "title": "羽球上升流", "prompt": "羽球上升流 · 左右跑接羽球",
			"stand": Vector3(-12.4, 1.85, 14.4), "point": Vector3(-11.45, 1.85, 15.75), "prop": "shuttle", "paint": Color("#3d6fb0")},
		{"id": "game-098", "title": "紙翼穿峽", "prompt": "紙翼穿峽 · 左右傾斜穿峽口",
			"stand": Vector3(-16.4, 1.85, 11.4), "point": Vector3(-15.45, 1.85, 12.75), "prop": "paperwing", "paint": Color("#c05a52")},
		{"id": "game-104", "title": "繩橋共振", "prompt": "繩橋共振 · 跟著拍子左右踩",
			"stand": Vector3(0.6, 1.80, 5.8), "point": Vector3(1.55, 1.80, 7.15), "prop": "ropebridge", "paint": Color("#6e4c32")},
		{"id": "game-105", "title": "風箏追風", "prompt": "風箏追風 · 跟著箭頭拉風箏",
			"stand": Vector3(-7.6, 1.85, 12.0), "point": Vector3(-6.65, 1.85, 13.35), "prop": "windkite", "paint": Color("#ff8a6b")},
		{"id": "game-106", "title": "落星接網", "prompt": "落星接網 · 左右跑接星星",
			"stand": Vector3(7.0, 2.35, 11.4), "point": Vector3(7.95, 2.35, 12.75), "prop": "starnet", "paint": Color("#3a2f6e")},
		{"id": "game-107", "title": "雲影快門", "prompt": "雲影快門 · 雲變對形狀時拍",
			"stand": Vector3(14.0, 2.35, 11.6), "point": Vector3(14.95, 2.35, 12.95), "prop": "cloudcam", "paint": Color("#5b7bb0")},
		{"id": "game-099", "title": "氣壓彈射", "prompt": "氣壓彈射 · 指針到綠區放手",
			"stand": Vector3(3.0, 0.20, -8.4), "point": Vector3(3.95, 0.20, -7.05), "prop": "pump", "paint": Color("#d2554a")},
	],
}
const FOOTPRINT := Vector3(1.5, 2.0, 1.0)
const DARK := Color("#343b42")
const BRASS := Color("#d9a64e")
const CREAM := Color("#ffe9c2")
const TIMBER := Color("#6b5137")


static func rows(region: String) -> Array:
	return STANDS.get(region, [])


static func build(world: Node3D, region: String) -> void:
	for row: Dictionary in rows(region):
		var at: Vector3 = row.stand
		var sculpt := Kit.Sculpt.new()
		sculpt.frame = Transform3D(Basis.IDENTITY, at)
		_booth(sculpt, row.paint)
		match str(row.prop):
			"windup": _windup_prop(sculpt)
			"cuckoo": _cuckoo_prop(sculpt)
			"frog": _frog_prop(sculpt)
			"tops": _tops_prop(sculpt)
			"soldier": _soldier_prop(sculpt)
			"magnet": _magnet_prop(sculpt)
			"bridge": _bridge_prop(sculpt)
			"rails": _rails_prop(sculpt)
			"puppet": _puppet_prop(sculpt)
			"dice": _dice_prop(sculpt)
			"kart": _kart_prop(sculpt)
			"musicbox": _musicbox_prop(sculpt)
			"camera": _camera_prop(sculpt)
			"lily": _lily_prop(sculpt)
			"mushroom": _mushroom_prop(sculpt)
			"code": _code_prop(sculpt)
			"dew": _dew_prop(sculpt)
			"vine": _vine_prop(sculpt)
			"post": _post_prop(sculpt)
			"bee": _bee_prop(sculpt)
			"roots": _roots_prop(sculpt)
			"leafboat": _leafboat_prop(sculpt)
			"stamp": _stamp_prop(sculpt)
			"book": _book_prop(sculpt)
			"sheep": _sheep_prop(sculpt)
			"sleeper": _sleeper_prop(sculpt)
			"lift": _lift_prop(sculpt)
			"window": _window_prop(sculpt)
			"bubble": _bubble_prop(sculpt)
			"shuttle": _shuttle_prop(sculpt)
			"ropebridge": _rope_bridge_prop(sculpt)
			"windkite": _wind_kite_prop(sculpt)
			"starnet": _star_net_prop(sculpt)
			"cloudcam": _cloud_camera_prop(sculpt)
			"pump": _pump_prop(sculpt)
			"lock": _lock_prop(sculpt)
			"slide": _slide_prop(sculpt)
			"cloudhop": _cloudhop_prop(sculpt)
			"paperwing": _paper_wing_prop(sculpt)
		var stand: MeshInstance3D = world._mesh(sculpt.mesh(), Vector3.ZERO, world._vertex_color_material("arcade-stand"))
		stand.name = "ArcadeStand_" + str(row.id)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = FOOTPRINT
		shape.shape = box
		body.position = at + Vector3(0, FOOTPRINT.y * 0.5, 0)
		body.add_child(shape)
		stand.add_child(body)
		world._local_label(str(row.title), at + Vector3(0, 2.16, -0.2), 26, CREAM).pixel_size = 0.0125
		world._point(str(row.id), str(row.prompt), row.point)


## The booth every arcade stand shares: plinth, striped counter, two posts and a sign board.
static func _booth(sculpt: Kit.Sculpt, paint: Color) -> void:
	sculpt.box(Vector3(0, 0.09, 0), Vector3(1.5, 0.18, 1.0), DARK)
	sculpt.box(Vector3(0, 0.53, 0), Vector3(1.3, 0.7, 0.8), paint)
	for stripe in 3:
		sculpt.box(Vector3(-0.42 + stripe * 0.42, 0.53, 0.405), Vector3(0.2, 0.62, 0.02), CREAM)
	sculpt.box(Vector3(0, 0.92, 0), Vector3(1.42, 0.08, 0.92), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.62, 1.5, -0.34), Vector3(0.1, 1.1, 0.1), TIMBER)
	sculpt.box(Vector3(0, 2.16, -0.3), Vector3(1.9, 0.44, 0.1), DARK)
	sculpt.box(Vector3(0, 1.92, -0.25), Vector3(1.9, 0.05, 0.05), BRASS)


## A butterfly key on the roof and a tin cat waiting on its race mat.
static func _windup_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.box(Vector3(0, 2.52, -0.3), Vector3(0.1, 0.3, 0.1), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.3), 0.2, 0.2, 0.09, BRASS, 8, facing)
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.25), 0.09, 0.09, 0.03, DARK, 6, facing)
	sculpt.box(Vector3(0, 0.97, 0.08), Vector3(1.2, 0.02, 0.5), Color("#2f5d62"))
	var coral := Color("#ff7f6a")
	sculpt.box(Vector3(-0.28, 1.15, 0.08), Vector3(0.4, 0.24, 0.24), coral)
	sculpt.box(Vector3(-0.1, 1.36, 0.08), Vector3(0.26, 0.22, 0.24), coral)
	for ear: float in [-0.07, 0.07]:
		sculpt.box(Vector3(-0.1 + ear, 1.5, 0.08), Vector3(0.07, 0.08, 0.2), coral)
	for wheel: float in [-0.4, -0.16]:
		sculpt.tube(Vector3(wheel, 1.04, 0.2), 0.07, 0.07, 0.04, DARK, 6, facing)
	sculpt.box(Vector3(-0.52, 1.2, 0.08), Vector3(0.08, 0.04, 0.04), BRASS)
	sculpt.box(Vector3(-0.58, 1.2, 0.08), Vector3(0.04, 0.2, 0.06), BRASS)


## A cuckoo clock on the roof with its bird halfway out, and a spare bird on the counter.
static func _cuckoo_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var wall := Color("#b9704a")
	var roof := Color("#a8473f")
	var bird := Color("#ffd166")
	sculpt.box(Vector3(0, 2.72, -0.3), Vector3(0.62, 0.68, 0.3), wall)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.2, 3.14, -0.3), Vector3(0.54, 0.09, 0.4), roof, Basis(Vector3.BACK, side * -0.6))
	sculpt.tube(Vector3(0, 2.66, -0.13), 0.19, 0.19, 0.04, CREAM, 10, facing)
	sculpt.box(Vector3(0, 2.71, -0.1), Vector3(0.03, 0.13, 0.02), DARK)
	sculpt.box(Vector3(0.05, 2.66, -0.1), Vector3(0.1, 0.03, 0.02), DARK)
	sculpt.box(Vector3(0, 2.96, -0.1), Vector3(0.16, 0.14, 0.14), bird)
	sculpt.box(Vector3(0, 2.94, -0.01), Vector3(0.06, 0.05, 0.06), Color("#e07b39"))
	sculpt.box(Vector3(0, 2.2, -0.2), Vector3(0.03, 0.34, 0.03), BRASS)
	sculpt.tube(Vector3(0, 2.02, -0.2), 0.08, 0.08, 0.04, BRASS, 8, facing)
	sculpt.box(Vector3(0.3, 1.09, 0.1), Vector3(0.24, 0.24, 0.22), bird)
	sculpt.box(Vector3(0.3, 1.08, 0.24), Vector3(0.08, 0.06, 0.08), Color("#e07b39"))
	sculpt.box(Vector3(-0.3, 1.02, 0.1), Vector3(0.36, 0.12, 0.3), wall)


## A camera on a tripod above the sign, and a jar of fireflies on the counter.
static func _camera_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	for lean: float in [-1.0, 0.0, 1.0]:
		sculpt.box(Vector3(lean * 0.16, 2.6, -0.3 + absf(lean) * 0.06 - 0.06), Vector3(0.04, 0.5, 0.04), TIMBER, Basis(Vector3.BACK, lean * 0.32))
	sculpt.box(Vector3(0, 3.0, -0.3), Vector3(0.5, 0.32, 0.26), DARK)
	sculpt.box(Vector3(0, 3.19, -0.3), Vector3(0.52, 0.06, 0.28), Color("#8a8494"))
	sculpt.tube(Vector3(0, 3.0, -0.12), 0.13, 0.11, 0.14, BRASS, 8, facing)
	sculpt.tube(Vector3(0, 3.0, -0.04), 0.08, 0.08, 0.02, Color("#16303a"), 8, facing)
	sculpt.box(Vector3(0.17, 3.24, -0.3), Vector3(0.08, 0.05, 0.08), Color("#6fd39a"))
	sculpt.tube(Vector3(-0.28, 1.14, 0.1), 0.15, 0.15, 0.34, Color("#9fc9b4"), 8)
	sculpt.tube(Vector3(-0.28, 1.33, 0.1), 0.12, 0.12, 0.05, TIMBER, 8)
	for fly: Vector3 in [Vector3(-0.31, 1.1, 0.26), Vector3(-0.23, 1.2, 0.26), Vector3(-0.3, 1.24, 0.25)]:
		sculpt.box(fly, Vector3(0.035, 0.035, 0.02), Color("#dcff8a"))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A lily pad with a frog on the roof, and a little pond basin of pads on the counter.
static func _lily_prop(sculpt: Kit.Sculpt) -> void:
	var leaf := Color("#5c9c62")
	sculpt.tube(Vector3(0, 2.44, -0.3), 0.46, 0.46, 0.05, leaf, 12)
	sculpt.box(Vector3(0.3, 2.47, -0.12), Vector3(0.22, 0.02, 0.1), Color("#3f7f52"), Basis(Vector3.UP, -0.5))
	var frog := Color("#7cb85a")
	sculpt.box(Vector3(-0.08, 2.6, -0.3), Vector3(0.26, 0.2, 0.22), frog)
	for eye: float in [-0.16, 0.0]:
		sculpt.box(Vector3(eye, 2.73, -0.2), Vector3(0.08, 0.08, 0.06), CREAM)
		sculpt.box(Vector3(eye, 2.73, -0.16), Vector3(0.04, 0.04, 0.02), DARK)
	sculpt.tube(Vector3(-0.15, 1.0, 0.1), 0.42, 0.4, 0.12, Color("#9aa59a"), 10)
	sculpt.tube(Vector3(-0.15, 1.05, 0.1), 0.36, 0.36, 0.04, Color("#2c6a66"), 10)
	for pad: Vector3 in [Vector3(-0.3, 1.08, 0.05), Vector3(-0.02, 1.08, 0.2), Vector3(-0.2, 1.08, 0.28)]:
		sculpt.tube(pad, 0.1, 0.1, 0.02, leaf, 8)
	sculpt.box(Vector3(-0.02, 1.11, 0.2), Vector3(0.06, 0.05, 0.06), Color("#f2a7b8"))
	sculpt.box(Vector3(0.38, 1.0, 0.1), Vector3(0.3, 0.06, 0.26), CREAM)


## A spotted mushroom umbrella over the sign, and a seedling in a clay pot on the counter.
static func _mushroom_prop(sculpt: Kit.Sculpt) -> void:
	var cap := Color("#c8483e")
	var spot := Color("#fff2dc")
	sculpt.box(Vector3(0, 2.62, -0.3), Vector3(0.08, 0.36, 0.08), Color("#efe2c4"))
	sculpt.tube(Vector3(0, 2.84, -0.3), 0.62, 0.5, 0.14, cap, 12)
	sculpt.tube(Vector3(0, 3.02, -0.3), 0.48, 0.18, 0.22, cap, 12)
	for dot: Vector3 in [Vector3(-0.3, 2.98, -0.06), Vector3(0.18, 3.06, -0.12), Vector3(0.42, 2.92, -0.14), Vector3(-0.08, 3.14, -0.2)]:
		sculpt.box(dot, Vector3(0.1, 0.06, 0.06), spot)
	sculpt.tube(Vector3(-0.3, 1.06, 0.1), 0.14, 0.11, 0.22, Color("#b8643f"), 8)
	sculpt.tube(Vector3(-0.3, 1.18, 0.1), 0.12, 0.12, 0.02, Color("#4f3f2e"), 8)
	sculpt.box(Vector3(-0.3, 1.3, 0.1), Vector3(0.03, 0.22, 0.03), Color("#5c9c62"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.3 + side * 0.07, 1.4, 0.1), Vector3(0.12, 0.03, 0.07), Color("#6fae5c"), Basis(Vector3.BACK, side * 0.3))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## Four little paper lanterns hung under the sign, each with a firefly glow
## (kept below the greenhouse ribs so they stay in view), and a stone lantern
## on the counter.
static func _code_prop(sculpt: Kit.Sculpt) -> void:
	var paper := Color("#f1e2bc")
	var glow := Color("#dcff8a")
	for lantern: Vector3 in [Vector3(-0.42, 1.62, -0.12), Vector3(-0.14, 1.56, -0.12), Vector3(0.14, 1.62, -0.12), Vector3(0.42, 1.56, -0.12)]:
		sculpt.box(lantern + Vector3(0, (1.9 - lantern.y) * 0.5 + 0.06, 0), Vector3(0.02, 1.9 - lantern.y - 0.12, 0.02), DARK)
		sculpt.tube(lantern, 0.1, 0.1, 0.2, paper, 8)
		sculpt.tube(lantern + Vector3(0, 0.12, 0), 0.06, 0.1, 0.04, TIMBER, 8)
		sculpt.box(lantern + Vector3(0, 0, 0.1), Vector3(0.07, 0.07, 0.02), glow)
	var stone := Color("#8f9488")
	sculpt.box(Vector3(-0.3, 1.0, 0.1), Vector3(0.22, 0.06, 0.22), stone)
	sculpt.box(Vector3(-0.3, 1.12, 0.1), Vector3(0.08, 0.18, 0.08), stone)
	sculpt.box(Vector3(-0.3, 1.27, 0.1), Vector3(0.18, 0.12, 0.18), stone.darkened(0.1))
	sculpt.box(Vector3(-0.3, 1.27, 0.2), Vector3(0.08, 0.06, 0.02), Color("#ffe7a0"))
	sculpt.tube(Vector3(-0.3, 1.37, 0.1), 0.16, 0.02, 0.1, stone, 6)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A tin frog crouched on a little belt of letter blocks, with its butterfly key, and a big key on the roof.
static func _frog_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	var tin := Color("#7fa25a")
	sculpt.box(Vector3(0, 0.99, 0.08), Vector3(1.24, 0.06, 0.36), Color("#3b3135"))
	for roller: float in [-0.56, 0.56]:
		sculpt.tube(Vector3(roller, 0.99, 0.08), 0.05, 0.05, 0.38, DARK, 8, Basis(Vector3.BACK, PI * 0.5))
	for block: Array in [[-0.36, Color("#ad573f")], [0.02, Color("#c4904a")], [0.38, Color("#5b8f80")]]:
		sculpt.box(Vector3(block[0], 1.12, 0.08), Vector3(0.22, 0.2, 0.22), block[1])
		sculpt.box(Vector3(block[0], 1.12, 0.195), Vector3(0.12, 0.12, 0.01), CREAM)
	sculpt.box(Vector3(0.02, 1.32, 0.08), Vector3(0.3, 0.17, 0.22), tin)
	sculpt.box(Vector3(0.16, 1.41, 0.08), Vector3(0.14, 0.12, 0.18), tin)
	for eye: float in [-0.06, 0.06]:
		sculpt.box(Vector3(0.18, 1.49, 0.08 + eye), Vector3(0.06, 0.06, 0.05), CREAM)
	sculpt.box(Vector3(-0.15, 1.45, 0.08), Vector3(0.03, 0.12, 0.03), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(-0.15, 1.53, 0.08 + side * 0.06), 0.05, 0.05, 0.02, BRASS, 6, facing)
	sculpt.box(Vector3(0, 2.52, -0.3), Vector3(0.1, 0.3, 0.1), BRASS)
	for side: float in [-1.0, 1.0]:
		sculpt.tube(Vector3(side * 0.2, 2.8, -0.3), 0.2, 0.2, 0.09, tin, 8, facing)


## A tin dish ringed with straw rope and two tops squaring up on the counter, and a big top on the roof.
static func _tops_prop(sculpt: Kit.Sculpt) -> void:
	sculpt.tube(Vector3(0, 0.98, 0.08), 0.5, 0.52, 0.05, Color("#8c7f74"), 16)
	sculpt.tube(Vector3(0, 1.02, 0.08), 0.46, 0.46, 0.04, Color("#c9a35c"), 16)
	sculpt.tube(Vector3(0, 1.0, 0.08), 0.4, 0.4, 0.03, Color("#7d7068"), 16)
	for top: Array in [[-0.17, Color("#b8483a")], [0.19, Color("#4f8a7e")]]:
		var at := Vector3(top[0], 1.0, 0.08)
		sculpt.tube(at + Vector3(0, 0.06, 0), 0.02, 0.09, 0.12, Color("#8f8a86"), 8)
		sculpt.tube(at + Vector3(0, 0.17, 0), 0.13, 0.13, 0.1, top[1], 10)
		sculpt.tube(at + Vector3(0, 0.23, 0), 0.1, 0.06, 0.04, BRASS, 8)
		sculpt.tube(at + Vector3(0, 0.29, 0), 0.025, 0.025, 0.08, TIMBER, 6)
	sculpt.tube(Vector3(0, 2.5, -0.3), 0.03, 0.12, 0.2, Color("#8f8a86"), 8)
	sculpt.tube(Vector3(0, 2.72, -0.3), 0.3, 0.3, 0.22, Color("#b8483a"), 12)
	sculpt.tube(Vector3(0, 2.72, -0.3), 0.31, 0.31, 0.06, CREAM, 12)
	sculpt.tube(Vector3(0, 2.9, -0.3), 0.2, 0.08, 0.1, BRASS, 10)
	sculpt.tube(Vector3(0, 3.02, -0.3), 0.04, 0.04, 0.14, TIMBER, 6)


## A striped sentry box with a toy soldier popping out and a mallet on the counter, and a big mallet on the roof.
static func _soldier_prop(sculpt: Kit.Sculpt) -> void:
	var red := Color("#b8483a")
	sculpt.box(Vector3(-0.22, 1.26, 0.0), Vector3(0.44, 0.6, 0.4), CREAM)
	for stripe: float in [-0.36, -0.22, -0.08]:
		sculpt.box(Vector3(stripe, 1.26, 0.205), Vector3(0.06, 0.6, 0.01), red)
	sculpt.box(Vector3(-0.22, 1.62, 0.0), Vector3(0.52, 0.08, 0.48), Color("#5b6f9a"))
	sculpt.box(Vector3(-0.22, 1.28, 0.21), Vector3(0.22, 0.34, 0.01), DARK)
	sculpt.box(Vector3(-0.22, 1.38, 0.26), Vector3(0.14, 0.12, 0.1), Color("#ebb894"))
	sculpt.box(Vector3(-0.22, 1.52, 0.26), Vector3(0.16, 0.2, 0.12), Color("#2f2838"))
	sculpt.box(Vector3(-0.22, 1.18, 0.26), Vector3(0.18, 0.14, 0.1), red)
	sculpt.box(Vector3(0.3, 1.02, 0.12), Vector3(0.4, 0.04, 0.04), TIMBER, Basis(Vector3.UP, 0.4))
	sculpt.tube(Vector3(0.45, 1.06, 0.2), 0.08, 0.08, 0.2, Color("#c8a676"), 8, Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, 0.4))
	sculpt.box(Vector3(0, 2.5, -0.3), Vector3(0.06, 0.4, 0.06), TIMBER, Basis(Vector3.BACK, 0.5))
	sculpt.tube(Vector3(-0.12, 2.72, -0.3), 0.13, 0.13, 0.36, Color("#c8a676"), 10, Basis(Vector3.BACK, PI * 0.5 + 0.5))
	for band: float in [-0.14, 0.14]:
		sculpt.tube(Vector3(-0.12, 2.72, -0.3) + Vector3(band, 0, 0).rotated(Vector3.BACK, 0.5), 0.14, 0.14, 0.05, red, 10, Basis(Vector3.BACK, PI * 0.5 + 0.5))


## A little jib crane on the roof lifting a tin robot with a red horseshoe
## magnet, and a toy crate with a wooden duck waiting on the counter.
static func _magnet_prop(sculpt: Kit.Sculpt) -> void:
	var red := Color("#c8423a")
	var steel := Color("#c3c8cf")
	var tin := Color("#a9b0b8")
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.55, 2.8, -0.3), Vector3(0.08, 0.84, 0.08), TIMBER)
	sculpt.box(Vector3(0.18, 3.2, -0.3), Vector3(0.82, 0.07, 0.07), Color("#b5553c"))
	sculpt.box(Vector3(0.36, 3.02, -0.3), Vector3(0.04, 0.4, 0.04), Color("#b5553c"), Basis(Vector3.BACK, -0.8))
	sculpt.box(Vector3(-0.15, 3.1, -0.3), Vector3(0.02, 0.18, 0.02), DARK)
	sculpt.box(Vector3(-0.15, 2.97, -0.3), Vector3(0.34, 0.09, 0.12), red)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.15 + side * 0.12, 2.85, -0.3), Vector3(0.1, 0.16, 0.12), red)
		sculpt.box(Vector3(-0.15 + side * 0.12, 2.74, -0.3), Vector3(0.1, 0.06, 0.12), steel)
	sculpt.box(Vector3(-0.15, 2.62, -0.3), Vector3(0.12, 0.09, 0.1), tin)
	sculpt.box(Vector3(-0.15, 2.5, -0.3), Vector3(0.16, 0.14, 0.11), tin)
	sculpt.box(Vector3(-0.15, 2.51, -0.24), Vector3(0.04, 0.04, 0.01), red)
	for eye: float in [-0.03, 0.03]:
		sculpt.box(Vector3(-0.15 + eye, 2.63, -0.245), Vector3(0.02, 0.02, 0.01), DARK)
	sculpt.box(Vector3(-0.3, 1.1, 0.1), Vector3(0.4, 0.24, 0.3), pine)
	sculpt.box(Vector3(-0.3, 1.22, 0.1), Vector3(0.42, 0.03, 0.32), pine.darkened(0.25))
	sculpt.box(Vector3(-0.3, 1.1, 0.26), Vector3(0.18, 0.1, 0.01), CREAM)
	sculpt.box(Vector3(0.3, 1.05, 0.1), Vector3(0.22, 0.12, 0.14), Color("#e8b84a"))
	sculpt.box(Vector3(0.21, 1.15, 0.1), Vector3(0.09, 0.09, 0.09), Color("#e8b84a"))
	sculpt.box(Vector3(0.15, 1.14, 0.1), Vector3(0.05, 0.03, 0.04), Color("#e0773c"))
	for wheel: float in [0.22, 0.38]:
		sculpt.tube(Vector3(wheel, 0.99, 0.18), 0.03, 0.03, 0.02, DARK, 6, Basis(Vector3.RIGHT, PI * 0.5))


## A stack of painted blocks swinging from a rope on the roof, and a little
## wooden arch bridge with a toy engine on the counter.
static func _bridge_prop(sculpt: Kit.Sculpt) -> void:
	var paints: Array[Color] = [Color("#c0503f"), Color("#e0b04a"), Color("#4f79a8")]
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.0, 3.25, -0.3), Vector3(0.9, 0.06, 0.06), TIMBER)
	sculpt.box(Vector3(0.42, 2.82, -0.3), Vector3(0.06, 0.86, 0.06), TIMBER)
	sculpt.box(Vector3(-0.12, 3.05, -0.3), Vector3(0.02, 0.4, 0.02), CREAM, Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(-0.17, 2.82, -0.3), Vector3(0.36, 0.14, 0.2), paints[0], Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(-0.42, 2.48, -0.3), Vector3(0.28, 0.14, 0.2), paints[1])
	sculpt.box(Vector3(-0.42, 2.62, -0.3), Vector3(0.24, 0.14, 0.2), paints[2])
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.34, 1.06, 0.1), Vector3(0.12, 0.2, 0.2), pine.darkened(0.15))
	for step in 5:
		var t := (step + 0.5) / 5.0
		var x := lerpf(-0.36, 0.36, t)
		sculpt.box(Vector3(x, 1.12 + 0.07 * sin(t * PI), 0.1), Vector3(0.16, 0.05, 0.2), pine, Basis(Vector3.BACK, -0.35 * cos(t * PI)))
	sculpt.box(Vector3(0, 1.22, 0.1), Vector3(0.82, 0.04, 0.22), pine.darkened(0.1))
	sculpt.box(Vector3(-0.08, 1.31, 0.1), Vector3(0.22, 0.12, 0.14), paints[0])
	sculpt.box(Vector3(-0.15, 1.42, 0.1), Vector3(0.06, 0.1, 0.06), Color("#4a4e57"))
	sculpt.box(Vector3(0.12, 1.3, 0.1), Vector3(0.14, 0.1, 0.14), paints[2])


## A railway signal with three coloured lamps on the roof, and a wooden toy
## track splitting three ways on the counter with a little engine at the points.
static func _rails_prop(sculpt: Kit.Sculpt) -> void:
	var lamps: Array[Color] = [Color("#c0503f"), Color("#4f79a8"), Color("#e0b04a")]
	var pine := Color("#d2a46a")
	sculpt.box(Vector3(0.0, 2.72, -0.3), Vector3(0.08, 0.68, 0.08), DARK)
	sculpt.box(Vector3(0.0, 3.0, -0.25), Vector3(0.26, 0.6, 0.1), DARK.lightened(0.15))
	for lamp in 3:
		sculpt.tube(Vector3(0.0, 3.2 - lamp * 0.19, -0.19), 0.07, 0.07, 0.03, lamps[lamp], 8, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0.24, 2.92, -0.3), Vector3(0.36, 0.06, 0.04), CREAM, Basis(Vector3.BACK, 0.5))
	sculpt.box(Vector3(-0.3, 0.98, 0.1), Vector3(0.5, 0.03, 0.12), pine)
	for branch in 3:
		var turn := (branch - 1) * 0.45
		sculpt.box(Vector3(0.15 + 0.1 * cos(turn), 0.98, 0.1 + 0.18 * sin(turn)), Vector3(0.36, 0.03, 0.12), pine.darkened(0.08), Basis(Vector3.UP, -turn))
	sculpt.box(Vector3(-0.32, 1.06, 0.1), Vector3(0.2, 0.12, 0.1), lamps[0])
	sculpt.box(Vector3(-0.25, 1.15, 0.1), Vector3(0.04, 0.08, 0.04), Color("#4a4e57"))
	sculpt.box(Vector3(-0.42, 1.09, 0.1), Vector3(0.08, 0.16, 0.1), lamps[0].darkened(0.2))


## A broad leaf tipped over the sign with a big dewdrop rolling on it and a
## caterpillar on its edge, and a potted flower bud on the counter.
static func _dew_prop(sculpt: Kit.Sculpt) -> void:
	var leaf := Color("#5f9e4f")
	var tilt := Basis(Vector3.BACK, -0.18)
	sculpt.box(Vector3(0.05, 2.55, -0.3), Vector3(0.05, 0.5, 0.05), Color("#3f6f3a"))
	sculpt.box(Vector3(0, 2.84, -0.3), Vector3(1.5, 0.05, 0.5), leaf, tilt)
	sculpt.box(Vector3(0, 2.875, -0.3), Vector3(1.4, 0.02, 0.05), Color("#b9d48a"), tilt)
	for tip: float in [-1.0, 1.0]:
		sculpt.box(Vector3(tip * 0.8, 2.84 - tip * 0.15, -0.3), Vector3(0.18, 0.05, 0.26), leaf.darkened(0.1), tilt)
	sculpt.ball(Vector3(-0.3, 3.02, -0.3), 0.15, Color("#a9e2ef"), Color("#e8fbff"), 8, 4, 0.9)
	sculpt.box(Vector3(0.45, 2.85, -0.07), Vector3(0.22, 0.06, 0.06), Color("#9ccf52"), tilt)
	sculpt.tube(Vector3(-0.3, 1.06, 0.1), 0.14, 0.11, 0.22, Color("#b8643f"), 8)
	sculpt.tube(Vector3(-0.3, 1.18, 0.1), 0.12, 0.12, 0.02, Color("#4f3f2e"), 8)
	sculpt.box(Vector3(-0.3, 1.32, 0.1), Vector3(0.03, 0.26, 0.03), Color("#3f6f3a"))
	sculpt.ball(Vector3(-0.3, 1.5, 0.1), 0.07, Color("#f2a7b8"), Color("#7cae5a"), 6, 3, 1.3)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A marionette dangling from a wooden cross on the roof, and a tiny curtained
## puppet stage on the counter.
static func _puppet_prop(sculpt: Kit.Sculpt) -> void:
	var red := Color("#c0503f")
	var blue := Color("#4f79a8")
	var pine := Color("#d2a46a")
	var velvet := Color("#7a2a3c")
	sculpt.box(Vector3(0.0, 3.3, -0.3), Vector3(0.56, 0.05, 0.06), pine)
	sculpt.box(Vector3(0.0, 3.3, -0.3), Vector3(0.06, 0.05, 0.4), pine)
	for x: float in [-0.25, 0.0, 0.25]:
		sculpt.box(Vector3(x, 3.0, -0.3), Vector3(0.012, 0.56, 0.012), CREAM)
	sculpt.box(Vector3(0.0, 2.92, -0.3), Vector3(0.12, 0.12, 0.1), pine.lightened(0.1))
	sculpt.box(Vector3(0.0, 2.99, -0.3), Vector3(0.1, 0.04, 0.1), red)
	sculpt.box(Vector3(0.0, 2.76, -0.3), Vector3(0.14, 0.18, 0.08), red)
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.13, 2.84, -0.3), Vector3(0.05, 0.16, 0.05), red, Basis(Vector3.BACK, side * 0.9))
		sculpt.box(Vector3(side * 0.04, 2.58, -0.3), Vector3(0.05, 0.18, 0.05), blue)
	sculpt.box(Vector3(0.0, 1.14, 0.0), Vector3(0.56, 0.4, 0.06), pine.darkened(0.2))
	sculpt.box(Vector3(0.0, 1.1, 0.04), Vector3(0.4, 0.28, 0.02), Color("#2c2440"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.16, 1.1, 0.06), Vector3(0.1, 0.3, 0.03), velvet)
	sculpt.box(Vector3(0.0, 1.29, 0.06), Vector3(0.46, 0.06, 0.03), velvet)
	sculpt.box(Vector3(0.0, 1.03, 0.08), Vector3(0.06, 0.1, 0.03), red)


## A little bamboo trellis over the sign with a vine winding up through its
## gaps to a pink flower, a butterfly on the top bar, and a coil of twine and a
## seedling on the counter.
static func _vine_prop(sculpt: Kit.Sculpt) -> void:
	var bamboo := Color("#c9b26a")
	var vine := Color("#4f8a3a")
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.5, 2.85, -0.3), Vector3(0.05, 0.9, 0.05), bamboo.darkened(0.1))
	for bar in 3:
		var y := 2.55 + bar * 0.28
		var gap: float = [-0.15, 0.2, -0.05][bar]
		sculpt.box(Vector3((-0.5 + gap - 0.09) * 0.5, y, -0.3), Vector3(gap + 0.41, 0.04, 0.04), bamboo)
		sculpt.box(Vector3((0.5 + gap + 0.09) * 0.5, y, -0.3), Vector3(0.41 - gap, 0.04, 0.04), bamboo)
	var points: Array[Vector3] = [Vector3(0.05, 2.4, -0.25), Vector3(-0.15, 2.55, -0.25), Vector3(0.2, 2.83, -0.25), Vector3(-0.05, 3.11, -0.25), Vector3(0.1, 3.3, -0.25)]
	for index in points.size() - 1:
		var from := points[index]
		var to := points[index + 1]
		var mid := (from + to) * 0.5
		var along := to - from
		sculpt.box(mid, Vector3(0.04, along.length(), 0.04), vine, Basis(Vector3.BACK, -atan2(along.x, along.y)))
		sculpt.box(mid + Vector3(0.06, 0, 0.02), Vector3(0.1, 0.05, 0.02), vine.lightened(0.15), Basis(Vector3.BACK, 0.6))
	sculpt.ball(Vector3(0.1, 3.36, -0.25), 0.07, Color("#f2a7b8"), Color("#ffd166"), 6, 3, 1.0)
	sculpt.box(Vector3(0.32, 3.13, -0.25), Vector3(0.12, 0.08, 0.02), Color("#ffd166"))
	sculpt.tube(Vector3(-0.3, 1.02, 0.1), 0.12, 0.12, 0.1, Color("#d9c08a"), 8)
	sculpt.tube(Vector3(-0.3, 1.08, 0.1), 0.05, 0.05, 0.03, Color("#8a7a5a"), 6)
	sculpt.tube(Vector3(0.28, 1.04, 0.1), 0.1, 0.08, 0.16, Color("#b8643f"), 8)
	sculpt.box(Vector3(0.28, 1.2, 0.1), Vector3(0.02, 0.18, 0.02), vine)
	sculpt.box(Vector3(0.32, 1.27, 0.1), Vector3(0.1, 0.03, 0.06), vine.lightened(0.15), Basis(Vector3.BACK, 0.4))


## A tall crenellated dice tower on the roof with a big die tumbling out, and a
## felt tray of little cups and dice on the counter.
static func _dice_prop(sculpt: Kit.Sculpt) -> void:
	var walnut := Color("#8a5a3a")
	var ivory := Color("#f3ead6")
	var felt := Color("#3f6f5a")
	sculpt.box(Vector3(-0.1, 2.75, -0.3), Vector3(0.34, 0.74, 0.3), walnut)
	for merlon: float in [-0.22, -0.1, 0.02]:
		sculpt.box(Vector3(merlon, 3.17, -0.3), Vector3(0.08, 0.1, 0.3), walnut.lightened(0.1))
	sculpt.box(Vector3(-0.1, 2.48, -0.14), Vector3(0.16, 0.18, 0.02), Color("#1d1420"))
	sculpt.box(Vector3(0.24, 2.5, -0.2), Vector3(0.16, 0.16, 0.16), ivory, Basis(Vector3.BACK, 0.4) * Basis(Vector3.UP, 0.5))
	sculpt.box(Vector3(0.24, 2.5, -0.115), Vector3(0.04, 0.04, 0.01), DARK, Basis(Vector3.BACK, 0.4))
	sculpt.box(Vector3(0.0, 0.99, 0.12), Vector3(0.9, 0.05, 0.32), felt)
	for cup in 3:
		sculpt.tube(Vector3(-0.3 + cup * 0.3, 1.06, 0.12), 0.07, 0.09, 0.1, Color("#d2a46a"), 8)
	for die: Vector3 in [Vector3(-0.15, 1.06, 0.22), Vector3(0.16, 1.06, 0.02)]:
		sculpt.box(die, Vector3(0.08, 0.08, 0.08), ivory, Basis(Vector3.UP, die.x * 3.0))


## A big dandelion clock on a tall stem above the sign with a letter tucked
## under it, and a little red mailbox with its flag up on the counter.
static func _post_prop(sculpt: Kit.Sculpt) -> void:
	var stem := Color("#7a9a4a")
	var seed := Color("#f6f1e2")
	var tin := Color("#c8483e")
	sculpt.box(Vector3(0.35, 2.75, -0.3), Vector3(0.04, 0.8, 0.04), stem, Basis(Vector3.BACK, -0.15))
	sculpt.ball(Vector3(0.42, 3.2, -0.3), 0.26, seed, Color("#d8d2c0"), 10, 5, 1.0)
	sculpt.ball(Vector3(0.42, 3.2, -0.3), 0.06, Color("#a89f88"), Color.TRANSPARENT, 6, 3)
	for drift in 3:
		var at := Vector3(-0.1 - drift * 0.22, 3.0 + drift * 0.12, -0.25)
		sculpt.box(at, Vector3(0.012, 0.12, 0.012), Color("#d8ccb0"))
		sculpt.ball(at + Vector3(0, 0.08, 0), 0.04, seed, Color.TRANSPARENT, 5, 2)
	sculpt.box(Vector3(0.12, 2.62, -0.24), Vector3(0.2, 0.13, 0.02), Color("#f4e6c4"), Basis(Vector3.BACK, 0.25))
	sculpt.box(Vector3(-0.28, 1.08, 0.1), Vector3(0.28, 0.16, 0.18), tin)
	sculpt.tube(Vector3(-0.28, 1.16, 0.1), 0.09, 0.09, 0.18, tin.darkened(0.1), 8, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(-0.1, 1.24, 0.12), Vector3(0.02, 0.2, 0.02), Color("#5a4a3a"))
	sculpt.box(Vector3(-0.05, 1.3, 0.12), Vector3(0.1, 0.07, 0.02), Color("#ffd166"))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A striped wooden beehive on the roof with three bees bobbing on wires
## round its door, and a pot of pink flowers on the counter.
static func _bee_prop(sculpt: Kit.Sculpt) -> void:
	var honey := Color("#e0a83a")
	var roof := Color("#c8483e")
	for box in 3:
		sculpt.box(Vector3(0, 2.5 + box * 0.17, -0.3), Vector3(0.56 - box * 0.04, 0.15, 0.4), honey.darkened(0.08 * box))
	sculpt.box(Vector3(0, 3.03, -0.3), Vector3(0.66, 0.06, 0.48), roof)
	sculpt.box(Vector3(0, 3.1, -0.3), Vector3(0.44, 0.08, 0.36), Color("#f4e6c4"))
	sculpt.box(Vector3(0, 2.5, -0.08), Vector3(0.2, 0.06, 0.02), Color("#2a1a10"))
	sculpt.box(Vector3(0, 2.44, -0.02), Vector3(0.36, 0.03, 0.14), TIMBER)
	for bee in 3:
		var at := Vector3(-0.5 + bee * 0.5, 2.75 + 0.18 * (bee % 2), 0.0)
		sculpt.box(at + Vector3(0, 0.12, 0), Vector3(0.008, 0.24, 0.008), Color("#5a4a3a"))
		sculpt.ball(at, 0.07, honey, Color("#2a2020"), 6, 3, 1.3)
		sculpt.box(at + Vector3(0, 0.0, 0), Vector3(0.03, 0.12, 0.15), Color("#2a2020"))
		sculpt.box(at + Vector3(0, 0.07, -0.03), Vector3(0.1, 0.02, 0.06), Color("#e8f4ff"))
	sculpt.tube(Vector3(0.3, 1.06, 0.1), 0.12, 0.09, 0.16, Color("#b5553c"), 8)
	for bloom in 4:
		var at := Vector3(0.22 + (bloom % 2) * 0.16, 1.24 + floorf(bloom * 0.5) * 0.08, 0.06 + (bloom % 3) * 0.04)
		sculpt.ball(at, 0.06, Color("#f2a7b8"), Color("#ffd166"), 6, 3)
	sculpt.box(Vector3(-0.3, 1.0, 0.1), Vector3(0.36, 0.06, 0.26), CREAM)


## A big green watering can tipped over a seedling pot on the roof, a stream
## of drops between them, and three little pots with sprouts on the counter.
static func _roots_prop(sculpt: Kit.Sculpt) -> void:
	var can := Color("#4f8f6a")
	var clay := Color("#c0673f")
	var leaf := Color("#6fb04f")
	var tip := Basis(Vector3.BACK, 0.45)
	sculpt.tube(Vector3(-0.3, 2.78, -0.3), 0.2, 0.2, 0.34, can, 10, tip * Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(-0.38, 3.0, -0.3), Vector3(0.05, 0.22, 0.05), can.darkened(0.2), tip)
	sculpt.box(Vector3(0.0, 2.88, -0.3), Vector3(0.36, 0.05, 0.05), can.darkened(0.1), Basis(Vector3.BACK, -0.35))
	sculpt.box(Vector3(0.2, 2.8, -0.3), Vector3(0.09, 0.12, 0.12), Color("#c9b26a"))
	for drop in 3:
		sculpt.box(Vector3(0.3 + drop * 0.03, 2.66 - drop * 0.11, -0.3), Vector3(0.035, 0.06, 0.035), Color("#8fd0f0"))
	sculpt.tube(Vector3(0.4, 2.42, -0.3), 0.14, 0.11, 0.16, clay, 8)
	sculpt.ball(Vector3(0.4, 2.55, -0.3), 0.07, leaf, Color.TRANSPARENT, 6, 3, 0.6)
	for pot in 3:
		var at := Vector3(-0.42 + pot * 0.34, 1.02, 0.12)
		sculpt.tube(at, 0.09, 0.07, 0.14, clay.darkened(0.06 * pot), 8)
		sculpt.box(at + Vector3(0, 0.12, 0), Vector3(0.02, 0.1, 0.02), leaf.darkened(0.2))
		for side: float in [-1.0, 1.0]:
			sculpt.ball(at + Vector3(side * 0.04, 0.17, 0), 0.035, leaf, Color.TRANSPARENT, 5, 2, 0.6)


## A curled green leaf boat with a little paddle across it on the roof, a
## blue ribbon of stream under it, and a pink petal with ants on the counter.
static func _leafboat_prop(sculpt: Kit.Sculpt) -> void:
	var leaf := Color("#5fa04a")
	sculpt.box(Vector3(0, 2.44, -0.3), Vector3(1.2, 0.04, 0.4), Color("#3f8fa8"))
	sculpt.ball(Vector3(0, 2.6, -0.3), 0.42, leaf, leaf.lightened(0.2), 10, 4, 0.35)
	sculpt.box(Vector3(0, 2.68, -0.3), Vector3(0.72, 0.03, 0.03), leaf.darkened(0.3))
	sculpt.box(Vector3(0.05, 2.8, -0.28), Vector3(0.7, 0.04, 0.04), Color("#8a6640"), Basis(Vector3.BACK, 0.35))
	sculpt.box(Vector3(0.36, 2.92, -0.28), Vector3(0.16, 0.1, 0.03), Color("#b5884e"), Basis(Vector3.BACK, 0.35))
	for ant in 3:
		sculpt.ball(Vector3(-0.22 + ant * 0.16, 2.72, -0.12), 0.035, Color("#2a2020"), Color.TRANSPARENT, 5, 2)
	sculpt.ball(Vector3(0.28, 1.0, 0.12), 0.15, Color("#f2a7b8"), Color("#ffd166"), 8, 3, 0.3)
	for ant in 2:
		sculpt.ball(Vector3(0.22 + ant * 0.12, 1.06, 0.12), 0.03, Color("#2a2020"), Color.TRANSPARENT, 5, 2)
	sculpt.box(Vector3(-0.3, 1.0, 0.1), Vector3(0.34, 0.06, 0.26), CREAM)


## A big wooden flower stamp hanging from a little gallows arm on the roof,
## a pink flower printed on a sheet below it, and ink jars on the counter.
static func _stamp_prop(sculpt: Kit.Sculpt) -> void:
	var wood := Color("#9a7048")
	var dye := Color("#e0587a")
	sculpt.box(Vector3(-0.5, 2.85, -0.3), Vector3(0.06, 0.9, 0.06), wood.darkened(0.15))
	sculpt.box(Vector3(-0.2, 3.28, -0.3), Vector3(0.66, 0.06, 0.06), wood.darkened(0.15))
	sculpt.box(Vector3(0.1, 3.12, -0.3), Vector3(0.015, 0.3, 0.015), Color("#5a4632"))
	sculpt.ball(Vector3(0.1, 2.94, -0.3), 0.07, wood.lightened(0.15), Color.TRANSPARENT, 8, 3)
	sculpt.tube(Vector3(0.1, 2.86, -0.3), 0.03, 0.03, 0.1, wood, 6)
	sculpt.box(Vector3(0.1, 2.76, -0.3), Vector3(0.26, 0.12, 0.26), wood)
	sculpt.box(Vector3(0.1, 2.68, -0.3), Vector3(0.22, 0.04, 0.22), dye)
	sculpt.box(Vector3(0.1, 2.44, -0.25), Vector3(0.5, 0.02, 0.36), Color("#f6eedb"))
	for petal in 5:
		var at := Vector3(0.1, 2.46, -0.25) + Basis(Vector3.UP, petal * TAU / 5.0) * Vector3(0.07, 0, 0)
		sculpt.ball(at, 0.05, dye, Color.TRANSPARENT, 6, 2, 0.3)
	sculpt.ball(Vector3(0.1, 2.47, -0.25), 0.035, Color("#f2b93a"), Color.TRANSPARENT, 6, 2, 0.3)
	for jar in 3:
		var tone: Color = [dye, Color("#f2b93a"), Color("#6f9ad8")][jar]
		sculpt.tube(Vector3(-0.4 + jar * 0.16, 1.03, 0.1), 0.06, 0.06, 0.14, tone, 8)
		sculpt.box(Vector3(-0.4 + jar * 0.16, 1.12, 0.1), Vector3(0.07, 0.04, 0.07), Color("#b5884e"))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.36, 0.02, 0.26), Color("#f6eedb"))


## A big open book on the roof with its two pages swinging up to clap, a
## little ghost peeking over the spine, and a stack of books with a ribbon
## bookmark on the counter.
static func _book_prop(sculpt: Kit.Sculpt) -> void:
	var paper := Color("#efe3c8")
	var leather := Color("#7a3a5c")
	sculpt.box(Vector3(0, 2.42, -0.3), Vector3(1.3, 0.06, 0.5), leather)
	for side: float in [-1.0, 1.0]:
		var lift := Basis(Vector3.BACK, side * -0.55)
		sculpt.box(Vector3(side * 0.3, 2.62, -0.3), Vector3(0.62, 0.05, 0.44), paper, lift)
		sculpt.box(Vector3(side * 0.3, 2.6, -0.3), Vector3(0.6, 0.03, 0.42), paper.darkened(0.2), lift)
	sculpt.ball(Vector3(0, 2.86, -0.2), 0.15, Color("#eef0ff"), Color.TRANSPARENT, 8, 4, 1.15)
	for eye: float in [-0.05, 0.05]:
		sculpt.box(Vector3(eye, 2.9, -0.06), Vector3(0.03, 0.05, 0.02), Color("#2a2440"))
	for book in 3:
		var tone: Color = [Color("#5b3f74"), Color("#4f8f86"), Color("#c0485e")][book]
		sculpt.box(Vector3(0.28, 1.0 + book * 0.09, 0.1), Vector3(0.36 - book * 0.04, 0.08, 0.26), tone, Basis(Vector3.UP, book * 0.25))
	sculpt.box(Vector3(0.3, 0.96, 0.25), Vector3(0.04, 0.2, 0.01), Color("#d9a64e"))
	sculpt.box(Vector3(-0.3, 1.02, 0.1), Vector3(0.3, 0.1, 0.22), paper)


## A little bed on the roof with its pinstriped sheet running down as a slide,
## a sleeping cat curled on the sheet, and a pillow and a folded quilt on the
## counter.
static func _slide_prop(sculpt: Kit.Sculpt) -> void:
	var sheet := Color("#efe6f4")
	var plum := Color("#5b3f74")
	sculpt.box(Vector3(-0.35, 2.62, -0.3), Vector3(0.5, 0.16, 0.42), plum)
	sculpt.box(Vector3(-0.35, 2.74, -0.3), Vector3(0.48, 0.06, 0.4), sheet)
	sculpt.box(Vector3(-0.58, 2.86, -0.3), Vector3(0.06, 0.34, 0.42), plum.darkened(0.2))
	sculpt.box(Vector3(-0.44, 2.8, -0.3), Vector3(0.14, 0.07, 0.3), Color("#f3ecfa"))
	var slope := Basis(Vector3.BACK, 0.42)
	sculpt.box(Vector3(0.25, 2.55, -0.3), Vector3(0.78, 0.03, 0.4), sheet, slope)
	for stripe: float in [-0.12, 0.12]:
		sculpt.box(Vector3(0.25, 2.565, -0.3 + stripe), Vector3(0.78, 0.01, 0.02), Color("#9c86c8"), slope)
	sculpt.ball(Vector3(0.2, 2.62, -0.25), 0.08, Color("#d98a4a"), Color.TRANSPARENT, 8, 4, 0.7)
	sculpt.ball(Vector3(0.12, 2.66, -0.25), 0.05, Color("#d98a4a"), Color.TRANSPARENT, 6, 3)
	sculpt.box(Vector3(-0.25, 1.04, 0.1), Vector3(0.36, 0.1, 0.24), Color("#f3ecfa"))
	sculpt.box(Vector3(0.28, 1.0, 0.1), Vector3(0.36, 0.06, 0.26), Color("#e79bb6"))
	sculpt.box(Vector3(0.28, 1.06, 0.1), Vector3(0.34, 0.05, 0.24), Color("#4f8f86"))


## A big round brass door lock on the roof with its rings and a key in the
## keyhole at the top, and a ring of keys and a little broom on the counter.
static func _lock_prop(sculpt: Kit.Sculpt) -> void:
	var facing := Basis(Vector3.RIGHT, PI * 0.5)
	sculpt.tube(Vector3(0, 2.8, -0.3), 0.4, 0.4, 0.06, BRASS, 16, facing)
	for ring in 3:
		var radius := 0.33 - ring * 0.09
		sculpt.tube(Vector3(0, 2.8, -0.26), radius, radius, 0.03, Color("#b07a3a").darkened(ring * 0.12), 16, facing)
	sculpt.box(Vector3(0, 3.12, -0.24), Vector3(0.06, 0.08, 0.04), Color("#c9b6ff"))
	sculpt.box(Vector3(0, 3.3, -0.24), Vector3(0.05, 0.3, 0.04), BRASS)
	sculpt.tube(Vector3(0, 3.5, -0.24), 0.1, 0.1, 0.04, BRASS, 10, facing)
	sculpt.tube(Vector3(-0.28, 1.0, 0.1), 0.1, 0.1, 0.02, BRASS.darkened(0.2), 10)
	for key in 3:
		sculpt.box(Vector3(-0.36 + key * 0.08, 1.02, 0.18), Vector3(0.03, 0.02, 0.12), BRASS)
	sculpt.box(Vector3(0.32, 1.08, 0.08), Vector3(0.03, 0.3, 0.03), Color("#9a6a40"), Basis(Vector3.BACK, 0.5))
	sculpt.box(Vector3(0.42, 0.98, 0.08), Vector3(0.14, 0.1, 0.06), Color("#d9b85a"), Basis(Vector3.BACK, 0.5))


## A ramp of painted blocks on the roof with a cardboard-box car about to leave
## its lip, and a little taped box car on bottle-cap wheels on the counter.
static func _kart_prop(sculpt: Kit.Sculpt) -> void:
	var paints: Array[Color] = [Color("#c0503f"), Color("#4f79a8"), Color("#e0b04a")]
	var card := Color("#c99a62")
	for step in 3:
		sculpt.box(Vector3(-0.45 + step * 0.2, 2.5 + step * 0.06, -0.3), Vector3(0.2, 0.14 + step * 0.12, 0.24), paints[step])
	sculpt.box(Vector3(0.3, 2.86, -0.3), Vector3(0.3, 0.2, 0.24), card, Basis(Vector3.BACK, 0.35))
	sculpt.box(Vector3(0.3, 2.97, -0.3), Vector3(0.06, 0.2, 0.25), Color("#d9c08a"), Basis(Vector3.BACK, 0.35))
	sculpt.box(Vector3(0.0, 1.08, 0.1), Vector3(0.4, 0.2, 0.26), card)
	sculpt.box(Vector3(0.0, 1.08, 0.235), Vector3(0.08, 0.2, 0.01), Color("#d9c08a"))
	for wheel: float in [-0.13, 0.13]:
		sculpt.tube(Vector3(wheel, 0.99, 0.24), 0.05, 0.05, 0.03, Color("#c0503f"), 8, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(-0.08, 1.26, 0.06), Vector3(0.02, 0.2, 0.02), CREAM)
	sculpt.box(Vector3(-0.02, 1.32, 0.06), Vector3(0.1, 0.07, 0.01), Color("#f7f1e3"))


## A big dream bubble on the roof with a little sheep curled inside, and a
## pillow and a nightcap on the counter.
static func _bubble_prop(sculpt: Kit.Sculpt) -> void:
	sculpt.ball(Vector3(0, 2.95, -0.25), 0.42, Color("#d8ccff"), Color("#9fe0e0"), 12, 6, 1.0)
	sculpt.ball(Vector3(-0.14, 3.1, 0.12), 0.07, Color("#ffffff"), Color.TRANSPARENT, 6, 3)
	sculpt.ball(Vector3(0.02, 2.9, 0.12), 0.14, Color("#f4f0ff"), Color.TRANSPARENT, 8, 4, 0.8)
	sculpt.ball(Vector3(-0.12, 2.92, 0.16), 0.06, Color("#4a3a4a"), Color.TRANSPARENT, 6, 3)
	sculpt.box(Vector3(0, 2.5, -0.25), Vector3(0.05, 0.12, 0.05), BRASS)
	sculpt.box(Vector3(-0.26, 1.02, 0.1), Vector3(0.36, 0.1, 0.24), Color("#f3ecfa"))
	sculpt.tube(Vector3(0.28, 1.06, 0.1), 0.12, 0.02, 0.24, Color("#4f6f9a"), 8)
	sculpt.ball(Vector3(0.3, 1.2, 0.1), 0.04, Color("#ffd166"), Color.TRANSPARENT, 6, 3)


## A big wind-up music box on the roof with its lid open and a clown on a
## spring popping out, and a little brass cylinder and comb on the counter.
static func _musicbox_prop(sculpt: Kit.Sculpt) -> void:
	var walnut := Color("#6e4630")
	var brass := Color("#c9953e")
	sculpt.box(Vector3(-0.1, 2.62, -0.3), Vector3(0.62, 0.3, 0.36), walnut)
	sculpt.box(Vector3(-0.1, 2.62, -0.115), Vector3(0.4, 0.14, 0.02), brass)
	sculpt.box(Vector3(-0.1, 2.9, -0.46), Vector3(0.62, 0.32, 0.04), walnut.lightened(0.1), Basis(Vector3.RIGHT, -0.5))
	sculpt.box(Vector3(0.24, 2.85, -0.3), Vector3(0.03, 0.22, 0.03), Color("#c3c8cf"), Basis(Vector3.BACK, -0.3))
	sculpt.box(Vector3(0.3, 2.98, -0.3), Vector3(0.12, 0.12, 0.1), Color("#f7f1e3"))
	sculpt.box(Vector3(0.3, 3.06, -0.3), Vector3(0.14, 0.05, 0.11), Color("#c0503f"))
	sculpt.box(Vector3(0.36, 2.98, -0.24), Vector3(0.04, 0.04, 0.03), Color("#c0503f"))
	sculpt.box(Vector3(-0.48, 2.62, -0.3), Vector3(0.04, 0.04, 0.04), brass)
	sculpt.box(Vector3(-0.52, 2.62, -0.3), Vector3(0.03, 0.16, 0.06), brass)
	sculpt.tube(Vector3(0.0, 1.05, 0.1), 0.07, 0.07, 0.34, brass, 10, Basis(Vector3.BACK, PI * 0.5))
	for tooth in 5:
		sculpt.box(Vector3(-0.12 + tooth * 0.06, 1.0, 0.22), Vector3(0.03, 0.02, 0.14), Color("#c3c8cf"))


## A big folded paper plane gliding nose-up over the sign on a pole, and a
## little one on the counter.
static func _paper_wing_prop(sculpt: Kit.Sculpt) -> void:
	var paper := Color("#fbf8ee")
	var crease := Color("#cfc6d8")
	var stripe := Color("#e8807a")
	sculpt.box(Vector3(0.0, 2.45, -0.2), Vector3(0.04, 0.5, 0.04), DARK)
	for side: float in [-1.0, 1.0]:
		var wing := Basis(Vector3.FORWARD, side * 0.22) * Basis(Vector3.RIGHT, -0.25)
		sculpt.box(Vector3(side * 0.3, 2.78, -0.2), Vector3(0.6, 0.03, 0.42), paper, wing)
		sculpt.box(Vector3(side * 0.38, 2.8, -0.12), Vector3(0.3, 0.035, 0.06), stripe, wing)
	sculpt.box(Vector3(0.0, 2.7, -0.2), Vector3(0.05, 0.16, 0.5), crease, Basis(Vector3.RIGHT, -0.25))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(-0.25 + side * 0.09, 1.03, 0.12), Vector3(0.18, 0.02, 0.14), paper, Basis(Vector3.FORWARD, side * 0.2))
	sculpt.box(Vector3(-0.25, 1.01, 0.12), Vector3(0.03, 0.05, 0.16), crease)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## Three little cloud pads stepping up over the sign, each on a thin pole, the
## top one with a flag; a puff of cloud on the counter.
static func _cloudhop_prop(sculpt: Kit.Sculpt) -> void:
	var cloud := Color("#f4f0fa")
	for step in 3:
		var at := Vector3(-0.45 + step * 0.45, 2.3 + step * 0.16, -0.2)
		sculpt.box(at + Vector3(0, -0.2, 0), Vector3(0.03, 0.4, 0.03), DARK)
		sculpt.ball(at, 0.16, cloud, Color.TRANSPARENT, 8, 4, 0.55)
		sculpt.ball(at + Vector3(0.1, 0.03, 0), 0.12, cloud, Color.TRANSPARENT, 8, 4, 0.6)
		sculpt.ball(at + Vector3(-0.1, 0.02, 0), 0.11, cloud, Color.TRANSPARENT, 8, 4, 0.6)
	sculpt.box(Vector3(0.45, 2.92, -0.2), Vector3(0.02, 0.3, 0.02), DARK)
	sculpt.box(Vector3(0.53, 3.0, -0.2), Vector3(0.16, 0.1, 0.02), Color("#e8807a"))
	sculpt.ball(Vector3(-0.3, 1.04, 0.1), 0.12, cloud, Color.TRANSPARENT, 8, 4, 0.7)
	sculpt.ball(Vector3(-0.18, 1.02, 0.12), 0.09, cloud, Color.TRANSPARENT, 8, 4, 0.7)
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)

## A big shuttlecock on the roof, cork down and feathers up, with a racket
## leaning on it, and a little racket and shuttle lying on the counter.
static func _shuttle_prop(sculpt: Kit.Sculpt) -> void:
	var white := Color("#fbfdff")
	var coral := Color("#ff8a6b")
	var cork := Color("#e9c98f")
	sculpt.ball(Vector3(-0.1, 2.62, -0.3), 0.16, cork, Color.TRANSPARENT, 10, 6)
	sculpt.tube(Vector3(-0.1, 2.76, -0.3), 0.15, 0.15, 0.05, coral, 10)
	sculpt.tube(Vector3(-0.1, 2.98, -0.3), 0.16, 0.34, 0.42, white, 12)
	sculpt.box(Vector3(0.34, 2.86, -0.3), Vector3(0.04, 0.5, 0.04), Color("#a87a4f"), Basis(Vector3.BACK, 0.35))
	sculpt.tube(Vector3(0.44, 3.16, -0.3), 0.16, 0.16, 0.03, coral, 12, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.35))
	sculpt.box(Vector3(-0.22, 1.0, 0.12), Vector3(0.36, 0.02, 0.04), Color("#a87a4f"))
	sculpt.tube(Vector3(0.06, 1.01, 0.12), 0.1, 0.1, 0.02, coral, 10)
	sculpt.ball(Vector3(0.3, 1.02, 0.16), 0.04, cork, Color.TRANSPARENT, 6, 3)
	sculpt.tube(Vector3(0.36, 1.03, 0.16), 0.03, 0.07, 0.1, white, 8, Basis(Vector3.BACK, PI * 0.5))


## A little four-pane window on the roof, misted over with one pane wiped
## clear and a ghost peeking through it, and a cloth over a bucket on the
## counter.
static func _window_prop(sculpt: Kit.Sculpt) -> void:
	var frame := Color("#e8dcc4")
	sculpt.box(Vector3(0, 2.85, -0.3), Vector3(0.8, 0.7, 0.06), frame)
	for pane in 4:
		var x := -0.18 if pane % 2 == 0 else 0.18
		var y := 3.02 if pane < 2 else 2.68
		var clear := pane == 1
		sculpt.box(Vector3(x, y, -0.26), Vector3(0.32, 0.28, 0.02), Color("#2a3060") if clear else Color("#d8d4ec"))
	sculpt.ball(Vector3(0.18, 3.0, -0.22), 0.09, Color("#eef0ff"), Color.TRANSPARENT, 8, 4)
	sculpt.box(Vector3(0, 2.46, -0.24), Vector3(0.9, 0.06, 0.12), frame.darkened(0.2))
	sculpt.tube(Vector3(0.28, 1.06, 0.1), 0.12, 0.1, 0.16, Color("#8a8aa0"), 8)
	sculpt.box(Vector3(0.28, 1.16, 0.1), Vector3(0.26, 0.04, 0.22), Color("#f4ecd8"), Basis(Vector3.BACK, 0.2))
	sculpt.box(Vector3(-0.28, 1.0, 0.1), Vector3(0.3, 0.05, 0.2), Color("#e79bb6"))


## A little plank rope bridge on the roof between two posts with lanterns,
## and a coil of rope with a spare plank on the counter.
static func _rope_bridge_prop(sculpt: Kit.Sculpt) -> void:
	var wood := Color("#a87a4f")
	var dark := Color("#6e4c32")
	var rope := Color("#d9c08a")
	for side: float in [-0.42, 0.32]:
		sculpt.box(Vector3(side, 2.78, -0.3), Vector3(0.05, 0.42, 0.05), dark)
		sculpt.ball(Vector3(side, 3.02, -0.3), 0.05, Color("#ffd35c"), Color.TRANSPARENT, 6, 3)
	for plank in 6:
		var x := -0.33 + plank * 0.12
		var sag := 0.06 * sin(PI * (plank + 0.5) / 6.0)
		sculpt.box(Vector3(x, 2.6 - sag, -0.3), Vector3(0.09, 0.02, 0.26), wood.darkened(0.08 * (plank % 2)))
	for z: float in [-0.43, -0.17]:
		sculpt.box(Vector3(-0.05, 2.82, z), Vector3(0.74, 0.015, 0.015), rope)
	sculpt.tube(Vector3(-0.18, 1.01, 0.12), 0.1, 0.1, 0.05, rope, 10)
	sculpt.box(Vector3(0.22, 1.0, 0.14), Vector3(0.3, 0.02, 0.08), wood)


## A little brass cage lift on the roof with its cable, an arrow dial above
## and a ghost riding inside, and a red bellhop cap on the counter.
static func _lift_prop(sculpt: Kit.Sculpt) -> void:
	sculpt.box(Vector3(0, 2.8, -0.3), Vector3(0.56, 0.7, 0.46), Color("#2a2034"))
	for side: float in [-1.0, 1.0]:
		sculpt.box(Vector3(side * 0.27, 2.8, -0.08), Vector3(0.04, 0.7, 0.04), BRASS)
	for bar in 4:
		sculpt.box(Vector3(-0.18 + bar * 0.12, 2.8, -0.06), Vector3(0.02, 0.64, 0.02), BRASS.darkened(0.15))
	sculpt.box(Vector3(0, 3.18, -0.3), Vector3(0.6, 0.06, 0.5), BRASS)
	sculpt.box(Vector3(0, 3.5, -0.3), Vector3(0.03, 0.6, 0.03), Color("#3a3040"))
	sculpt.tube(Vector3(0, 3.34, -0.04), 0.12, 0.12, 0.03, BRASS, 10, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0.04, 3.38, -0.02), Vector3(0.1, 0.02, 0.01), Color("#2a2034"), Basis(Vector3.BACK, 0.7))
	sculpt.ball(Vector3(0.06, 2.72, -0.2), 0.12, Color("#eef0ff"), Color.TRANSPARENT, 8, 4)
	sculpt.tube(Vector3(-0.26, 1.02, 0.1), 0.1, 0.1, 0.1, Color("#c0485e"), 10)
	sculpt.box(Vector3(-0.26, 0.99, 0.18), Vector3(0.12, 0.02, 0.06), Color("#2a2034"))
	sculpt.box(Vector3(0.28, 1.0, 0.1), Vector3(0.18, 0.05, 0.14), BRASS)


## A big diamond kite flying on a pole over the roof with a ribbon tail, and a
## reel of string with a little arrow vane on the counter.
static func _wind_kite_prop(sculpt: Kit.Sculpt) -> void:
	var coral := Color("#ff8a6b")
	var sun := Color("#ffd35c")
	var dark := Color("#6e4c32")
	sculpt.box(Vector3(0.3, 2.85, -0.3), Vector3(0.04, 0.5, 0.04), dark)
	var tilt := Basis(Vector3.BACK, PI * 0.25)
	sculpt.box(Vector3(-0.05, 3.05, -0.32), Vector3(0.36, 0.36, 0.02), coral, tilt)
	sculpt.box(Vector3(-0.05, 3.05, -0.3), Vector3(0.18, 0.18, 0.02), sun, tilt)
	for bow in 3:
		sculpt.box(Vector3(-0.05 - bow * 0.08, 2.72 - bow * 0.1, -0.3), Vector3(0.06, 0.04, 0.02), [coral, sun, Color("#8fe0c4")][bow])
	sculpt.tube(Vector3(-0.2, 1.02, 0.12), 0.08, 0.08, 0.08, Color("#f4ecd8"), 10, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0.2, 1.08, 0.12), Vector3(0.02, 0.16, 0.02), dark)
	sculpt.box(Vector3(0.24, 1.16, 0.12), Vector3(0.12, 0.03, 0.03), sun)


## A little bed on the roof with a ghost asleep under a red quilt in a striped
## nightcap and a big Z over it, and a pillow on the counter.
static func _sleeper_prop(sculpt: Kit.Sculpt) -> void:
	var wood := Color("#6a4058")
	sculpt.box(Vector3(0, 2.52, -0.3), Vector3(0.9, 0.12, 0.44), wood)
	sculpt.box(Vector3(-0.42, 2.72, -0.3), Vector3(0.06, 0.4, 0.44), wood.lightened(0.1))
	sculpt.box(Vector3(0.08, 2.62, -0.3), Vector3(0.66, 0.08, 0.4), Color("#c0485e"))
	sculpt.box(Vector3(-0.28, 2.64, -0.3), Vector3(0.18, 0.08, 0.34), Color("#f3ecfa"))
	sculpt.ball(Vector3(-0.26, 2.78, -0.26), 0.11, Color("#eef0ff"), Color.TRANSPARENT, 8, 4)
	sculpt.tube(Vector3(-0.3, 2.9, -0.26), 0.08, 0.02, 0.14, Color("#c0485e"), 8, Basis(Vector3.BACK, 0.6))
	sculpt.box(Vector3(0.2, 3.1, -0.22), Vector3(0.18, 0.03, 0.02), Color("#d8d2ff"))
	sculpt.box(Vector3(0.2, 2.96, -0.22), Vector3(0.18, 0.03, 0.02), Color("#d8d2ff"))
	sculpt.box(Vector3(0.2, 3.03, -0.22), Vector3(0.03, 0.18, 0.02), Color("#d8d2ff"), Basis(Vector3.BACK, -0.7))
	sculpt.box(Vector3(0.24, 1.02, 0.1), Vector3(0.36, 0.1, 0.24), Color("#f3ecfa"))
	sculpt.box(Vector3(-0.28, 1.0, 0.1), Vector3(0.3, 0.06, 0.22), Color("#5b3f74"))


## A brass launcher on the roof tilted at the sky with a pink-ribboned cloud
## bundle in its mouth, a round gauge beside it, and a red pump on the counter.
static func _pump_prop(sculpt: Kit.Sculpt) -> void:
	var brass := Color("#d6a444")
	var red := Color("#d2554a")
	var cloud := Color("#f4f0fa")
	var tilt := Basis(Vector3.BACK, -0.6)
	sculpt.tube(Vector3(0.0, 2.6, -0.25), 0.13, 0.17, 0.62, brass, 12, tilt)
	sculpt.tube(Vector3(-0.14, 2.47, -0.25), 0.15, 0.15, 0.06, Color("#9a6a2a"), 12, tilt)
	sculpt.ball(Vector3(0.22, 2.94, -0.25), 0.15, cloud, Color.TRANSPARENT, 8, 4, 0.8)
	sculpt.box(Vector3(0.22, 2.94, -0.25), Vector3(0.03, 0.26, 0.3), Color("#f08cb0"))
	sculpt.box(Vector3(-0.1, 2.3, -0.25), Vector3(0.36, 0.08, 0.2), DARK)
	sculpt.tube(Vector3(-0.48, 2.55, -0.2), 0.16, 0.16, 0.05, brass, 14, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.tube(Vector3(-0.48, 2.55, -0.17), 0.13, 0.13, 0.02, CREAM, 14, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(-0.44, 2.58, -0.15), Vector3(0.1, 0.02, 0.02), red, Basis(Vector3.BACK, 0.7))
	sculpt.tube(Vector3(-0.25, 1.12, 0.12), 0.06, 0.06, 0.26, red, 10)
	sculpt.box(Vector3(-0.25, 1.3, 0.12), Vector3(0.02, 0.12, 0.02), Color("#c3c8cf"))
	sculpt.box(Vector3(-0.25, 1.36, 0.12), Vector3(0.18, 0.03, 0.04), Color("#a87a4f"))
	sculpt.box(Vector3(0.3, 1.0, 0.1), Vector3(0.4, 0.06, 0.3), CREAM)


## A big hoop net on a pole over the roof with a gold star caught in it, and a
## woven basket of little stars on the counter.
static func _star_net_prop(sculpt: Kit.Sculpt) -> void:
	var wood := Color("#a87a4f")
	var gold := Color("#ffd35c")
	sculpt.box(Vector3(0.25, 2.85, -0.3), Vector3(0.04, 0.5, 0.04), Color("#6e4c32"))
	sculpt.tube(Vector3(0.0, 3.08, -0.3), 0.24, 0.24, 0.04, wood, 14)
	sculpt.tube(Vector3(0.0, 2.98, -0.3), 0.22, 0.08, 0.18, Color("#e8f1fa"), 12)
	sculpt.ball(Vector3(0.0, 3.0, -0.3), 0.08, gold, Color.TRANSPARENT, 5, 3)
	sculpt.tube(Vector3(-0.15, 1.02, 0.12), 0.12, 0.09, 0.1, Color("#c99a5b"), 10)
	for star in 3:
		sculpt.ball(Vector3(-0.2 + star * 0.05, 1.09, 0.12), 0.03, gold, Color.TRANSPARENT, 5, 3)


## A big camera on a tripod on the roof aimed at a puffy cloud shaped like a
## rabbit, and a little stack of prints on the counter.
static func _cloud_camera_prop(sculpt: Kit.Sculpt) -> void:
	var dark := Color("#3d3f52")
	var white := Color("#fbfdff")
	for leg: float in [-0.12, 0.0, 0.12]:
		sculpt.box(Vector3(0.25 + leg, 2.72, -0.3 + leg * 0.5), Vector3(0.025, 0.3, 0.025), Color("#6e4c32"), Basis(Vector3.BACK, leg))
	sculpt.box(Vector3(0.25, 2.92, -0.3), Vector3(0.22, 0.14, 0.14), dark)
	sculpt.tube(Vector3(0.12, 2.94, -0.3), 0.05, 0.05, 0.08, Color("#6f86b8"), 10, Basis(Vector3.BACK, PI * 0.5))
	sculpt.ball(Vector3(-0.2, 3.05, -0.3), 0.12, white, Color.TRANSPARENT, 8, 4)
	sculpt.ball(Vector3(-0.2, 3.2, -0.3), 0.07, white, Color.TRANSPARENT, 6, 3)
	for ear: float in [-0.04, 0.04]:
		sculpt.box(Vector3(-0.2 + ear, 3.32, -0.3), Vector3(0.03, 0.1, 0.03), white)
	for card in 3:
		sculpt.box(Vector3(-0.15 + card * 0.02, 1.0 + card * 0.01, 0.12), Vector3(0.12, 0.01, 0.14), white.darkened(0.05 * card))


## A little wooden fence on the roof with a woolly sheep leaping it under a
## crescent moon and a stitched star, and a nightcap and a tally slate on the
## counter.
static func _sheep_prop(sculpt: Kit.Sculpt) -> void:
	var wood := Color("#8a6a4a")
	for post: float in [-0.36, 0.36]:
		sculpt.box(Vector3(post, 2.62, -0.3), Vector3(0.06, 0.36, 0.06), wood)
	for rail: float in [2.56, 2.72]:
		sculpt.box(Vector3(0, rail, -0.3), Vector3(0.78, 0.05, 0.04), wood.lightened(0.08))
	sculpt.ball(Vector3(0.02, 3.0, -0.26), 0.16, Color("#f4f0ff"), Color("#d8d2ea"), 10, 5, 0.75)
	sculpt.ball(Vector3(0.2, 3.04, -0.2), 0.07, Color("#3a3040"), Color.TRANSPARENT, 6, 3)
	for leg: float in [-0.08, 0.1]:
		sculpt.box(Vector3(leg, 2.86, -0.22), Vector3(0.03, 0.1, 0.03), Color("#3a3040"), Basis(Vector3.BACK, 0.6))
	sculpt.tube(Vector3(-0.34, 3.36, -0.3), 0.1, 0.1, 0.03, Color("#fff2c4"), 10, Basis(Vector3.RIGHT, PI * 0.5))
	sculpt.box(Vector3(0.32, 3.34, -0.28), Vector3(0.08, 0.08, 0.02), Color("#ffd98a"), Basis(Vector3.BACK, 0.785))
	sculpt.tube(Vector3(-0.26, 1.04, 0.1), 0.1, 0.02, 0.2, Color("#5b3f74"), 8, Basis(Vector3.BACK, 0.5))
	sculpt.box(Vector3(0.28, 1.06, 0.06), Vector3(0.3, 0.2, 0.03), Color("#2a2a32"), Basis(Vector3.RIGHT, -0.3))
