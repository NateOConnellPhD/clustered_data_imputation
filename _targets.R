## Load your packages, e.g. library(targets).
source("R/functions.R")

#Define Methods List of methods to run
# Define a list of method functions
methods_list <- list(
  mixgb = fit_mixgb,
  jomo = fit_jomo,
  merf = fit_missMERF,
  mice_freq = fit_miceFreq,
  mice_bayes = fit_miceBayes,
  mice_pmm = fit_micePMM,
  missforest = fit_missForest, 
  knn = fit_knn,
  missranger = fit_missRanger
)

#Define Simulation dataset
sims <- expand_grid(
  meth = c(
    'mixgb',
    'jomo',
    'merf',
    'mice_freq',
    'mice_bayes',
    'mice_pmm',
    'missforest',
    'knn',
    "missranger"
  ),
  n_sim = 1000,
  n_subj = c(200, 500, 1000),
  n_time = c(5),
  missing_prob = c(.2, .4),
  type=c("bin", "continuous")
)

# sims <- expand_grid(
#   meth = c(
#     'mixgb',
#     'jomo',
#     'merf',
#     'mice_freq',
#     'mice_bayes',
#     'mice_pmm',
#     'missforest',
#     'knn',
#     "missranger"
#   ),
#   n_sim = 2,
#   n_subj = c(500),
#   n_time = c(5),
#   missing_prob = c(.2),
#   type=c("bin")
# )


# ## Branch resources
# branch_resources <- tar_resources(
#   future = tar_resources_future(resources = list(n_cores=20))
# )


#tar plan
tar_plan(
  sim <- tar_map(
    values=sims,
    names=c(meth, n_subj, missing_prob, type),
    tar_target(
      sim,
      simulate(
        n_sim = n_sim,
        n_subj = n_subj,
        n_time = n_time,
        missing_prob = missing_prob,
        type = type,
        meth = meth
      ),
      memory="transient",
      garbage_collection = T
    )
  ),
  tar_combine(sims_comb, sim[[1]])
)


#tar_poll(interval = 5)  # Update every 5 seconds [1, 2, 3] 



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

  
