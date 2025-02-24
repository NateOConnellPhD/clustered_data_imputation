

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