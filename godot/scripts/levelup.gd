# XP-driven level-up: builds the 3-card offer and applies the pick
# (plan §5 pool: new weapon, weapon level+1, passive; passives cap at 5).
class_name LevelUpDeck
extends RefCounted

const MAX_PASSIVE_STACKS := 5

const PASSIVES := [
	{"key": "ferocity", "name": "Ferocity", "desc": "+10% weapon damage"},
	{"key": "haste", "name": "Haste", "desc": "+8% move speed"},
	{"key": "ward", "name": "Warding", "desc": "-1 damage taken"},
	{"key": "grip", "name": "Grip", "desc": "+25% pickup radius"},
	{"key": "insight", "name": "Insight", "desc": "+15% xp gain"},
]


static func build_pool(game: GameState) -> Array:
	var pool: Array = []
	for id in WeaponSystem.IDS:
		var owned: Dictionary = {}
		for w in game.weapons:
			if w.id == id:
				owned = w
				break
		var meta: Dictionary = WeaponSystem.META[id]
		if owned.is_empty():
			pool.append({"kind": "weapon", "id": id, "name": meta.name,
				"desc": meta.desc, "icon": meta.icon})
		elif owned.level < WeaponSystem.MAX_LEVEL:
			pool.append({"kind": "upgrade", "id": id, "name": meta.name,
				"desc": meta.desc, "icon": meta.icon, "to_level": owned.level + 1})
	for passive in PASSIVES:
		if game.passives[passive.key] < MAX_PASSIVE_STACKS:
			pool.append({"kind": "passive", "key": passive.key,
				"name": passive.name, "desc": passive.desc, "icon": ""})
	return pool


# Nothing left to grant (everything capped): offer a rich consolation.
static func bonus_card() -> Dictionary:
	return {"kind": "bonus", "name": "Coin Cache", "desc": "+25 gold, +10 hp", "icon": "coin"}


static func make_offer(game: GameState) -> Array:
	var pool := build_pool(game)
	pool.shuffle()
	var cards: Array = []
	for i in 3:
		cards.append(pool[i] if i < pool.size() else bonus_card())
	return cards


static func apply_offer(game: GameState, card: Dictionary) -> void:
	match card.kind:
		"weapon":
			game.weapons.append({"id": card.id, "level": 1, "cd": 0.0})
		"upgrade":
			for w in game.weapons:
				if w.id == card.id and w.level < WeaponSystem.MAX_LEVEL:
					w.level += 1
					break
		"passive":
			game.passives[card.key] += 1
		_:
			game.gold += 25
			game.hp = minf(game.max_hp, game.hp + 10.0)
