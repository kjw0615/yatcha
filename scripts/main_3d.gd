extends Control

const Rules = preload("res://scripts/rules.gd")
const Board3DScene = preload("res://scenes/board_3d.tscn")
const MINT = Color("76e5c0")
const WHITE = Color("eaf3f5")
const MUTED = Color("8fa7b8")

var sheets = []
var dice = [1, 1, 1, 1, 1]
var held = [false, false, false, false, false]
var player = 0
var rolls = 0
var selected = -1
var busy = false
var finished = false

var board_3d: Node3D
var die_buttons: Array = []
var hold_labels: Array = []
var cells: Array = []
var totals: Array = []
var bonus_labels: Array = []
var turn_label: Label
var phase_label: Label
var status_label: Label
var roll_button: Button
var commit_button: Button
var history_label: Label
var history: Array = []
var rng = RandomNumberGenerator.new()

# 스페이스바 누르고 있기(흔들기) 상태 관리
var is_space_pressed: bool = false
var is_shaking_cup: bool = false

# 흔들기 파워 게이지 (board_3d의 shake_intensity 범위 0.2~1.8, 던지기 유효 범위 0.5~2.0)
const POWER_MIN = 0.2
const POWER_MAX = 1.8
const POWER_WEAK = 0.5
const POWER_STRONG = 1.3
var power_bar: ProgressBar
var power_label: Label
var power_zone = -1

func _ready() -> void:
	rng.randomize()
	var ui_theme = Theme.new()
	ui_theme.default_font_size = 17
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.set_color("font_color", "Label", WHITE)
	theme = ui_theme
	build_ui()
	new_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			if event.pressed and not event.echo:
				_on_roll_press_started()
			elif not event.pressed:
				_on_roll_press_released()
		elif event.pressed and not event.echo:
			if event.keycode >= KEY_1 and event.keycode <= KEY_5:
				toggle_hold(event.keycode - KEY_1)
			elif event.keycode == KEY_ENTER:
				if selected >= 0 and not commit_button.disabled:
					commit_score()

func _on_roll_press_started() -> void:
	if busy or finished or rolls >= 3 or held.all(func(value): return value):
		return
	is_space_pressed = true
	is_shaking_cup = true
	selected = -1
	refresh()
	board_3d.start_shaking_cup(held)

func _on_roll_press_released() -> void:
	if is_shaking_cup:
		is_shaking_cup = false
		is_space_pressed = false
		busy = true
		refresh()
		board_3d.release_and_throw_cup()

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func label_in(parent: Node, text_value: String, font_size: int = 17, color: Color = WHITE) -> Label:
	var item = Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button_in(parent: Node, text_value: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = text_value
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal", style(Color("203848")))
	item.add_theme_stylebox_override("hover", style(Color("31566a")))
	item.add_theme_stylebox_override("pressed", style(Color("247967")))
	item.add_theme_stylebox_override("disabled", style(Color("14232e")))
	item.add_theme_color_override("font_disabled_color", Color("536976"))
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func panel_in(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(Color(0.06, 0.14, 0.19, 0.9), 18))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column

func build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	
	var header = HBoxContainer.new()
	root.add_child(header)
	
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	label_in(brand, "YACHT CLUB 3D", 32, MINT)
	label_in(brand, "물리 기반 3D 다이스 트레이 & 컵 흔들기 [Space 길게 누르고 떼기 / 1~5: 킵]", 15, MUTED)
	button_in(header, "게임 규칙", show_rules)
	button_in(header, "새 게임", confirm_restart)
	
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)
	
	# 좌측 3D 뷰포트 및 조작부 패널
	var left = panel_in(body)
	left.custom_minimum_size.x = 580
	label_in(left, "3D PHYSICS TRAY / D6 INTERACTIVE", 13, MINT)
	turn_label = label_in(left, "", 28)
	phase_label = label_in(left, "", 16, MUTED)
	
	# 3D 뷰포트 컨테이너
	var subviewport_container = SubViewportContainer.new()
	subviewport_container.stretch = true
	subviewport_container.custom_minimum_size = Vector2(550, 320)
	subviewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(subviewport_container)
	
	var subviewport = SubViewport.new()
	subviewport.handle_input_locally = false
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport_container.add_child(subviewport)
	
	board_3d = Board3DScene.instantiate()
	subviewport.add_child(board_3d)
	board_3d.roll_finished.connect(_on_3d_roll_finished)
	board_3d.cup_state_changed.connect(_on_cup_state_changed)
	
	# 하단 킵(Keep) 상태 표시 및 토글 버튼 바
	var tray = HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("separation", 10)
	left.add_child(tray)
	for i in range(5):
		var column = VBoxContainer.new()
		tray.add_child(column)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(76, 50)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_stylebox_override("normal", style(Color("203848")))
		btn.add_theme_stylebox_override("hover", style(Color("31566a")))
		btn.add_theme_stylebox_override("pressed", style(Color("247967")))
		btn.pressed.connect(toggle_hold.bind(i))
		column.add_child(btn)
		die_buttons.append(btn)
		var caption = label_in(column, "", 12, MINT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_labels.append(caption)
	
	# 흔들기 파워 게이지: 구간별 색과 문구로 던질 타이밍을 안내
	power_label = label_in(left, "", 14, MUTED)
	power_bar = ProgressBar.new()
	power_bar.min_value = POWER_MIN
	power_bar.max_value = POWER_MAX
	power_bar.step = 0.01
	power_bar.show_percentage = false
	power_bar.custom_minimum_size.y = 16
	power_bar.add_theme_stylebox_override("background", style(Color("14232e"), 8))
	left.add_child(power_bar)
	reset_power_gauge()
	
	# 마우스로도 누르고 있다 뗄 수 있는 굴리기 버튼
	roll_button = Button.new()
	roll_button.text = "주사위 통 흔들기 및 던지기 (Space)"
	roll_button.custom_minimum_size.y = 52
	roll_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	roll_button.add_theme_font_size_override("font_size", 18)
	roll_button.add_theme_stylebox_override("normal", style(Color("1f6b5b")))
	roll_button.add_theme_stylebox_override("hover", style(Color("2a8f7a")))
	roll_button.add_theme_stylebox_override("pressed", style(Color("bf8438")))
	roll_button.add_theme_stylebox_override("disabled", style(Color("14232e")))
	roll_button.button_down.connect(_on_roll_press_started)
	roll_button.button_up.connect(_on_roll_press_released)
	left.add_child(roll_button)
	
	status_label = label_in(left, "", 15, WHITE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# 우측 점수판 패널
	var right = panel_in(body)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score_grid = GridContainer.new()
	score_grid.columns = 3
	score_grid.add_theme_constant_override("h_separation", 10)
	score_grid.add_theme_constant_override("v_separation", 5)
	right.add_child(score_grid)
	
	label_in(score_grid, "족보", 14, MUTED)
	label_in(score_grid, "Player 1", 14, MINT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_in(score_grid, "Player 2", 14, MINT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	for i in range(12):
		var row = []
		var name_label = label_in(score_grid, Rules.TITLES[i], 16)
		name_label.tooltip_text = Rules.HINTS[i]
		for p in range(2):
			var cell = Button.new()
			cell.custom_minimum_size = Vector2(76, 34)
			cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cell.pressed.connect(select_category.bind(i))
			score_grid.add_child(cell)
			row.append(cell)
		cells.append(row)
		if i == 5:
			label_in(score_grid, "보너스 (63점 이상 +35)", 14, MUTED)
			for p in range(2):
				var bonus_label = label_in(score_grid, "0/63", 14, MUTED)
				bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bonus_labels.append(bonus_label)
	
	label_in(score_grid, "총점", 18, WHITE)
	for p in range(2):
		var total_label = label_in(score_grid, "0", 22, MINT)
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		totals.append(total_label)
	
	commit_button = button_in(right, "기록 확정 (Enter)", commit_score)
	commit_button.custom_minimum_size.y = 48
	commit_button.add_theme_font_size_override("font_size", 18)
	
	label_in(right, "최근 기록", 13, MUTED)
	history_label = label_in(right, "", 14, MUTED)

func new_game() -> void:
	sheets = []
	for p in range(2):
		var sheet = []
		sheet.resize(12)
		sheet.fill(-1)
		sheets.append(sheet)
	player = 0
	rolls = 0
	selected = -1
	busy = false
	finished = false
	is_shaking_cup = false
	is_space_pressed = false
	history.clear()
	held = [false, false, false, false, false]
	dice = [1, 1, 1, 1, 1]
	for i in range(5):
		board_3d.set_held(i, false)
	update_dice()
	refresh()

func toggle_hold(index: int) -> void:
	if rolls == 0 or busy or finished or is_shaking_cup:
		return
	held[index] = not held[index]
	board_3d.set_held(index, held[index])
	refresh()

func _on_cup_state_changed(shaking: bool, power: float) -> void:
	if not shaking:
		reset_power_gauge()
		return
	power_bar.value = power
	var zone = 0
	var color = Color("6f8aa0")
	var text = "약함 · 조금 더 흔드세요"
	if power >= POWER_MAX - 0.02:
		zone = 3
		color = Color("ff8a5c")
		text = "MAX · 지금 떼어서 던지세요!"
	elif power >= POWER_STRONG:
		zone = 2
		color = Color("f2b56b")
		text = "강함 · 멀리 굴러갑니다"
	elif power >= POWER_WEAK:
		zone = 1
		color = MINT
		text = "적정 · 언제든 던질 수 있습니다"
	if zone != power_zone:
		power_zone = zone
		power_bar.add_theme_stylebox_override("fill", style(color, 8))
		power_label.add_theme_color_override("font_color", color)
		power_label.text = "흔들기 파워  %s" % text
	status_label.text = "통을 흔드는 중입니다! 원하는 타이밍에 키나 버튼을 떼어 던지세요. (파워 %.1fx)" % power
	roll_button.text = "흔드는 중! (떼면 던지기)"

func reset_power_gauge() -> void:
	power_zone = -1
	power_bar.value = POWER_MIN
	power_bar.add_theme_stylebox_override("fill", style(Color("6f8aa0"), 8))
	power_label.add_theme_color_override("font_color", MUTED)
	power_label.text = "흔들기 파워  Space를 길게 눌러 통을 흔드세요"

func _on_3d_roll_finished(new_values: Array) -> void:
	for i in range(5):
		if not held[i]:
			dice[i] = new_values[i]
	rolls += 1
	busy = false
	update_dice()
	refresh()

func update_dice() -> void:
	for i in range(5):
		die_buttons[i].text = "주사위 %d\n[ %d ]" % [i + 1, dice[i]]
		var is_keep = held[i]
		die_buttons[i].add_theme_stylebox_override("normal", style(Color("247967") if is_keep else Color("203848")))
		hold_labels[i].text = "KEEP (보관)" if is_keep else "ROLL (굴림)"
		hold_labels[i].add_theme_color_override("font_color", MINT if is_keep else MUTED)

func select_category(category: int) -> void:
	if busy or finished or rolls == 0 or sheets[player][category] >= 0:
		return
	selected = category
	refresh()

func commit_score() -> void:
	if selected < 0 or busy or finished or rolls == 0 or sheets[player][selected] >= 0:
		return
	var points = Rules.score(dice, selected)
	sheets[player][selected] = points
	history.push_front("P%d  ·  %s  +%d" % [player + 1, Rules.TITLES[selected], points])
	if history.size() > 3:
		history.pop_back()
	finished = not sheets[0].has(-1) and not sheets[1].has(-1)
	if not finished:
		player = 1 - player
		rolls = 0
		selected = -1
		held = [false, false, false, false, false]
		for i in range(5):
			board_3d.set_held(i, false)
	refresh()

func refresh() -> void:
	var completed = 0
	for value in sheets[player]:
		if value >= 0:
			completed += 1
	turn_label.text = "PLAYER %d의 차례" % (player + 1)
	phase_label.text = "ROUND %02d / 12     ·     굴리기 %d / 3" % [mini(12, completed + 1), rolls]
	
	if not is_shaking_cup:
		roll_button.text = "주사위 통 흔들기 (Space 길게 누르기) · %d회 남음" % (3 - rolls)
	
	roll_button.disabled = busy or finished or rolls >= 3 or held.all(func(value): return value)
	commit_button.disabled = selected < 0 or busy or finished
	
	if not is_shaking_cup:
		status_label.text = "Space 키나 버튼을 길게 눌러 통을 흔든 뒤 떼어서 던지세요."
		if busy:
			status_label.text = "3D 물리 주사위가 트레이 안에서 구르는 중입니다..."
		elif rolls > 0:
			status_label.text = "1~5번 키나 주사위를 눌러 킵(Keep)하거나, 오른쪽에서 족보를 선택하세요."
			if rolls == 3:
				status_label.text = "굴리기를 모두 소진했습니다. 점수를 기록할 족보를 선택하세요."
	
	commit_button.text = "점수표에서 족보를 선택하세요"
	if selected >= 0:
		var points = Rules.score(dice, selected)
		commit_button.text = "%s · %d점 기록 확정 (Enter)" % [Rules.TITLES[selected], points]
		if points == 0:
			status_label.text = "이 족보를 0점으로 소진합니다. 확정 전에 확인하세요."
	
	for p in range(2):
		totals[p].text = str(Rules.total(sheets[p]))
		bonus_labels[p].text = "%d/63 · +%d" % [Rules.upper(sheets[p]), Rules.bonus(sheets[p])]
		for category in range(12):
			var cell = cells[category][p]
			var recorded = sheets[p][category]
			cell.disabled = p != player or recorded >= 0 or rolls == 0 or busy or finished
			cell.text = str(recorded) if recorded >= 0 else "-"
			cell.add_theme_color_override("font_disabled_color", WHITE if recorded >= 0 else MUTED)
			if recorded < 0 and p == player and rolls > 0 and not finished:
				cell.text = "%d" % Rules.score(dice, category)
			var color = Color("247967") if selected == category and p == player else Color("203848")
			cell.add_theme_stylebox_override("normal", style(color))
	
	history_label.text = "\n".join(history) if not history.is_empty() else "첫 번째 기록을 기다리고 있습니다."
	if finished:
		var first = Rules.total(sheets[0])
		var second = Rules.total(sheets[1])
		turn_label.text = "무승부!" if first == second else "PLAYER %d 승리!" % (1 if first > second else 2)
		phase_label.text = "최종 결과   ·   %d : %d" % [first, second]
		status_label.text = "모든 판이 끝났습니다. 새 게임으로 다시 도전하세요!"

func show_rules() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "요트 다이스 3D 규칙 및 조작법"
	dialog.dialog_text = "두 명이 번갈아 12번씩 플레이합니다.\n\n[새로운 3D 조작법]\n• Space 길게 누르기(또는 버튼 누르고 있기): 3D 주사위 통 흔들기\n• Space 떼기: 원하는 타이밍에 트레이 안으로 주사위 던지기\n• 1~5 키 또는 주사위 버튼: 킵(Keep) / 롤(Roll) 전환\n• 점수표 클릭 후 Enter: 점수 확정\n\n[규칙]\n1. 턴당 최대 3회 굴릴 수 있습니다.\n2. 보관(Keep)된 주사위는 통에 들어가지 않고 상단에 유지됩니다.\n3. 1~6 상단 점수 합계 63점 이상 시 보너스 +35점 획득."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650, 500))

func confirm_restart() -> void:
	if busy:
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "새 게임"
	dialog.dialog_text = "현재 점수를 초기화하고 새 게임을 시작할까요?"
	add_child(dialog)
	dialog.confirmed.connect(func():
		new_game()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
