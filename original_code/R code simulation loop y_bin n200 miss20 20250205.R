#binary outcome

#run missMERF V1.R code file first


# Load required libraries
library(jomo)
library(mice)
library(miceadds)
library(micemd)
library(missForest)
library(VIM)       
library(missRanger)
library(dplyr)
library(naniar)
library(visdat)
library(lme4)
library(performance)
library(ggplot2)
library(tidyr)
library(pROC)
library(mixgb)
#install.packages("mixgb")


set.seed(20)

# Simulation parameters
n_sim <- 1000
n_subj <- 200
n_time <- 5
n_total <- n_subj * n_time  # Total observations
missing_prob <- 0.2



simulate = function(n_subj, n_time, missing_prob, type, meth){
  #generate Data
  data = gen_data(n_subj, n_time, missing_prob, type)
  
  #Run Model 
  t1 <- Sys.time()
  df_out = fit_model(meth, data)
  t2 <- Sys.time()
  
  #evaluate model 
  res <- evaluate(df_out, complete_data, meth, as.numeric(difftime(t2, t1, units="secs")))
  
  res
}
simulate(n_subj=n_subj, n_time=n_time, missing_prob=missing_prob, type="bin", meth="mixgb")








##################analyze results

# Summarize results
summary_results <- results %>%
  group_by(method) %>%
  summarise(across(everything(), mean, na.rm = TRUE))

print(summary_results)

summary_results1 <- results %>%
  group_by(method) %>%
  summarise(across(everything(), sd, na.rm = TRUE))

print(summary_results1)

dim(results)
names(results)

#boxplots of the metrics by method

# Convert data from wide to long format
results$model_auc<-as.numeric(results$model_auc)
results$diff_auc<-as.numeric(results$diff_auc)
df_long <- results %>%
  pivot_longer(cols = -method, names_to = "metric", values_to = "value")

# Define metric groups
metrics_set1 <- c("mse", "mae", "bias", "pfc", "time")
metrics_set2 <- c("model_mse", "model_mae", "model_bias", "model_aic", "model_auc")
metrics_set3 <- c("diff_mse", "diff_mae", "diff_bias", "diff_aic", "diff_auc")

# First plot: MSE, MAE, Bias, PFC, Time
plot1 <- ggplot(df_long %>% filter(metric %in% metrics_set1), aes(x = method, y = value, fill = method)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.7) +  # Transparent boxes, no outliers
  geom_jitter(width = 0.2, alpha = 0.2) +  # Adds jittered points
  facet_wrap(~ metric, scales = "free_y") +  # Facet by metric, allow different scales
  labs(title = "Imputation Performance Metrics: MSE, MAE, Bias, PFC, Time",
       x = "Imputation Method",
       y = "Value") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), 
        legend.position = "none", 
        strip.text = element_text(face = "bold"))

# Second plot: Model MSE, Model MAE, Model Bias, Model AIC, Model AUC
plot2 <- ggplot(df_long %>% filter(metric %in% metrics_set2), aes(x = method, y = value, fill = method)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.7) +  
  geom_jitter(width = 0.2, alpha = 0.2) +  
  facet_wrap(~ metric, scales = "free_y") +  
  labs(title = "Model Evaluation Metrics: MSE, MAE, Bias, AIC, AUC",
       x = "Imputation Method",
       y = "Value") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), 
        legend.position = "none", 
        strip.text = element_text(face = "bold"))

# Third plot: Difference between Imputed Model and Complete Model: MSE, MAE, Bias, AIC, AUC
plot3 <- ggplot(df_long %>% filter(metric %in% metrics_set3), aes(x = method, y = value, fill = method)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.7) +  
  geom_jitter(width = 0.2, alpha = 0.2) +  
  facet_wrap(~ metric, scales = "free_y") +  
  labs(title = "Difference Between Imputed and Complete Data Models: MSE, MAE, Bias, AIC, AUC",
       x = "Imputation Method",
       y = "Value") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), 
        legend.position = "none", 
        strip.text = element_text(face = "bold"))


# Print plots
print(plot1)
ggsave("Ybin n200 miss20 Plot 1.jpg", dpi = 300)
print(plot2)
ggsave("Ybin n200 miss20 Plot 2.jpg", dpi = 300)
print(plot3)
ggsave("Ybin n200 miss20 Plot 3.jpg", dpi = 300)



write.csv(results,"Ybin n200 miss20 simulations.csv")



tiff(file="Ybin n200 miss20 Plot 1.tiff", res=100,width=10,height=6, units="in")
print(plot1)
dev.off()

tiff(file="Ybin n200 miss20 Plot 2.tiff", res=100,width=10,height=6, units="in")
print(plot2)
dev.off()

tiff(file="Ybin n200 miss20 Plot 3.tiff", res=100,width=10,height=6, units="in")
print(plot3)
dev.off()

















