# Missforest
fit_missForest = function(data){
  imp_missForest <- missForest(data)
  data_mf <- imp_missForest$ximp
  return(data_mf)
}
