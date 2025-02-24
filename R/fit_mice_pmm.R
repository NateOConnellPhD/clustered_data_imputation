#Mice PMM
fit_micePMM = function(data){
  imp_mice <- mice(data, method = "pmm", m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  return(data_mice)
}