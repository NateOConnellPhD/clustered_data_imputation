
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

fit_model <- function(meth, data) {
  if (!meth %in% names(methods_list)) {
    stop("Unknown method: ", meth)
  }
  df_out <- methods_list[[meth]](data)
  return(df_out)
}