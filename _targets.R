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

# Define Simulation dataset
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
#   n_sim = 1000,
#   n_subj = c(200, 500, 1000),
#   n_time = c(5),
#   missing_prob = c(.2, .4),
#   type=c("bin", "continuous")
# ) 

sims <- expand_grid(
  meth = c(
    'mixgb'
  ),
  n_sim = 3,
  n_subj = c(200, 500,1000),
  n_time = c(5),
  missing_prob = c(.2),
  type=c("bin", "continuous")
) 


### Branch resources
branch_resources <- tar_resources(
  future = tar_resources_future(resources = list(n_cores=20))
)

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
      resources=branch_resources,
      memory="transient",
      garbage_collection = T
    )
  ),
  tar_combine(sims_comb, sim[[1]])
)


# simulate(
#   n_sim = sims$n_sim[1],
#   n_subj = sims$n_subj[1],
#   n_time = sims$n_time[1],
#   missing_prob = sims$missing_prob[1],
#   type = sims$type[1],
#   meth = sims$meth[1]
# )
