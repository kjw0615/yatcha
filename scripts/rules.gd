class_name YachtRules
extends RefCounted

const TITLES = ["에이스", "듀얼", "트리플", "쿼드", "펜타", "헥사", "초이스", "포카드", "풀하우스", "스몰 스트레이트", "라지 스트레이트", "요트"]
const HINTS = ["1의 합", "2의 합", "3의 합", "4의 합", "5의 합", "6의 합", "모든 눈의 합", "같은 눈 4개 이상 · 전체 합", "같은 눈 3개 + 2개 · 전체 합", "연속된 눈 4개 · 15점", "연속된 눈 5개 · 30점", "같은 눈 5개 · 50점"]

static func score(dice: Array, category: int) -> int:
	if dice.size() != 5:
		return 0
	var counts = [0, 0, 0, 0, 0, 0, 0]
	var total = 0
	for value in dice:
		if value < 1 or value > 6:
			return 0
		counts[value] += 1
		total += value
	if category < 6:
		return counts[category + 1] * (category + 1)
	match category:
		6: return total
		7: return total if counts.max() >= 4 else 0
		8: return total if counts.has(3) and counts.has(2) else 0
		9, 10:
			var run = 0
			var longest = 0
			for face in range(1, 7):
				run = run + 1 if counts[face] > 0 else 0
				longest = maxi(longest, run)
			if category == 9:
				return 15 if longest >= 4 else 0
			return 30 if longest >= 5 else 0
		11: return 50 if counts.max() == 5 else 0
	return 0

static func upper(sheet: Array) -> int:
	var result = 0
	for i in range(6):
		result += maxi(0, sheet[i])
	return result

static func bonus(sheet: Array) -> int:
	return 35 if upper(sheet) >= 63 else 0

static func total(sheet: Array) -> int:
	var result = bonus(sheet)
	for value in sheet:
		result += maxi(0, value)
	return result
