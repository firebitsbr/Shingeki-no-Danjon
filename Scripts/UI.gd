extends CanvasLayer

const SKILL_TIMEOUT = 3
const CHOOSER_BASE_Y = 96

onready var player = $"../.."
onready var status_panel = $Tabs/Inventory
onready var skill_panel = $Tabs/Skills

var just_opened = false
var skill_time = 0

var dialogues = []
var on_dialogue = false
var dialogue_status
var shop = []

signal message_closed
signal choice_selected

func _ready():
	PlayerStats.connect("level_up", self, "level_up")
	SkillBase.connect("new_skill", self, "new_skill")
	DungeonState.connect("floor_changed", self, "new_floor")
	
	for button in status_panel.get_node("AddStat").get_children():
		button.connect("pressed", self, "on_add_stat", [button.name])
	for button in status_panel.get_node("Inventory").get_children():
		button.connect("pressed", self, "on_inventory_click", [button.get_index()])
	for button in $Shop/ShopItems.get_children():
		button.connect("pressed", self, "on_buy", [button.get_index()])
		button.connect("mouse_entered", self, "over_shop", [button.get_index()])
		button.connect("mouse_exited", self, "out_shop", [button.get_index()])
	for icon in skill_panel.get_node("Icons").get_children():
		icon.connect("mouse_entered", self, "over_skill_icon", [icon.get_index()])
		icon.connect("mouse_exited", self, "out_skill_icon", [icon.get_index()])

func _physics_process(delta):
	if skill_time > 0:
		skill_time -= delta
		$SkillAcquiredPanel.modulate.a = clamp(skill_time / (SKILL_TIMEOUT-1), 0, 1)
		
		if skill_time <= 0:
			$SkillAcquiredPanel.visible = false
			
	if !get_tree().paused: return
	
	if on_dialogue:
		if on_dialogue.has("choices"):
			if Input.is_action_just_pressed("ui_down") and on_dialogue.choice < on_dialogue.choices.size()-1:
				on_dialogue.choice += 1
			elif Input.is_action_just_pressed("ui_up") and on_dialogue.choice > 0:
				on_dialogue.choice -= 1
			$DialogueBox/Chooser.rect_position.y = CHOOSER_BASE_Y + on_dialogue.choice * 48
			
		if Input.is_action_just_pressed("Interact") and !just_opened:
			if on_dialogue.has("choices"): dialogue_status.branch = dialogue_status.dialogue[dialogue_status.branch].branches[on_dialogue.choice]
			next_message()
		
	elif Input.is_action_just_pressed("Menu") and !just_opened:
		$"/root/Game".leave_menu = true
		$Tabs.visible = false
		$Shop.visible = false
		get_tree().paused = false
			
	just_opened = false

func enable():
	$Tabs.visible = true
	just_opened = true
	refresh()

func soft_refresh():
	$HUD/HealthIndicator.max_value = PlayerStats.max_health
	$HUD/HealthIndicator.value = PlayerStats.health
	$HUD/ManaIndicator.max_value = PlayerStats.max_mana
	$HUD/ManaIndicator.value = PlayerStats.mana

func refresh():
	$HUD/HealthIndicator.max_value = PlayerStats.max_health
	$HUD/HealthIndicator.value = PlayerStats.health
	$HUD/ManaIndicator.max_value = PlayerStats.max_mana
	$HUD/ManaIndicator.value = PlayerStats.mana
	
	status_panel.get_node("Stats/Level").text = str(PlayerStats.level)
	status_panel.get_node("Stats/Skillpoints").text =  str(PlayerStats.stat_points)
	status_panel.get_node("Stats/Experience").text =  str(PlayerStats.experience)
	var to_next = PlayerStats.total_exp(PlayerStats.level-1) + PlayerStats.exp_to_level(PlayerStats.level)
	status_panel.get_node("Stats/ToNext").text =  str(to_next- PlayerStats.experience)
	status_panel.get_node("Stats/Strength").text =  str(PlayerStats.strength)
	status_panel.get_node("Stats/Dexterity").text =  str(PlayerStats.dexterity)
	status_panel.get_node("Stats/Intelligence").text =  str(PlayerStats.intelligence)
	status_panel.get_node("Stats/Vitality").text =  str(PlayerStats.vitality)
	status_panel.get_node("Money/Amount").text =  str(PlayerStats.money)
	
	for button in status_panel.get_node("AddStat").get_children():
		button.disabled = (PlayerStats.stat_points == 0)
	
	for i in range(PlayerStats.INVENTORY_SIZE):
		var slot = status_panel.get_node("Inventory").get_child(i)
		if PlayerStats.inventory[i] != null:
			slot.disabled = false
			slot.visible = true
			slot.texture_normal = Res.get_item_texture(PlayerStats.inventory[i].id)
			slot.get_node("Amount").text = str(PlayerStats.inventory[i].stack)
		else:
			slot.disabled = true
			slot.visible = false
			
	for i in range(PlayerStats.equipment.size()):
		var slot = status_panel.get_node("Equipment").get_child(i)
		if PlayerStats.equipment[i] > -1:
			slot.visible = true
			slot.texture = Res.get_item_texture(PlayerStats.equipment[i])
		else:
			slot.visible = false
	
	for i in range(skill_panel.get_node("Icons").get_child_count()):
		var icon = skill_panel.get_node("Icons").get_child(i)
		
		if i < SkillBase.acquired_skills.size():
			icon.visible = true
			icon.texture = Res.get_skill_texture(SkillBase.acquired_skills[i])
		else:
			icon.visible = false

func on_add_stat(stat):
	PlayerStats[stat.to_lower()] += 1
	SkillBase.inc_stat(stat)
	PlayerStats.stat_points -= 1
	
	PlayerStats.recalc_stats()
	refresh()

func on_inventory_click(i):
	var item = Res.items[PlayerStats.inventory[i].id]
	
	if item.type == "consumable":
		Res.play_sample(player, "Consume", false)
		PlayerStats.inventory[i] = null
		PlayerStats.health += item.health
		refresh()
	else:
		var slot = PlayerStats.EQUIPMENT_SLOTS.find(item.type)
		
		if slot > -1:
			var old = null
			if PlayerStats.equipment[slot] > -1: old = PlayerStats.equipment[slot]
			PlayerStats.equipment[slot] = item.id
			
			if old != null: PlayerStats.inventory[i] = {"id": old, "stack": 1}
			else: PlayerStats.inventory[i] = null
			
			if slot == 3:
				player.update_weapon()
		refresh()

func over_skill_icon(i):
	skill_panel.get_node("SkillName").visible = true
	skill_panel.get_node("SkillName").rect_position = get_viewport().get_mouse_position() - $Tabs.rect_position
	skill_panel.get_node("SkillName/Label").text = SkillBase.acquired_skills[i]#Res.skills[SkillBase.acquired_skills[i]].name

func out_skill_icon(i):
	skill_panel.get_node("SkillName").visible = false

func new_skill(skill):
	Res.play_sample(player, "SkillAcquired", false)
	$"SkillAcquiredPanel".visible = true
	$"SkillAcquiredPanel/Name".text = skill
	skill_time = SKILL_TIMEOUT
	
func level_up():
	Res.play_sample(player, "LevelUp", false)
	$LevelUpLabel.visible = true
	yield(get_tree().create_timer(1), "timeout")
	$LevelUpLabel.visible = false
	
func new_floor(f):
	if f > 0: $FloorLabel.text = "F" + str(f)
	elif f < 0: $FloorLabel.text = str(f) + "B"
	else: $FloorLabel.text = "GF"
	
	$FloorLabel.visible = true
	yield(get_tree().create_timer(1), "timeout")
	$FloorLabel.visible = false

func got_item(id):
	$ItemGetPanel/Name.text = Res.items[id].name
	$ItemGetPanel.visible = true
	yield(get_tree().create_timer(1), "timeout")
	$ItemGetPanel.visible = false

func initiate_dialogue(script):
	if !on_dialogue:
		get_tree().paused = true
		player.get_node("Interact").visible = false
		$DialogueBox.visible = true
		
		$DialogueManager.dialogue(script)

func dialogue_finished():
	get_tree().paused = false
	$DialogueBox.visible = false
	on_dialogue = null

func start_dialogue(_dialogue):
	dialogue_status = {branch = 0, message = 0, dialogue = _dialogue}
	next_message()

func next_message():
	if dialogue_status.message >= dialogue_status.dialogue[dialogue_status.branch].messages.size():
		dialogue_finished()
		return
	
	var dialogue = dialogue_status.dialogue[dialogue_status.branch].messages[dialogue_status.message]
	on_dialogue = dialogue
	
	$DialogueBox/Name/Label.text = dialogue.speaker
	$DialogueBox/Text.text = dialogue.message
	
	if dialogue.has("choices"):
		dialogue_status.message = 0
		$DialogueBox/Chooser.visible = true
		$DialogueBox/Chooser.rect_position.y = CHOOSER_BASE_Y
		dialogue.choice = 0
		
		for choice in dialogue.choices: $DialogueBox/Text.text = $DialogueBox/Text.text + "\n   " + choice
	else:
		dialogue_status.message += 1
		$DialogueBox/Chooser.visible = false

func open_shop(name, items):
	get_tree().paused = true
	$Shop.visible = true
	$Shop/Name.text = name
	shop = items
	
	refresh_shop()

func refresh_shop():
	$Shop/Money/Amount.text = str(PlayerStats.money)
	
	for i in range($Shop/ShopItems.get_child_count()):
		var slot = $Shop/ShopItems.get_child(i)
		
		if i < shop.size():
			slot.disabled = false
			slot.visible = true
			slot.texture_normal = Res.get_item_texture(shop[i])
		else:
			slot.disabled = true
			slot.visible = false
	
	for i in range(PlayerStats.INVENTORY_SIZE):
		var slot = $Shop/InventoryItems.get_child(i)
		if PlayerStats.inventory[i]:
			slot.visible = true
			slot.texture = Res.get_item_texture(PlayerStats.inventory[i].id)
		else:
			slot.visible = false

func on_buy(i):
	var item = Res.items[shop[i]]
	
	if PlayerStats.money >= item.price and PlayerStats.add_item(item.id):
		Res.play_sample(player, "Buy", false)
		PlayerStats.money -= item.price
		refresh_shop()
	else:
		Res.play_sample(player, "Buzzer", false)

func over_shop(i):
	$Shop/PriceTag.visible = true
	$Shop/PriceTag.rect_position = get_viewport().get_mouse_position() - $Shop.rect_position
	$Shop/PriceTag/Amount.text = str(Res.items[shop[i]].price)

func out_shop(i):
	$Shop/PriceTag.visible = false