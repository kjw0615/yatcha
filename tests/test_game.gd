extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var checks = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Rules.score([6, 6, 6, 6, 6], 5) == 30, "Upper score")
	check(Rules.score([1, 2, 3, 4, 6], 9) == 15, "Small straight")
	check(Rules.score([1, 2, 2, 3, 4], 9) == 15, "Duplicate in small straight")
	check(Rules.score([1, 2, 3, 5, 6], 9) == 0, "Broken straight")
	check(Rules.score([2, 3, 4, 5, 6], 10) == 30, "Large straight")
	check(Rules.score([2, 2, 3, 3, 3], 8) == 13, "Full house")
	check(Rules.score([6, 6, 6, 6, 6], 8) == 0, "Yacht is not full house")
	check(Rules.score([6, 6, 6, 6, 2], 7) == 26, "Four of a kind includes fifth")
	check(Rules.score([6, 6, 6, 6, 6], 11) == 50, "Yacht")
	check(Rules.score([6, 6, 6, 6, 5], 11) == 0, "Not yacht")
	check(Rules.bonus([3, 6, 9, 12, 15, 18, -1, -1, -1, -1, -1, -1]) == 35, "Bonus threshold")
	check(Rules.bonus([2, 6, 9, 12, 15, 18, -1, -1, -1, -1, -1, -1]) == 0, "Below bonus")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	check(game.sheets.size() == 2 and game.rolls == 0, "Initial state")
	game.select_category(0)
	check(game.selected == -1, "Cannot score before roll")
	await game.roll_dice()
	check(game.rolls == 1, "First roll")
	var kept = game.dice[0]
	game.toggle_hold(0)
	await game.roll_dice()
	check(game.dice[0] == kept and game.rolls == 2, "Held die stays")
	await game.roll_dice()
	await game.roll_dice()
	check(game.rolls == 3, "Maximum three rolls")
	game.new_game()
	for turn in range(24):
		game.dice = [1, 2, 3, 4, 5]
		game.rolls = 1
		game.select_category(turn / 2)
		game.commit_score()
		if turn == 0:
			check(game.player == 1 and game.rolls == 0, "Turn switches")
			game.rolls = 1
			game.selected = 0
			game.sheets[1][0] = 0
			game.commit_score()
			check(game.player == 1, "Cannot overwrite filled category")
			game.sheets[1][0] = -1
			game.selected = -1
	check(game.finished, "Game ends after 24 turns")
	check(not game.sheets[0].has(-1) and not game.sheets[1].has(-1), "All categories filled")
	check(Rules.total(game.sheets[0]) == 75, "Final score")
	game.new_game()
	check(not game.finished and game.sheets[0].count(-1) == 12, "Restart")
	print("PASS: %d checks including full 24-turn game" % checks)
	quit(0)
