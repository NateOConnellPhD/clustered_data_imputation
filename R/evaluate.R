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
    
    if(is.numeric(imputed_data$Y)==F){
      y_true  = as.numeric(as.character(imputed_data$Y))
    } else{
      y_true <- imputed_data$Y
    }
   
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