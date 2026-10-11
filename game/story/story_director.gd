extends RefCounted

const INTRO_LINES: Array[Dictionary] = [
	{"speaker": "票票", "text": "歡迎抵達迎賓大道！行李請放好，笑容不用寄艙。"},
	{"speaker": "主角", "text": "那邊有位同學，尾巴好像比行李先下船。"},
	{"speaker": "小角", "text": "這是新式圍巾！只是它會自己打結。"},
	{"speaker": "票票", "text": "請放心，今天沒有入園考試。第一張拍貼就在前面。"},
	{"speaker": "露露", "text": "想慢慢看也可以，錯過的照片之後都能回來補拍。"},
]

const MAIN_LINES: Array[Dictionary] = [
	{"speaker": "票票", "text": "大道有遊戲、探索和合照。照片會把今天的小意外收好。"},
	{"speaker": "阿浪", "text": "廣播亭修好了！目前只會把入口說成出口，算是半修好。"},
	{"speaker": "小角", "text": "我可以幫忙播報！請往出口……我是說，請跟著笑聲走。"},
	{"speaker": "露露", "text": "拍貼不必完美。站歪一點，反而比較像真的在玩。"},
	{"speaker": "票票", "text": "園區的大門一直開著。先去逛逛，回來再說也沒問題。"},
]

const QUESTS: Dictionary = {
	"quest-001": {
		"id": "quest-001", "title": "吉祥物的尾巴危機", "photo_id": "photo-welcome-quest-1",
		"steps": [
			{"prompt": "哪個部分讓小角看起來像有第二條尾巴？", "options": ["背景板的圓孔", "地上的腳印", "票票的帽子"], "correct": 0, "feedback": "圓孔剛好套住尾巴，看起來像多了一條！"},
			{"prompt": "把背景板移到哪裡，能讓尾巴變成彩帶？", "options": ["對準背景的飄帶缺口", "蓋住小角的臉", "移到相機後面"], "correct": 0, "feedback": "尾巴接上飄帶缺口，這下是園區限定裝飾了。"},
			{"prompt": "最後要怎麼留下這張合照？", "options": ["選個滑稽姿勢再按快門", "等尾巴自己打蝴蝶結", "請票票寄存相機"], "correct": 0, "feedback": "拍好了！小角堅稱那是他設計的彩帶。"},
		],
	},
	"quest-002": {
		"id": "quest-002", "title": "廣播即興救場", "photo_id": "photo-welcome-quest-2",
		"steps": [
			{"prompt": "阿浪剛才把入口說成哪裡？", "options": ["出口", "海底", "員工休息室"], "correct": 0, "feedback": "沒錯，入口出口只差一個方向，差點把大家送回港口。"},
			{"prompt": "指向迎賓大道入口的箭頭該朝哪邊？", "options": ["朝園區裡面", "朝回船碼頭", "朝天空"], "correct": 0, "feedback": "箭頭轉正了，這次不用搭船回來。"},
			{"prompt": "選哪句話替廣播收尾？", "options": ["歡迎來玩，迷路也算探索！", "本亭今日停止思考。", "請把票票寄到失物招領。"], "correct": 0, "feedback": "票票笑了。阿浪說廣播亭終於通過口試。"},
		],
	},
}

const EXPLORATIONS: Array[Dictionary] = [
	{"id": "explore-001", "zone": "welcome", "title": "花壇會眨眼", "interaction": "觀察花壇眼睛跟隨角色；站到地面笑臉上按表情鈕，讓花朵一起眨眼後拍貼。", "hint": "花壇旁牌子畫著笑臉與腳印。", "photo_id": "photo-welcome-explore-1"},
	{"id": "explore-002", "zone": "welcome", "title": "歡迎字樣的影子", "interaction": "旋轉大道展示燈，讓歡迎字樣投影落到牆上空框；按牆邊快門取卡。", "hint": "空框內有字樣輪廓與燈光箭頭。", "photo_id": "photo-welcome-explore-2"},
	{"id": "explore-003", "zone": "welcome", "title": "長椅雙人份", "interaction": "坐到長椅並放下免費借用的吉祥物立牌；按扶手快門取得合照卡。", "hint": "椅上有兩個座位圖示與立牌借用架。", "photo_id": "photo-welcome-explore-3"},
]

const PROLOGUE_ENTRY: Dictionary = {
	"id": "prologue-boat", "title": "開船前的小插曲", "status": "future", "replayable": true,
	"description": "預留船上序章入口；目前尚未演出，玩家從下船抵達迎賓大道開始。",
}

func intro_lines() -> Array:
	return INTRO_LINES.duplicate(true)

func main_lines() -> Array:
	return MAIN_LINES.duplicate(true)

func quest_data(id: String) -> Dictionary:
	return (QUESTS.get(id, {}) as Dictionary).duplicate(true)

func exploration_data() -> Array:
	return EXPLORATIONS.duplicate(true)

func prologue_entry() -> Dictionary:
	return PROLOGUE_ENTRY.duplicate(true)
