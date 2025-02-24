# mixgb 
fit_mixgb = function(data){
  imp_mixgb <- mixgb(data, m = 1, maxit = 10)
  data_mixgb <- data.frame(complete(imp_mixgb[[1]]))
  return(data_mixgb)
}