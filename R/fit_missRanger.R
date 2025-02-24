#missRanger
fit_missRanger = function(data){
  data_missRanger <- missRanger(data, pmm.k = 5, num.trees = 100, maxiter = 10)
  return(data_missRanger)
}