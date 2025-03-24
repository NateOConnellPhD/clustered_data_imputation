# Plot Metrics function 
# df_long: data frame in long format of results. 
# metric_set: specify 1, 2, or 3 for different plots
# type: bin or continuous
# n_subj: 200, 500, or 1000
# miss_prob: 0.2 or 0.4


plot_metrics <- function(df_long, metric_set=1, type="bin", n_subj=200, miss_prob=.2) {
  # Define metric sets
  metrics_list <- list(
    "bin" = list(
      c("mse",  "bias", "pfc", "time"),
      c("model_mse", "model_bias", "model_aic", "model_auc"),
      c("diff_mse",  "diff_bias", "diff_aic", "diff_auc")
    ),
    "continuous" = list(
      c("mse",  "bias", "pfc", "time"),
      c("model_mse", "model_bias", "model_aic", "model_r2"),
      c("diff_mse",  "diff_bias", "diff_aic", "diff_r2")
    )
  )
  
  # Validate inputs
  if (!(type %in% names(metrics_list))) stop("Invalid type. Choose 'bin' or 'continuous'.")
  if (!(metric_set %in% c(1, 2, 3))) stop("Invalid metric_set. Choose 1, 2, or 3.")
  
  # Select the correct metric set
  selected_metrics <- metrics_list[[type]][[metric_set]]
  
  # Filter data
  df_filtered <- df_long %>%
    filter(metric %in% selected_metrics,
           type == !!type, 
           n_subj == !!n_subj, 
           miss_prob == !!miss_prob)
  
  type_name = ifelse(type=="bin", "Binary", "Continuous")
  
  # Generate plot
  plot <- ggplot(df_filtered, aes(x = method, y = value, fill = method)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7) +  # Transparent boxes, no outliers
    #geom_jitter(width = 0.2, alpha = 0.02) +  # Adds jittered points
    #geom_violin(alpha = 0.15, scale = "width")+
    ggdist::stat_dots(side = "both", dotsize = 0.5, alpha = 0.25)+
    facet_wrap(~ metric, scales = "free_y") +  # Facet by metric, allow different scales
    labs(title = paste("Metrics for", type_name, "Data (n =", n_subj, ", missing prob =", miss_prob, ")"),
         x = "Imputation Method",
         y = "Value") +
    #theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1), 
          legend.position = "none", 
          strip.text = element_text(face = "bold"))+
    theme(
      panel.grid.major = element_line(color = "grey80"),
      panel.grid.minor = element_line(color = "grey90"),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none",
      strip.text = element_text(face = "bold")
    )
  
  return(plot)
}
