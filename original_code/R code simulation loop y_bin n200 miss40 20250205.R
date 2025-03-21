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
missing_prob <- 0.4

# Storage for evaluation metrics
results <- data.frame(method = character(),
                      mse = numeric(),
                      mae = numeric(),
                      bias = numeric(),
                      pfc = numeric(),
			    model_mse = numeric(),
			    model_mae = numeric(),
			    model_bias = numeric(),
			    model_aic = numeric(),
			    model_auc = numeric(),
			    diff_mse = numeric(),
			    diff_mae = numeric(),
			    diff_bias = numeric(),
			    diff_aic = numeric(),
			    diff_auc = numeric(),
                      time = numeric())

# Function to evaluate imputation quality
  evaluate <- function(imputed_data, complete_data, method, time_taken) {
    sse <- (imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])^2
    mse <- mean(rbind(sse$X1,sse$X2,sse$X3))
    sae <- abs(imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])
    mae <- mean(rbind(sae$X1,sae$X2,sae$X3))
    ssb <- (imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])
    bias <- mean(rbind(ssb$X1,ssb$X2,ssb$X3))

    #make binary variables as numerics for calculation of pfc
    Bn_imp <- imputed_data[missing_vars_bin]
    Bn_imp$B1 <- as.numeric(Bn_imp$B1)-1
    Bn_imp$B2 <- as.numeric(Bn_imp$B2)-1
    Bn_imp$B3 <- as.numeric(Bn_imp$B3)-1
    pfc <- (sum(abs(B1n-Bn_imp$B1))+sum(abs(B2n-Bn_imp$B2))+sum(abs(B3n-Bn_imp$B3)))/(3*n_total)

    #use mixed model on the imputed data and calculate performance characteristics
    model_impdata<-suppressWarnings(glmer(Y~scale(age)+sex+race+scale(X1)+scale(X2)+scale(X3)+B1+B2+B3+(1|id),data=imputed_data,binomial))
    y_pred<-predict(model_impdata,type="response",re.form=NULL,allow.new.levels=TRUE)
    y_true<-as.numeric(imputed_data$Y)-1
    model_mse <- mean((y_true - y_pred)^2)
    model_mae <- mean(abs(y_true - y_pred))
    model_bias <- mean(y_true - y_pred)
    model_aic <- AIC(model_impdata)
    model_auc <- pROC::roc(y_true,y_pred)$auc

    #complete data metrics
    model_complete<-suppressWarnings(glmer(Y~scale(age)+sex+race+scale(X1)+scale(X2)+scale(X3)+B1+B2+B3+(1|id),data=complete_data,binomial))
    y_pred_complete<-predict(model_complete,type="response",re.form=NULL,allow.new.levels=TRUE)
    complete_model_mse <- mean((y_true - y_pred_complete)^2)
    complete_model_mae <- mean(abs(y_true - y_pred_complete))
    complete_model_bias <- mean(y_true - y_pred_complete)
    complete_model_aic <- AIC(model_complete)
    complete_model_auc <- pROC::roc(y_true,y_pred_complete)$auc

    #compute difference between imputed and complete data model metrics
    diff_mse <- model_mse - complete_model_mse
    diff_mae <- model_mae - complete_model_mae
    diff_bias <- model_bias - complete_model_bias
    diff_aic <- model_aic - complete_model_aic
    diff_auc <- model_auc - complete_model_auc


    return(data.frame(method, mse, mae, bias, pfc, model_mse, model_mae, model_bias, model_aic, model_auc, time = time_taken,
		diff_mse, diff_mae, diff_bias, diff_aic, diff_auc))
  }
  


# Simulation loop
for (sim in 1:n_sim) {
  
  # Generate subject IDs
  id <- rep(1:n_subj, each = n_time)
  
  # Generate fixed predictors (age, sex, race)
  age <- rnorm(n_subj, mean = 50, sd = 10)
  sex <- rbinom(n_subj, 1, 0.5)  # 0 = Female, 1 = Male
  race <- sample(1:3, n_subj, replace = TRUE)  # 3 categories
  
  # Repeat fixed predictors for repeated measures
  age <- rep(age, each = n_time)
  sex <- rep(sex, each = n_time)
  race <- rep(race, each = n_time)
  
  # Generate continuous predictors with X2 and X3 having 0.5 correlation 
  X1 <- rbeta(n_total, 2, 5)
  X2 <- rnorm(n_total, mean = 0, sd = 1)
  X3 <- (0.5 * X2 + sqrt(1 - 0.5^2) * rnorm(n_total, mean = 0, sd = 1)) 

  #Generate junk variables not related to outcome
  JX1 <- rnorm(n_total, mean = 6, sd = 3)
  JX2 <- rnorm(n_total, mean = 2, sd = 2)
  JB1 <- as.factor(rbinom(n_total, 1, 0.25))
  JB2 <- as.factor(rbinom(n_total, 1, 0.35))

  # Generate binary predictors
  B1 <- as.factor(rbinom(n_total, 1, 0.5))
  B2 <- as.factor(rbinom(n_total, 1, 0.4))
  B3 <- as.factor(rbinom(n_total, 1, 0.3))
  B1n <- as.numeric(B1)-1
  B2n <- as.numeric(B2)-1
  B3n <- as.numeric(B3)-1
  
  # Generate binary outcome (random effects model)
  subj_effect <- rnorm(n_subj, mean = 0, sd = 1)
  Y_mod <- 2 + 0.5*X1 - 0.3*X2 + 0.8*X3 + 1.2*B1n - 0.5*B2n + 0.7*B3n +
       0.4*age - 0.6*sex + 0.3*race + subj_effect[id] + rnorm(n_total, sd = 1)
  Y_prob <- exp(scale(Y_mod)) / (exp(scale(Y_mod)) + 1)
  Y <- as.factor(rbinom(n_total,1,Y_prob))
  
  # Combine into a data frame
  data <- data.frame(id, age, sex, race, X1, X2, X3, B1, B2, B3, Y, JX1, JX2, JB1, JB2)
  complete_data <- data  # Store complete data for evaluation
  
  # Induce MAR missingness based on age, JX1 and JB1
  missing_vars <- c("X1", "X2", "X3", "B1", "B2", "B3")
  missing_vars_cont <- c("X1", "X2", "X3")
  missing_vars_bin <- c("B1", "B2", "B3")
  
  for (var in missing_vars) {
    mod <- scale(3 * age - 1.7 * JX1 - 1.2 * (as.numeric(JB1)-1))
    rp <- exp(mod) / (exp(mod) + 1)
    prob_missing <- pnorm(scale(rp))
    missing_indices <- which(runif(n_total) < prob_missing * missing_prob * 2)
    data[[var]][missing_indices] <- NA
  }
#print(miss_var_summary(data))

  # Store results
  res <- list()

  # mixgb R package (XGBoost)
  t1 <- Sys.time()
  imp_mixgb <- mixgb(data, m = 1, maxit = 10)
  data_mixgb <- data.frame(complete(imp_mixgb[[1]]))
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_mixgb, complete_data, "mixgb", as.numeric(difftime(t2, t1, units="secs"))))

  # JOMO (Mixed-Effects Multiple Imputation)
  t1 <- Sys.time()
  data_impute_vars<-data.frame(data[, missing_vars])
  data_complete_vars<-data.frame(cbind(1, data$age, data$sex, data$race, data$Y, data$JX1, 
	data$JX2, as.factor(data$JB1), as.factor(data$JB2)))
  colnames(data_complete_vars)<-c("intercept","age","sex","race","Y","JX1","JX2","JB1","JB2")
  data_complete_vars$JB1<-as.factor(data_complete_vars$JB1)
  data_complete_vars$JB2<-as.factor(data_complete_vars$JB2)
  z <- cbind(reInt = rep(1,n_total))
  imp_jomo <- jomo(Y = data_impute_vars, X = data_complete_vars, Z=z, clus = data$id, nimp = 1, nbetween = 200, nburn = 3000)
  data_jomo_out <-  imp_jomo[imp_jomo$Imputation == 1, ]
  data_jomo<- data.frame(as.numeric(data_jomo_out$clus),data_jomo_out$age,data_jomo_out$sex,data_jomo_out$race,
	data_jomo_out$X1,data_jomo_out$X2,data_jomo_out$X3,data_jomo_out$B1,data_jomo_out$B2,data_jomo_out$B3,
	as.factor(data_jomo_out$Y-1), data_jomo_out$JX1,data_jomo_out$JX2, as.factor(data_jomo_out$JB1-1), as.factor(data_jomo_out$JB2-1))
  colnames(data_jomo)<-names(data)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_jomo, complete_data, "jomo", as.numeric(difftime(t2, t1, units="secs"))))

  # missMERF (Fast Random Forest with  mixed effects model)
  t1 <- Sys.time()
  data_missMERF <- missMERF(data, cluster_id = data$id, pmm.k = 5, num.trees = 100, maxiter = 10)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_missMERF, complete_data, "missMERF", as.numeric(difftime(t2, t1, units="secs"))))

  # MICE (Fully Conditional Specification): Frequentist method for mixed model
  t1 <- Sys.time()
  # "empty" imputation as a template
  imp0 <- mice(data, maxit=0)
  pred1 <- imp0$predictorMatrix
  meth1 <- imp0$method
  # set imputation methods for the variables with missing values
  meth1[c("X1","X2","X3")] <- "2l.pan"
  meth1[c("B1","B2","B3")] <- "2l.bin"
  # set predictor matrix: 0=don't use, 1=fixed effect, -2=cluster variable
  pred1[,"id"] <- -2 
  #pred1[,"X1"] <- c(2,2,2,2,0,2,2,2,2,2,2)
  #pred1[,"X2"] <- c(2,2,2,2,2,0,2,2,2,2,2)
  #pred1[,"X3"] <- c(2,2,2,2,2,2,0,2,2,2,2)
  #pred1[,"B1"] <- c(2,2,2,2,2,2,2,0,2,2,2)
  #pred1[,"B2"] <- c(2,2,2,2,2,2,2,2,0,2,2)
  #pred1[,"B3"] <- c(2,2,2,2,2,2,2,2,2,0,2)
  #pred1[,"Y"] <- c(2,2,2,2,2,2,2,2,2,2,0)

  imp_mice <- mice(data, method = meth1, predictorMatrix = pred1, m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_mice, complete_data, "mice_freq", as.numeric(difftime(t2, t1, units="secs"))))

  # MICE (Fully Conditional Specification): Bayesian method for mixed model
  t1 <- Sys.time()
  # "empty" imputation as a template
  imp0 <- mice(data, maxit=0)
  pred1 <- imp0$predictorMatrix
  meth1 <- imp0$method
  # set imputation methods for the variables with missing values
  meth1[c("X1","X2","X3")] <- "2l.glm.norm"
  meth1[c("B1","B2","B3")] <- "2l.jomo"
  # set predictor matrix: 0=don't use, 1=fixed effect, -2=cluster variable
  pred1[,"id"] <- -2 
  #pred1[,"X1"] <- c(2,2,2,2,0,2,2,2,2,2,2)
  #pred1[,"X2"] <- c(2,2,2,2,2,0,2,2,2,2,2)
  #pred1[,"X3"] <- c(2,2,2,2,2,2,0,2,2,2,2)
  #pred1[,"B1"] <- c(2,2,2,2,2,2,2,0,2,2,2)
  #pred1[,"B2"] <- c(2,2,2,2,2,2,2,2,0,2,2)
  #pred1[,"B3"] <- c(2,2,2,2,2,2,2,2,2,0,2)
  #pred1[,"Y"] <- c(2,2,2,2,2,2,2,2,2,2,0)
  imp_mice <- mice(data, method = meth1, predictorMatrix = pred1, m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_mice, complete_data, "mice_bayes", as.numeric(difftime(t2, t1, units="secs"))))

  # MICE (Fully Conditional Specification): PMM
  t1 <- Sys.time()
  imp_mice <- mice(data, method = "pmm", m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_mice, complete_data, "mice_pmm", as.numeric(difftime(t2, t1, units="secs"))))

  # MissForest (Random Forest)
  t1 <- Sys.time()
  imp_missForest <- missForest(data)
  data_mf <- imp_missForest$ximp
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_mf, complete_data, "missForest", as.numeric(difftime(t2, t1, units="secs"))))

  # kNN Imputation
  t1 <- Sys.time()
  imp_knn <- kNN(data, variable = missing_vars, k = 5)
  data_knn <- imp_knn[,1:15]
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_knn, complete_data, "kNN", as.numeric(difftime(t2, t1, units="secs"))))

  # MissRanger (Fast Random Forest)
  t1 <- Sys.time()
  data_missRanger <- missRanger(data, pmm.k = 5, num.trees = 100, maxiter = 10)
  t2 <- Sys.time()
  res <- rbind(res, evaluate(data_missRanger, complete_data, "missRanger", as.numeric(difftime(t2, t1, units="secs"))))

  # Store results
  results <- rbind(results, res)
  res <- NA

  # Print progress
  if (sim %% 10 == 0) {
    cat("Simulation", sim, "completed\n")
  }
}










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
ggsave("Ybin n200 miss40 Plot 1.jpg", dpi = 300)
print(plot2)
ggsave("Ybin n200 miss40 Plot 2.jpg", dpi = 300)
print(plot3)
ggsave("Ybin n200 miss40 Plot 3.jpg", dpi = 300)



write.csv(results,"Ybin n200 miss40 simulations.csv")



tiff(file="Ybin n200 miss40 Plot 1.tiff", res=100,width=10,height=6, units="in")
print(plot1)
dev.off()

tiff(file="Ybin n200 miss40 Plot 2.tiff", res=100,width=10,height=6, units="in")
print(plot2)
dev.off()

tiff(file="Ybin n200 miss40 Plot 3.tiff", res=100,width=10,height=6, units="in")
print(plot3)
dev.off()

















