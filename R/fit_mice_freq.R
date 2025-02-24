# Mice Freq
fit_miceFreq = function(data){
  imp0 <- mice(data, maxit=0)
  pred1 <- imp0$predictorMatrix
  meth1 <- imp0$method
  # set imputation methods for the variables with missing values
  meth1[c("X1","X2","X3")] <- "2l.pan"
  meth1[c("B1","B2","B3")] <- "2l.bin"
  # set predictor matrix: 0=don't use, 1=fixed effect, -2=cluster variable
  pred1[,"id"] <- -2 
  #pred1[,"X1"] <- c(2,2,2,2,0,2,2,2,2,2,2)
  #pred1[,"X2"] <- c(2,2,2,2,2,0,2,2,2,2,2)
  #pred1[,"X3"] <- c(2,2,2,2,2,2,0,2,2,2,2)
  #pred1[,"B1"] <- c(2,2,2,2,2,2,2,0,2,2,2)
  #pred1[,"B2"] <- c(2,2,2,2,2,2,2,2,0,2,2)
  #pred1[,"B3"] <- c(2,2,2,2,2,2,2,2,2,0,2)
  #pred1[,"Y"] <- c(2,2,2,2,2,2,2,2,2,2,0)
  
  imp_mice <- mice(data, method = meth1, predictorMatrix = pred1, m = 1, maxit = 5)
  data_mice <- complete(imp_mice, action = 1)
  return(data_mice)
}