
# missMERF
fit_missMERF = function(data){
  data_missMERF <- missMERF(data, cluster_id = data$id, pmm.k = 5, num.trees = 100, maxiter = 10)
  return(data_missMERF)
}