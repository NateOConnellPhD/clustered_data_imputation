#Run Targets (callr_function==NULL required to run parallell within the simulation loop for a target)
tar_make(callr_function = NULL, reporter="summary")

#Load targets
tar_load("sims_comb")
sims_comb

