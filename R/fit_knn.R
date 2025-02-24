# KNN
fit_knn = function(data){
  missing_vars <- c("X1", "X2", "X3", "B1", "B2", "B3")
  imp_knn <- kNN(data, variable = missing_vars, k = 5)
  data_knn <- imp_knn[,1:15]
  return(data_knn)
}