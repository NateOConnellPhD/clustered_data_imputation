

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