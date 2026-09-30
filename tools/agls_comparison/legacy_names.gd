extends RefCounted
## Frontier-specific action names. Source identities live in Animation metadata and the manifest.
const CLIPS := {
	"ALSv2_Mantle_2m_Walking_01": "frontier_legacy_mantle_idle",
	"ALSv2_Mantle_2m_Walking_02": "frontier_legacy_mantle_run",
	"LMv2_Movement_Up_01": "frontier_legacy_ladder_up",
	"LMv2_Movement_Down_01": "frontier_legacy_ladder_down",
	"LMv2_Exit_Ladder_Up_01": "frontier_legacy_ladder_exit_top",
	"LMv2_Enter_Ladder_Down_01": "frontier_legacy_ladder_mount_top",
	"CMC_Climb_Hanging_Idle_Loop": "frontier_legacy_ledge_idle",
	"CMC_Shimmy_Long_LH_U": "frontier_legacy_climb_up",

	"ALS_CLF_Walk_F": "frontier_legacy_crouch_walk_forward",
	"ALS_CLF_Walk_B": "frontier_legacy_crouch_walk_backward",
	"ALS_CLF_Walk_L": "frontier_legacy_crouch_walk_left",
	"ALS_CLF_Walk_R": "frontier_legacy_crouch_walk_right",
	"ALS_Props_Bow_Aim_Sweep": "frontier_legacy_bow_aim",
	"ALS_Props_Bow_Aim_Sweep_Crouched": "frontier_legacy_bow_aim_crouch",
	"ALS_Props_RecurveBow_Draw_Stand": "frontier_legacy_bow_draw",
	"ALS_Props_RecurveBow_Draw_Crouch": "frontier_legacy_bow_draw_crouch",
	"ALS_Props_RecurveBow_Recoil": "frontier_legacy_bow_release",
	"ALS_Props_Bow_Sheath_Stand": "frontier_legacy_bow_sheath",
	"ALS_Props_Bow_Sheath_Crouch": "frontier_legacy_bow_sheath_crouch",
	"ALS_Props_Rifle_Aim_Sweep": "frontier_legacy_rifle_aim",
	"ALS_Props_Rifle_Aim_Sweep_Crouched": "frontier_legacy_rifle_aim_crouch",

	"ALS_N_Walk_F": "frontier_legacy_walk_forward",
	"ALS_N_Walk_B": "frontier_legacy_walk_backward",
	"ALS_N_Walk_LF": "frontier_legacy_walk_left",
	"ALS_N_Walk_RF": "frontier_legacy_walk_right",
	"ALS_N_Run_F": "frontier_legacy_run_forward",
	"ALS_N_Run_B": "frontier_legacy_run_backward",
	"ALS_N_Run_LF": "frontier_legacy_run_left",
	"ALS_N_Run_RF": "frontier_legacy_run_right",
	"ALS_N_Sprint_F": "frontier_legacy_sprint_forward",
	"ALSv2_JumpSeq_Idle": "frontier_legacy_jump",
	"ALSv2_N_Vault_1m_LH": "frontier_legacy_vault_left_hand",
	"ALSv2_N_Vault_1m_RH": "frontier_legacy_vault_right_hand"
}
