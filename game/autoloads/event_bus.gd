extends Node
## Global event bus for decoupled communication between systems.

signal score_changed(new_score: int)
signal notification_requested(message: String)
signal damage_dealt(world_position: Vector2, amount: int, is_critical: bool)
signal health_changed(current: int, maximum: int)
signal interaction_prompt_show(target: Node2D, action_name: String)
signal interaction_prompt_hide()