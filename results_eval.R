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



plot_metrics(df_long, metric_set=2, type="bin", n_subj=200, miss_prob = .2)

plot_metrics(df_long, metric_set=3, type="bin", n_subj=200, miss_prob = .4)


# Tabulate Metrics
tab_metrics(sims_comb, c("mse", "mae", "bias", "pfc"), list(type=c("bin"),
                                                           n_subj=c("200", "500", "1000"),
                                                           miss_prob = c("0.2", "0.4")))

tab_metrics(sims_comb, c("mse", "mae", "bias", "pfc"), list(type=c("continuous"),
                                                            n_subj=c("200", "500", "1000"),
                                                            miss_prob = c("0.2", "0.4")))

tab_metrics(sims_comb, c("diff_mse", "diff_mae", "diff_bias", "diff_aic",  "diff_auc"), list(type=c("bin"),
                                                            n_subj=c("200", "500", "1000"),
                                                            miss_prob = c("0.2", "0.4")))

tab_metrics(sims_comb, c("diff_mse", "diff_mae", "diff_bias", "diff_aic", "diff_r2"), list(type=c("continuous"),
                                                                                                       n_subj=c("200", "500", "1000"),
                                                                                                       miss_prob = c("0.2", "0.4")))

                  