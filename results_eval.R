#Run Targets (callr_function==NULL required to run parallell within the simulation loop for a target)
tar_make(callr_function = NULL, reporter="summary")

#Load targets
tar_load("sims_comb")
sims_comb



# with_progress({
#   simulate(
#     n_sim = 40,
#     n_subj = sims$n_subj[4],
#     n_time = sims$n_time[4],
#     missing_prob = sims$missing_prob[4],
#     type = "continuous",
#     meth = "mixgb"
#   )
# })

# 
# simulate_old(
# n_sim = 5,
# n_subj = sims$n_subj[4],
# n_time = sims$n_time[4],
# missing_prob = sims$missing_prob[4],
# type ="continuous",
# meth = "mixgb"
# )
# 
# n_sim = 5
# n_subj = sims$n_subj[4]
# n_time = sims$n_time[4]
# missing_prob = sims$missing_prob[4]
# type ="bin"
# meth = "jomo"



