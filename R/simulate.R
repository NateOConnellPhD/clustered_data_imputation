#Load Libraries
packs = c("jomo", "mice", "miceadds", "micemd", "missForest", "VIM", "missRanger", "dplyr",
          "naniar", "visdat", "lme4","glmmTMB", "performance", "tidyr", "pROC", "mixgb", "NOmisc")

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

# simulate <- function(n_sim, n_subj, n_time, missing_prob, type, meth) {
#   # Load and set the future plan in the worker session.
#   library(future)
#   library(furrr)
#   # Adjust 'workers' to the desired number of cores per target.
#   future::plan(multisession, workers = 20)
#   
#   # Create a progressor with the total number of steps.
#   p <- progressr::progressor(steps = n_sim)
#   
#   # Run the simulation n_sim times in parallel using future_map
#   results <- furrr::future_map(1:n_sim, function(i) {
#     # Update the progress bar in each iteration.
#     p(sprintf("Iteration %d", i))
#     
#     source("R/missMERF V1.R")
#     
#     # Ensure reproducibility by setting the seed for each iteration.
#     set.seed(1000 + i)
#     
#     # Generate Data.
#     data <- gen_data(n_subj=200, n_time=5, missing_prob=.2, type = type)
#     
#     # Run Model.
#     t1 <- Sys.time()
#     df_out <- fit_model(meth = meth, data = data$data)
#     t2 <- Sys.time()
#     
#     # Evaluate model.
#     res <- evaluate(df_out, data$complete_data, meth, as.numeric(difftime(t2, t1, units = "secs")))
#     res$type <- type
#     res$iter <- i
#     res$n_subj <- n_subj
#     res$miss_prob <- missing_prob
#     res
#   }, .options = furrr::furrr_options(seed = TRUE,
#                                      globals = TRUE,
#                                      packages = packs))  # Ensure 'packs' is defined (a character vector of package names)
#   
#   # Combine the results into one data frame.
#   out <- do.call(rbind, results)
#   rownames(out) <- NULL
#   out
# }


simulate <- function(n_sim, n_subj, n_time, missing_prob, type, meth, start_iter = 1) {
  # Load and set the future plan in the worker session.
  library(future)
  library(furrr)
  
  future::plan(multisession, workers = 20)
  
  # Create a progressor with the total number of steps.
  p <- progressr::progressor(steps = n_sim)
  
  # Run the simulation in parallel using future_map
  results <- furrr::future_map(start_iter:(start_iter + n_sim - 1), function(i) {
    # Update the progress bar
    p(sprintf("Iteration %d", i))
    
    source("R/missMERF V1.R")
    
    # Ensure reproducibility by setting the seed for each iteration
    set.seed(1000 + i)
    
    # Generate Data
    data <- gen_data(n_subj = n_subj, n_time = n_time, missing_prob = missing_prob, type = type)
    
    # Run Model
    t1 <- Sys.time()
    df_out <- fit_model(meth = meth, data = data$data)
    t2 <- Sys.time()
    
    # Evaluate model
    res <- evaluate(df_out, data$complete_data, meth, as.numeric(difftime(t2, t1, units = "secs")))
    res$type <- type
    res$iter <- i  # Store the actual iteration number
    res$n_subj <- n_subj
    res$miss_prob <- missing_prob
    res
  }, .options = furrr::furrr_options(seed = TRUE, globals = TRUE, packages = packs))
  
  # Combine results into a single data frame
  out <- do.call(rbind, results)
  rownames(out) <- NULL
  out
}


