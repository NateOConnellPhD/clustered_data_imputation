## Load your packages, e.g. library(targets).
lapply(list.files("R/", pattern = "\\.R$", full.names = TRUE), source)

#Define Simulation dataset
sims_50 <- expand_grid(
  meth = c(
    'mixgb',
    'jomo',
    'merf',
    'mice_freq',
    #'mice_bayes',
    'mice_pmm',
    'missforest',
    'knn',
    "missranger"
  ),
  n_sim = 50,
  n_subj = c(200, 500, 1000),
  n_time = c(5),
  missing_prob = c(.2, .4),
  type=c("bin", "continuous"),
  start_iter=1
)

sims_950 <- sims_50 %>% mutate(start_iter = n_sim+1, n_sim=950)  # Start from 101

# ## Branch resources
# branch_resources <- tar_resources(
#   future = tar_resources_future(resources = list(n_cores=20))
# )


# #tar plan
# tar_plan(
#   sim <- tar_map(
#     values=sims,
#     names=c(meth, n_subj, missing_prob, type),
#     tar_target(
#       sim,
#       simulate(
#         n_sim = n_sim,
#         n_subj = n_subj,
#         n_time = n_time,
#         missing_prob = missing_prob,
#         type = type,
#         meth = meth
#       ),
#       memory="transient",
#       garbage_collection = T
#     )
#   ),
#   tar_combine(sims_comb, sim[[1]])
# )

tar_plan(
  # First batch (1-100)
  sim_50 <- tar_map(
    values = sims_50,
    names = c(meth, n_subj, missing_prob, type, start_iter),
    tar_target(
      sim,
      simulate(
        n_sim = n_sim,
        n_subj = n_subj,
        n_time = n_time,
        missing_prob = missing_prob,
        type = type,
        meth = meth,
        start_iter = 1
      ),
      memory = "transient",
      garbage_collection = TRUE
    )
  ),
  
  # Combine all first 100 runs
  sims_50_comb <- tar_combine(
    sims_50_comb,
    sim_50[[1]],
    command = dplyr::bind_rows(!!!.x)  # Use bind_rows for correct row binding
  ),
  
  # Second batch (101-200), appending results
  sim_950 <- tar_map(
    values = sims_950,
    names = c(meth, n_subj, missing_prob, type),
    tar_target(
      sim_new,
      {
        prev_results <- tryCatch(tar_read(sim_100), error = function(e) NULL)
        new_results <- simulate(
          n_sim = n_sim,
          n_subj = n_subj,
          n_time = n_time,
          missing_prob = missing_prob,
          type = type,
          meth = meth,
          start_iter = 101  # Start from 101
        )
        if (!is.null(prev_results)) {
          bind_rows(prev_results, new_results)
        } else {
          new_results
        }
      },
      memory = "transient",
      garbage_collection = TRUE
    )
  ),

  # Combine all second 100 runs
  sims_950_comb <- tar_combine(
    sims_950_comb,
    sim_950[[1]],
    command = dplyr::bind_rows(!!!.x)
  ),

  sims_comb <- tar_combine(
    sims_comb,
    list(sims_50_comb, sims_950_comb),
    command = dplyr::bind_rows(!!!.x)
  )
)



