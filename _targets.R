## Load your packages, e.g. library(targets).
lapply(list.files("R/", pattern = "\\.R$", full.names = TRUE), source)

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


