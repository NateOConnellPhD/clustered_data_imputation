#Run Targets (callr_function==NULL required to run parallell within the simulation loop for a target)
#tar_make(callr_function = NULL, reporter="summary")

#Load functions
lapply(list.files("R/", pattern = "\\.R$", full.names = TRUE), source)

#Load targets
tar_load("sims_comb")



# Summarize results
summary_results <- sims_comb %>%
  group_by(method, type, n_subj, miss_prob) %>%
  summarise(across(everything(), mean, na.rm = TRUE))


summary_results1 <- sims_comb %>%
  group_by(method, type, n_subj, miss_prob) %>%
  summarise(across(everything(), sd, na.rm = TRUE))


# Convert data from wide to long format
df_long <- sims_comb %>%
  pivot_longer(cols = -c(method, type, n_subj, miss_prob), names_to = "metric", values_to = "value")

plot_metrics(df_long, metric_set=1, type="bin", n_subj=200, miss_prob = .2)

