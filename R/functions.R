#Load Libraries
packs = c("jomo", "mice", "miceadds", "micemd", "missForest", "VIM", "missRanger", "dplyr",
          "naniar", "visdat", "lme4", "performance", "tidyr", "pROC", "mixgb", "NOmisc")
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
library(pROC)
#devtools::install_github("https://github.com/NateOConnellPhD/NOmisc")
library(NOmisc)
library(tarchetypes)
library(targets)
library(future)
library(parallel)
library(furrr)
library(pingr)
library(progressr)

#load missMERF 
source("R/missMERF V1.R")

# Function to evaluate imputation quality
evaluate <- function(imputed_data, complete_data, method, time_taken) {
 

  missing_vars <- c("X1", "X2", "X3", "B1", "B2", "B3")
  missing_vars_cont <- c("X1", "X2", "X3")
  missing_vars_bin <- c("B1", "B2", "B3")
  
  
  # MSE, MAE, and Bias
  sse <- (imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])^2
  mse <- mean(rowMeans(sse))
  
  sae <- abs(imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])
  mae <- mean(rowMeans(sae))
  
  ssb <- (imputed_data[missing_vars_cont] - complete_data[missing_vars_cont])
  bias <- mean(rowMeans(ssb))
  
  # Binary Variable Conversion
  Bn_imp <- imputed_data[missing_vars_bin]
  Bn_imp[] <- lapply(Bn_imp, function(x) as.numeric(x) - 1)
  
  complete_data[c("B1", "B2", "B3")] <- lapply(complete_data[c("B1", "B2", "B3")], function(x) as.numeric(as.character(x)))
  
  # PFC Calculation
  n_total = nrow(complete_data) 
  pfc <- sum(abs(complete_data$B1 - Bn_imp$B1) + abs(complete_data$B2- Bn_imp$B2) + abs(complete_data$B3 - Bn_imp$B3)) / (3 * n_total)
  
  if(is_binary(complete_data$Y)){
    # Control for glmer to improve speed
    ctrl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 10000))
    
    # Model on Imputed Data
    model_impdata <- suppressWarnings(glmer(
      Y ~ scale(age) + sex + race + scale(X1) + scale(X2) + scale(X3) + B1 + B2 + B3 + (1 | id),
      data = imputed_data, family = binomial, control = ctrl
    ))
    
    y_pred <- predict(model_impdata, type = "response", re.form = NULL, allow.new.levels = TRUE)
    y_true <- as.numeric(imputed_data$Y) 
    
    model_mse <- mean((y_true - y_pred)^2)
    model_mae <- mean(abs(y_true - y_pred))
    model_bias <- mean(y_true - y_pred)
    model_aic <- AIC(model_impdata)
    model_auc <- as.numeric(pROC::roc(y_true, y_pred)$auc)
    
    # Complete Data Model (reuse glmer structure)
    #complete_data$Y = complete_data$Y)
    model_complete <- suppressWarnings(glmer(
      Y ~ scale(age) + sex + race + scale(X1) + scale(X2) + scale(X3) + B1 + B2 + B3 + (1 | id),
      data = complete_data, family = binomial, control = ctrl
    ))
    
    y_pred_complete <- predict(model_complete, type = "response", re.form = NULL, allow.new.levels = TRUE)
    complete_model_mse <- mean((y_true - y_pred_complete)^2)
    complete_model_mae <- mean(abs(y_true - y_pred_complete))
    complete_model_bias <- mean(y_true - y_pred_complete)
    complete_model_aic <- AIC(model_complete)
    complete_model_auc <- as.numeric(pROC::roc(y_true, y_pred_complete)$auc)
    
    # Differences between imputed and complete models
    diff_mse <- model_mse - complete_model_mse
    diff_mae <- model_mae - complete_model_mae
    diff_bias <- model_bias - complete_model_bias
    diff_aic <- model_aic - complete_model_aic
    diff_auc <- model_auc - complete_model_auc
    
    return(data.frame(
      method, mse, mae, bias, pfc, 
      model_mse, model_mae, model_bias, 
      model_aic, model_r2 = NA, model_auc, time = time_taken, 
      diff_mse, diff_mae, 
      diff_bias, diff_aic, diff_r2=NA, diff_auc
    ))
    
  } else {
    # Pre-scale numeric predictors outside the model
    imputed_data$age_s <- scale(imputed_data$age)
    imputed_data$X1_s <- scale(imputed_data$X1)
    imputed_data$X2_s <- scale(imputed_data$X2)
    imputed_data$X3_s <- scale(imputed_data$X3)
    
    complete_data$age_s <- scale(complete_data$age)
    complete_data$X1_s <- scale(complete_data$X1)
    complete_data$X2_s <- scale(complete_data$X2)
    complete_data$X3_s <- scale(complete_data$X3)
    
    # Define the formula once
    model_formula <- Y ~ age_s + sex + race + X1_s + X2_s + X3_s + B1 + B2 + B3 + (1 | id)
  
    # Fit models
    model_impdata <- lmer(model_formula, data = imputed_data)
    model_complete <- lmer(model_formula, data = complete_data)
    
    # Get predictions and calculate metrics in a vectorized way
    y_true <- imputed_data$Y
    y_pred <- predict(model_impdata, re.form = NULL)
    y_pred_complete <- predict(model_complete, re.form = NULL)
    
    model_mse <- mean((y_true - y_pred)^2)
    model_mae <- mean(abs(y_true - y_pred))
    model_bias <- mean(y_true - y_pred)
    model_aic <- AIC(model_impdata)
    model_r2 <- r2_nakagawa(model_impdata)$R2_conditional
    
    complete_model_mse <- mean((y_true - y_pred_complete)^2)
    complete_model_mae <- mean(abs(y_true - y_pred_complete))
    complete_model_bias <- mean(y_true - y_pred_complete)
    complete_model_aic <- AIC(model_complete)
    complete_model_r2 <- r2_nakagawa(model_complete)$R2_conditional
    
    # Compute differences
    diff_mse <- model_mse - complete_model_mse
    diff_mae <- model_mae - complete_model_mae
    diff_bias <- model_bias - complete_model_bias
    diff_aic <- model_aic - complete_model_aic
    diff_r2 <- model_r2 - complete_model_r2
    
    # Return results as a data frame
    return(data.frame(
      method, mse, mae, bias, pfc, 
      model_mse, model_mae, model_bias, 
      model_aic, model_r2, model_auc=NA, time = time_taken,
      diff_mse, diff_mae, 
      diff_bias, diff_aic, diff_r2, diff_auc=NA
    ))
    
  }
}

# Generate Data Function 
gen_data = function(n_subj, n_time, missing_prob, type){
  
  n_total  = n_subj * n_time
  
  # Generate subject IDs
  id <- rep.int(1:n_subj, n_time)
  
  # Generate fixed predictors (age, sex, race)
  age <- rep.int(rnorm(n_subj, mean = 50, sd = 10), n_time)
  sex <- rep.int(rbinom(n_subj, 1, 0.5), n_time)  
  race <- rep.int(sample.int(3, n_subj, replace = TRUE), n_time)  
  
  # Generate continuous predictors with X2 and X3 having 0.5 correlation 
  X2 <- rnorm(n_total, mean = 0, sd = 1)
  X1 <- rbeta(n_total, 2, 5)
  X3 <- 0.5 * X2 + sqrt(0.75) * rnorm(n_total)
  
  # Generate junk variables not related to outcome
  JX1 <- rnorm(n_total, mean = 6, sd = 3)
  JX2 <- rnorm(n_total, mean = 2, sd = 2)
  JB1 <- as.factor(rbinom(n_total, 1, 0.25))
  JB2 <- as.factor(rbinom(n_total, 1, 0.35))
  
  # Generate binary predictors and their numeric counterparts
  B1n <- rbinom(n_total, 1, 0.5)
  B2n <- rbinom(n_total, 1, 0.4)
  B3n <- rbinom(n_total, 1, 0.3)
  B1 <- as.factor(B1n)
  B2 <- as.factor(B2n)
  B3 <- as.factor(B3n)
  
  #simulate outcome
  subj_effect <- rnorm(n_subj, mean = 0, sd = 1)
  if(type=="bin"){
    # Generate binary outcome (random effects model)
    Y_mod <- 2 + 0.5*X1 - 0.3*X2 + 0.8*X3 + 1.2*B1n - 0.5*B2n + 0.7*B3n +
      0.4*age - 0.6*sex + 0.3*race + subj_effect[id] + rnorm(n_total, sd = 1)
    Y_prob <- exp(scale(Y_mod)) / (exp(scale(Y_mod)) + 1)
    Y <- as.factor(rbinom(n_total,1,Y_prob))
  } else if(type=="continuous"){
    # Generate continuous outcome (random effects model)
    Y <- 2 + 0.5*X1 - 0.3*X2 + 0.8*X3 + 1.2*B1n - 0.5*B2n + 0.7*B3n +
      0.4*age - 0.6*sex + 0.3*race + subj_effect[id] + rnorm(n_total, sd = 1)
  }
  
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
  
  list(data= data, 
       complete_data=complete_data)
}


## Define methods functions

# mixgb 
fit_mixgb = function(data){
  imp_mixgb <- mixgb(data, m = 1, maxit = 10)
  data_mixgb <- data.frame(complete(imp_mixgb[[1]]))
  return(data_mixgb)
}



# jomo 
fit_jomo = function(data){
  missing_vars <- c("X1", "X2", "X3", "B1", "B2", "B3")
  data_impute_vars<-data.frame(data[, missing_vars])
  data_complete_vars<-data.frame(cbind(1, data$age, data$sex, data$race, data$Y, data$JX1, 
                                       data$JX2, as.factor(data$JB1), as.factor(data$JB2)))
  colnames(data_complete_vars)<-c("intercept","age","sex","race","Y","JX1","JX2","JB1","JB2")
  data_complete_vars$JB1<-as.factor(data_complete_vars$JB1)
  data_complete_vars$JB2<-as.factor(data_complete_vars$JB2)
  n_total = nrow(data_complete_vars)
  z <- cbind(reInt = rep(1,n_total))
  imp_jomo <- jomo(Y = data_impute_vars, X = data_complete_vars, Z=z, clus = data$id, nimp = 1, nbetween = 200, nburn = 3000, output=0)
  data_jomo_out <-  imp_jomo[imp_jomo$Imputation == 1, ]
  if(is_binary(data_jomo_out$Y)) data_jomo_out$Y = as.numeric(as.character(data_jomo_out$Y))-1
  data_jomo <- data.frame(as.numeric(data_jomo_out$clus),data_jomo_out$age,data_jomo_out$sex,data_jomo_out$race,
                         data_jomo_out$X1,data_jomo_out$X2,data_jomo_out$X3,data_jomo_out$B1,data_jomo_out$B2,data_jomo_out$B3,
                        data_jomo_out$Y, data_jomo_out$JX1,data_jomo_out$JX2, as.factor(data_jomo_out$JB1-1), as.factor(data_jomo_out$JB2-1))
  colnames(data_jomo)<-names(data)
  return(data_jomo)
}

# missMERF
fit_missMERF = function(data){
  data_missMERF <- missMERF(data, cluster_id = data$id, pmm.k = 5, num.trees = 100, maxiter = 10)
  return(data_missMERF)
}

# Mice Freq
fit_miceFreq = function(data){
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
  return(data_mice)
}


# Mice Bayes
fit_miceBayes = function(data){
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
  return(data_mice)
}

#Mice PMM
fit_micePMM = function(data){
  imp_mice <- mice(data, method = "pmm", m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  return(data_mice)
}

# Missforest
fit_missForest = function(data){
  imp_missForest <- missForest(data)
  data_mf <- imp_missForest$ximp
  return(data_mf)
}

# KNN
fit_knn = function(data){
  missing_vars <- c("X1", "X2", "X3", "B1", "B2", "B3")
  imp_knn <- kNN(data, variable = missing_vars, k = 5)
  data_knn <- imp_knn[,1:15]
  return(data_knn)
}

#missRanger
fit_missRanger = function(data){
  data_missRanger <- missRanger(data, pmm.k = 5, num.trees = 100, maxiter = 10)
  return(data_missRanger)
}

##### Define Function for running methods based on function input ######
# Fit model function using the methods list
fit_model <- function(meth, data) {
  if (!meth %in% names(methods_list)) {
    stop("Unknown method: ", meth)
  }
  df_out <- methods_list[[meth]](data)
  return(df_out)
}


### Simulate Function
# simulate_old = function(n_sim, n_subj, n_time, missing_prob, type, meth){
# 
#   # Preallocate list for simulation results
#   res <- vector("list", n_sim)
# 
#   # Run the simulation 'n_replications' times
#   for(i in 1:n_sim) {
#     set.seed(1000+i)
# 
#     # Generate Data
#     data = gen_data(n_subj, n_time, missing_prob, type = type)
# 
#     # Run Model
#     t1 <- Sys.time()
#     df_out = fit_model(meth = meth, data = data$data)
#     t2 <- Sys.time()
# 
#     # Evaluate model
#     res[[i]] <- evaluate(df_out, data$complete_data, meth, as.numeric(difftime(t2, t1, units = "secs")))
#     res[[i]]$type = type
#     res[[i]]$iter = i
#     res[[i]]$n_subj = n_subj
#     res[[i]]$miss_prob = missing_prob
# 
#   }
# 
#   # Combine all results into a single data frame
#   out = do.call(rbind, res)
#   rownames(out) = NULL
#   out
# }

# 
# simulate <- function(n_sim, n_subj, n_time, missing_prob, type, meth) {
#   # Load and set the future plan in the worker session.
#   library(future)
#   library(furrr)
#   # Adjust 'workers' to the desired number of cores per target.
#   future::plan(multisession, workers = 20)
# 
#   # Run the simulation n_sim times in parallel using future_map
#   results <- future_map(1:n_sim, function(i) {
#     source("R/missMERF V1.R")
# 
#     # Ensure reproducibility by setting the seed for each iteration
#     set.seed(1000 + i)
# 
#     # Generate Data
#     data <- gen_data(n_subj, n_time, missing_prob, type=type)
# 
#     # Run Model
#     t1 <- Sys.time()
#     df_out <- fit_model(meth = "jomo", data = data$data)
#     t2 <- Sys.time()
# 
#     # Evaluate model
#     res <- evaluate(df_out, data$complete_data, meth, as.numeric(difftime(t2, t1, units = "secs")))
#     res$type <- type
#     res$iter = i
#     res$n_subj = n_subj
#     res$miss_prob = missing_prob
#     res
#   }, .options = furrr_options(seed = TRUE,
#                               globals=TRUE,
#                               packages=packs))
# 
#   # Combine the results into one data frame
#   out=do.call(rbind, results)
#   rownames(out) = NULL
#   out
# }

simulate <- function(n_sim, n_subj, n_time, missing_prob, type, meth) {
  # Load and set the future plan in the worker session.
  library(future)
  library(furrr)
  # Adjust 'workers' to the desired number of cores per target.
  future::plan(multisession, workers = 20)
  
  # Create a progressor with the total number of steps.
  p <- progressr::progressor(steps = n_sim)

  # Run the simulation n_sim times in parallel using future_map
  results <- furrr::future_map(1:n_sim, function(i) {
    # Update the progress bar in each iteration.
    p(sprintf("Iteration %d", i))

    source("R/missMERF V1.R")

    # Ensure reproducibility by setting the seed for each iteration.
    set.seed(1000 + i)

    # Generate Data.
    data <- gen_data(n_subj, n_time, missing_prob, type = type)

    # Run Model.
    t1 <- Sys.time()
    df_out <- fit_model(meth = meth, data = data$data)
    t2 <- Sys.time()

    # Evaluate model.
    res <- evaluate(df_out, data$complete_data, meth, as.numeric(difftime(t2, t1, units = "secs")))
    res$type <- type
    res$iter <- i
    res$n_subj <- n_subj
    res$miss_prob <- missing_prob
    res
  }, .options = furrr::furrr_options(seed = TRUE,
                                     globals = TRUE,
                                     packages = packs))  # Ensure 'packs' is defined (a character vector of package names)

  # Combine the results into one data frame.
  out <- do.call(rbind, results)
  rownames(out) <- NULL
  out
}

