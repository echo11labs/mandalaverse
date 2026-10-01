extends Node

# Global Event Bus for UI updates
# This decouples the game logic from the UI rendering

# Emitted by game logic when resources change
signal resource_updated(resource_type: String, new_amount: int)

# Emitted by game logic when objectives progress
signal objective_progressed(objective_id: String, current: int, max_val: int)

# Emitted by the UI when a building is selected to be built
signal build_action_requested(building_id: String)

# Emitted to log a new event message in the bottom-left event log

signal event_logged(message: String)
