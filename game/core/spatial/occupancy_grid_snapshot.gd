class_name GopalaOccupancyGridSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var configured: bool
var occupancy_sequence: int
var bounds_summary: Dictionary
var claim_count: int
var reserved_cell_count: int
var occupied_cell_count: int
var claims: Array[Dictionary]

func _init(p_configured: bool, p_seq: int, p_bounds: Dictionary, p_claim_count: int, p_res_count: int, p_occ_count: int, p_claims: Array[Dictionary]) -> void:
	configured = p_configured
	occupancy_sequence = p_seq
	bounds_summary = GopalaPlainData.copy_dictionary(p_bounds)
	claim_count = p_claim_count
	reserved_cell_count = p_res_count
	occupied_cell_count = p_occ_count
	var copied = GopalaPlainData.copy_value(p_claims) as Array
	claims.assign(copied)

func to_plain_data() -> Dictionary:
	return GopalaPlainData.copy_dictionary({
		"schema_version": SCHEMA_VERSION,
		"configured": configured,
		"occupancy_sequence": occupancy_sequence,
		"bounds_summary": bounds_summary,
		"claim_count": claim_count,
		"reserved_cell_count": reserved_cell_count,
		"occupied_cell_count": occupied_cell_count,
		"claims": claims
	})
