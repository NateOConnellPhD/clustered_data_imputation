#new start pulled from https://github.com/mayer79/missRanger/blob/main/R/missRanger.R
#2/3/2025



#pull helper functions

#' Univariate Imputation
#'
#' Fills missing values of a vector, matrix or data frame by sampling with replacement
#' from the non-missing values. For data frames, this sampling is done within column.
#' 
#' @param x A vector, matrix or data frame.
#' @param v A character vector of column names to impute (only relevant if `x` 
#'   is a data frame). The default `NULL` imputes all columns.
#' @param seed An integer seed.
#' @returns `x` with imputed values.
#' @export
#' @examples
#' imputeUnivariate(c(NA, 0, 1, 0, 1))
#' head(imputeUnivariate(generateNA(iris)))
imputeUnivariate <- function(x, v = NULL, seed = NULL) {
  stopifnot(is.atomic(x) || is.data.frame(x))
  
  if (!is.null(seed)) {
    set.seed(seed)  
  }
  
  imputeVec <- function(z) {
    na <- is.na(z)
    if ((s <- sum(na))) {
      if (s == length(z)) {
        stop("No non-missing elements to sample from.")
      }
      z[na] <- sample(z[!na], s, replace = TRUE)
    }
    z
  }
  
  # vector or matrix
  if (is.atomic(x)) {
    return(imputeVec(x))
  } 
 
  # data frame
  v <- if (is.null(v)) names(x) else intersect(v, names(x))
  x[, v] <- lapply(x[, v, drop = FALSE], imputeVec)

  return(x)
}


#' Print Method
#' 
#' Print method for an object of class "missRanger".
#'
#' @param x An object of class "missRanger".
#' @param ... Further arguments passed from other methods.
#' @returns Invisibly, the input is returned.
#' @export
#' @examples
#' CO2_ <- generateNA(CO2, seed = 1)
#' imp <- missRanger(CO2_, pmm.k = 5, data_only = FALSE, num.threads = 1)
#' imp
print.missRanger <- function(x, ...) {
  b <- x$best_iter
  cat("missRanger object. Extract imputed data via $data\n")
  cat("- best iteration:", b, "\n")
  cat("- best average OOB imputation error:", x$mean_pred_errors[b], "\n")
  invisible(x)
}

#' Summary Method
#' 
#' Summary method for an object of class "missRanger".
#' 
#' @param object An object of class "missRanger".
#' @param ... Further arguments passed from other methods.
#' @returns Invisibly, the input is returned.
#' @export
#' @examples
#' CO2_ <- generateNA(CO2, seed = 1)
#' imp <- missRanger(CO2_, pmm.k = 5, data_only = FALSE, num.threads = 1)
#' summary(imp)
summary.missRanger <- function(object, ...) {
  print(object)
  cat("\nSequence of OOB prediction errors:\n\n")
  print(object$pred_errors)
  cat("\nMean performance per iteration:\n")
  print(object$mean_pred_errors)
  cat("\nFirst rows of imputed data:\n\n")
  print(utils::head(object$data, 3L))
  invisible(object)
}


#' Predict Method
#' 
#' @description
#' Impute missing values on `newdata` based on an object of class "missRanger".
#' 
#' For multivariate imputation, use `missRanger(..., keep_forests = TRUE)`. 
#' For univariate imputation, no forests are required. 
#' This can be enforced by `predict(..., iter = 0)` or via `missRanger(. ~ 1, ...)`.
#' 
#' Note that out-of-sample imputation works best for rows in `newdata` with only one
#' missing value (counting only missings in variables used as covariates 
#' in random forests). We call this the "easy case". In the "hard case", 
#' even multiple iterations (set by `iter`) can lead to unsatisfactory results.
#' 
#' @details
#' The out-of-sample algorithm works as follows:
#' 1. Impute univariately all relevant columns by randomly drawing values 
#'    from the original unimputed data. This step will only impact "hard case" rows.
#' 2. Replace univariate imputations by predictions of random forests. This is done
#'    sequentially over variables, where the variables are sorted to minimize the impact
#'    of univariate imputations. Optionally, this is followed by predictive mean matching (PMM).
#' 3. Repeat Step 2 for "hard case" rows multiple times.
#' 
#' @param object 'missRanger' object.
#' @param newdata A `data.frame` with missing values to impute.
#' @param pmm.k Number of candidate predictions of the original dataset
#'   for predictive mean matching (PMM). By default the same value as during fitting.
#' @param iter Number of iterations for "hard case" rows. 0 for univariate imputation.
#' @param num.threads Number of threads used by ranger's predict function.
#'   The default `NULL` uses all threads.
#' @param seed Integer seed used for initial univariate imputation and PMM.
#' @param verbose Should info be printed? (1 = yes/default, 0 for no).
#' @param ... Passed to the predict function of ranger.
#' @export
#' @examples
#' iris2 <- generateNA(iris, seed = 20, p = c(Sepal.Length = 0.2, Species = 0.1))
#' imp <- missRanger(iris2, pmm.k = 5, num.trees = 100, keep_forests = TRUE, seed = 2)
#' predict(imp, head(iris2), seed = 3)
predict.missRanger <- function(
    object,
    newdata,
    pmm.k = object$pmm.k,
    iter = 4L,
    num.threads = NULL,
    seed = NULL,
    verbose = 1L,
    ...
  ) {
  stopifnot(
    "'newdata' should be a data.frame!" = is.data.frame(newdata),
    "'newdata' should have at least one row!" = nrow(newdata) >= 1L,
    "'iter' should not be negative!" = iter >= 0L,
    "'pmm.k' should not be negative!" = pmm.k >= 0L
  )
  data_raw <- object$data_raw
  
  # WHICH VARIABLES TO IMPUTE?
  
  # (a) Only those in newdata
  to_impute <- intersect(object$to_impute, colnames(newdata))
  
  # (b) Only those with missings
  to_fill <- is.na(newdata[, to_impute, drop = FALSE])
  missing_counts <- colSums(to_fill)
  to_impute <- to_impute[missing_counts > 0L]
  to_fill <- to_fill[, to_impute, drop = FALSE]
  
  if (length(to_impute) == 0L) {
    return(newdata)
  }
  
  # CHECK VARIABLES USED TO IMPUTE
  
  impute_by <- object$impute_by
  if (!all(impute_by %in% colnames(newdata))) {
    stop(
      "Variables not present in 'newdata': ",
      paste(setdiff(impute_by, colnames(newdata)), collapse = ", ")
    )
  }
  
  # We currently don't do multivariate imputation if variable not to be imputed 
  # has missing values
  only_impute_by <- setdiff(impute_by, to_impute)
  if (length(only_impute_by) > 0L && anyNA(newdata[, only_impute_by])) {
    stop(
      "Missing values in ", paste(only_impute_by, collapse = ", "), " not allowed."
    )
  }
  
  # CONSISTENCY CHECKS WITH 'data_raw'
  
  for (v in union(to_impute, impute_by)) {
    v_new <- newdata[[v]]
    v_orig <- data_raw[[v]]
    
    if (all(is.na(v_new))) {
      next  # NA of wrong class is fine!
    }
    # class() distinguishes numeric, integer, logical, factor, character, Date, ...
    # - variables in to_impute are numeric, integer, logical, factor, or character
    # - variables in impute_by can also be of *mode* numeric, which includes Dates
    if (!identical(class(v_new), class(v_orig))) {
      stop("Inconsistency between 'newdata' and original data in variable ", v)
    }
    
    # Factor inconsistencies are not okay in 'to_impute'
    if (
      v %in% to_impute && is.factor(v_new) && !identical(levels(v_new), levels(v_orig))
    ) {
      if (all(levels(v_new) %in% levels(v_orig))) {
        newdata[[v]] <- factor(v_new, levels(v_orig), ordered = is.ordered(v_orig))
        if (verbose >= 1L) {
          message("\nExtending factor levels of '", v, "' to those in original data")
        }
      } else {
        stop("New factor levels seen in variable to impute: ", v)
      }
    }
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  # UNIVARIATE IMPUTATION 

  for (v in to_impute) {
    bad <- to_fill[, v]
    v_orig <- data_raw[[v]]
    donors <- sample(v_orig[!is.na(v_orig)], size = sum(bad), replace = TRUE)
    if (all(bad)) {
      # Handles e.g. case when original is factor, but newdata has all NA of numeric type
      newdata[[v]] <- donors
    } else {
      newdata[[v]][bad] <- donors
    }
  }
  
  if (length(impute_by) == 0L || iter == 0L) {
    if (verbose >= 1L) {
      message("\nOnly univariate imputations done")
    }  
    return(newdata)
  }
  
  # MULTIVARIATE IMPUTATION
  
  if (is.null(object$forests)) {
    stop("No random forests in 'object'. Use missRanger(, keep_forests = TRUE).")
  }
  
  # Do we have a random forest for all variables with missings? If no, we don't repeat
  # its univariate imputation.
  forests_missing <- setdiff(to_impute, names(object$forests))
  if (length(forests_missing) > 0L) {
    if (verbose >= 1L) {
      message(
        "\nNo random forest for ", forests_missing, 
        ". Univariate imputation done for this variable."
      )
    }
    to_impute <- setdiff(to_impute, forests_missing)
  }
  
  # Do we have rows of "hard case"? If no, a single iteration is sufficient
  hard_cols <- intersect(to_impute, impute_by)
  hard_rows <- rowSums(to_fill[, hard_cols, drop = FALSE]) > 1L
  if (!any(hard_rows)) {
    iter <- 1L
  }
  
  # We first impute hard columns, then the rest.
  # Sorting hard columns is done in decreasing order of missings, counting only 
  # rows of hard case. Sorting of the rest is irrelevant.
  # We ignore the special case where one forest is missing
  hard_counts <- colSums(to_fill[hard_rows, hard_cols, drop = FALSE])
  to_impute <- c(
    hard_cols[order(hard_counts, decreasing = TRUE)],
    setdiff(to_impute, hard_cols)  # rest
  )
  
  for (j in seq_len(iter)) {
    for (v in to_impute) {
      pred <- stats::predict(
        object$forests[[v]],
        newdata[to_fill[, v], ],
        num.threads = num.threads,
        verbose = verbose >= 1L,
        ...
      )$predictions
      if (pmm.k >= 1) {
        xtrain <- object$forests[[v]]$predictions
        ytrain <- data_raw[[v]]
        if (anyNA(ytrain)) {
          ytrain <- ytrain[!is.na(ytrain)]  # To align with OOB predictions
        }
        pred <- pmm(xtrain = xtrain, xtest = pred, ytrain = ytrain, k = pmm.k)
      } else if (is.logical(newdata[[v]])) {
        pred <- as.logical(pred)
      } else if (is.character(newdata[[v]])) {
        pred <- as.character(pred)
      }
      newdata[[v]][to_fill[, v]] <- pred
    }
    if (j == 1L && iter > 1L) {
      to_fill <- to_fill & hard_rows
      hard_counts <- colSums(to_fill[, to_impute, drop = FALSE])
      to_impute <- to_impute[hard_counts > 0L]  # Need to fill only hard cases when j>1
    }
  }
  return(newdata)
}


#' Predictive Mean Matching
#'
#' For each value in the prediction vector `xtest`, one of the closest `k`
#' values in the prediction vector `xtrain` is randomly chosen and its observed
#' value in `ytrain` is returned. Note that `xtrain` and `xtest` must be both either
#' numeric, logical, or factor-valued. `ytest` can be of any type.
#'
#' @param xtrain Vector with predicted values in the training data.
#'   Must be numeric, logical, or factor-valued.
#' @param xtest Vector as `xtrain` with predicted values in the test data.
#'   Missing values are not allowed.
#' @param ytrain Vector of the observed values in the training data. Must be of same 
#'   length as `xtrain`.
#' @param k Number of nearest neighbours (donors) to sample from.
#' @param seed Integer random seed.
#' @returns Vector of the same length as `xtest` with values from `xtrain`.
#' @export
#' @examples 
#' pmm(xtrain = c(0.2, 0.3, 0.8), xtest = c(0.7, 0.2), ytrain = 1:3, k = 1)  # c(3, 1)
pmm <- function(xtrain, xtest, ytrain, k = 1L, seed = NULL) {
  stopifnot(
    (is.numeric(xtrain) && is.numeric(xtest)) ||
      (is.factor(xtrain) && is.factor(xtest)) ||
      (is.logical(xtrain) && is.logical(xtest)),
    length(xtrain) == length(ytrain),
    length(xtest) >= 1L,
    !anyNA(xtest),
    k >= 1L
  )
  
  # Filter on complete train data
  ok <- !is.na(xtrain) & !is.na(ytrain)
  if (!any(ok)) {
    stop("'xtrain' and 'ytrain' need at least one complete observation")
  }
  xtrain <- xtrain[ok]
  ytrain <- ytrain[ok]
  
  # Handle trivial case
  u <- unique(ytrain)
  if (length(u) == 1L) {
    return(rep(u, length(xtest)))
  }
  
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  if (is.factor(xtrain) && !identical(levels(xtrain), levels(xtest))) {
    stop("Incompatible factor levels in 'xtrain' and 'xtest'")  
  }
  
  if (!is.numeric(xtrain)) {
    xtrain <- as.numeric(xtrain)
    xtest <- as.numeric(xtest)
  }
  
  # PMM based on k-nearest neightbour
  k <- min(k, length(xtrain))
  nn <- FNN::knnx.index(xtrain, xtest, k)
  take <- t(stats::rmultinom(length(xtest), 1L, rep(1L, k)))
  
  return(ytrain[rowSums(nn * take)])
}




#' Fast Imputation of Missing Values by Chained Random Forests
#' 
#' Uses the "ranger" package (Wright & Ziegler) to do fast missing value imputation by
#' chained random forests, see Stekhoven & Buehlmann and Van Buuren & Groothuis-Oudshoorn.
#' Between the iterative model fitting, it offers the option of predictive mean matching.
#' This firstly avoids imputation with values not present in the original data
#' (like a value 0.3334 in a 0-1 coded variable).
#' Secondly, predictive mean matching tries to raise the variance in the resulting
#' conditional distributions to a realistic level. This allows to do multiple imputation
#' when repeating the call to [missRanger()].
#' 
#' The iterative chaining stops as soon as `maxiter` is reached or if the average
#' out-of-bag (OOB) prediction errors stop reducing.
#' In the latter case, except for the first iteration, the second last (= best)
#' imputed data is returned.
#' 
#' OOB prediction errors are quantified as 1 - R^2 for numeric variables, and as
#' classification error otherwise. If a variable has been imputed only univariately,
#' the value is 1.
#' 
#' @param data A `data.frame` with missing values to impute.
#' @param formula A two-sided formula specifying variables to be imputed
#'   (left hand side) and variables used to impute (right hand side).
#'   Defaults to `. ~ .`, i.e., use all variables to impute all variables.
#'   For instance, if all variables (with missings) should be imputed by all variables
#'   except variable "ID", use `. ~ . - ID`. Note that a "." is evaluated
#'   separately for each side of the formula. Further note that variables with missings
#'   must appear in the left hand side if they should be used on the right hand side.
#' @param pmm.k Number of candidate non-missing values to sample from in the 
#'   predictive mean matching steps. 0 to avoid this step.
#' @param num.trees Number of trees passed to [ranger::ranger()].
#' @param mtry Number of covariates considered per split. The default `NULL` equals
#'   the rounded down root of the number of features. Can be a function, e.g.,
#'   `function(p) trunc(p/3)`. Passed to [ranger::ranger()]. Note that during the
#'   first iteration, the number of features is growing. Thus, a fixed value can lead to
#'   an error. Using a function like `function(p) min(p, 2)` will fix such problem.
#' @param min.node.size Minimal node size passed to [ranger::ranger()].
#'   By default 1 for classification and 5 for regression.
#' @param min.bucket Minimal terminal node size passed to [ranger::ranger()].
#'   The default `NULL` means 1.
#' @param max.depth Maximal tree depth passed to [ranger::ranger()].
#'   `NULL` means unlimited depth. 1 means single split trees.
#' @param replace Sample with replacement passed to [ranger::ranger()].
#' @param sample.fraction Fraction of rows per tree passed to [ranger::ranger()].
#'   The default: use all rows when `replace = TRUE` and 0.632 otherwise.
#' @param case.weights Optional case weights passed to [ranger::ranger()].
#' @param num.threads Number of threads passed to [ranger::ranger()].
#'   The default `NULL` uses all threads.
#' @param save.memory Slow but memory saving mode of [ranger::ranger()].
#' @param maxiter Maximum number of iterations.
#' @param seed Integer seed.
#' @param verbose A value in 0, 1, 2 controlling the verbosity.
#' @param returnOOB Should the final average OOB prediction errors be added
#'   as data attribute "oob"? Only relevant when `data_only = TRUE`.
#' @param data_only If `TRUE` (default), only the imputed data is returned.
#'   Otherwise, a "missRanger" object with additional information is returned.
#' @param keep_forests Should the random forests of the last relevant iteration
#'   be returned? The default is `FALSE`. Setting this option will use a lot of memory.
#'   Only relevant when `data_only = TRUE`.
#' @param ... Additional arguments passed to [ranger::ranger()]. Not all make sense.
#' @returns 
#'   If `data_only = TRUE` an imputed `data.frame`. Otherwise, a "missRanger" object
#'   with the following elements:
#'   - `data`: The imputed data.
#'   - `data_raw`: The original data provided.
#'   - `forests`: When `keep_forests = TRUE`, a list of "ranger" models used to 
#'     generate the imputed data. `NULL` otherwise.
#'   - `to_impute`: Variables to be imputed (in this order).
#'   - `impute_by`: Variables used for imputation.
#'   - `best_iter`: Best iteration.
#'   - `pred_errors`: Per-iteration OOB prediction errors (1 - R^2 for regression,
#'     classification error otherwise).
#'   - `mean_pred_errors`: Per-iteration averages of OOB prediction errors.
#'   - `pmm.k`: Same as input `pmm.k`.
#'   
#' @references
#'   1. Wright, M. N. & Ziegler, A. (2016). ranger: A Fast Implementation of 
#'     Random Forests for High Dimensional Data in C++ and R. Journal of Statistical 
#'     Software, in press. <arxiv.org/abs/1508.04409>.
#'   2. Stekhoven, D.J. and Buehlmann, P. (2012). 'MissForest - nonparametric missing 
#'     value imputation for mixed-type data', Bioinformatics, 28(1) 2012, 112-118. 
#'     https://doi.org/10.1093/bioinformatics/btr597.
#'   3. Van Buuren, S., Groothuis-Oudshoorn, K. (2011). mice: Multivariate Imputation 
#'     by Chained Equations in R. Journal of Statistical Software, 45(3), 1-67. 
#'     http://www.jstatsoft.org/v45/i03/
#' @export
#' @examples
#' iris2 <- generateNA(iris, seed = 1)
#' 
#' imp1 <- missRanger(iris2, pmm.k = 5, num.trees = 50, seed = 1)
#' head(imp1)
#' 
#' # Extended output
#' imp2 <- missRanger(iris2, pmm.k = 5, num.trees = 50, data_only = FALSE, seed = 1)
#' summary(imp2)
#' 
#' all.equal(imp1, imp2$data)
#' 
#' # Formula interface: Univariate imputation of Species and Sepal.Width
#' imp3 <- missRanger(iris2, Species + Sepal.Width ~ 1)








missMERF <- function(
    data,
    cluster_id = .,
    formula = . ~ .,
    pmm.k = 0L,
    num.trees = 500,
    mtry = NULL,
    min.node.size = NULL,
    min.bucket = NULL,
    max.depth = NULL,
    replace = TRUE,
    sample.fraction = if (replace) 1 else 0.632,
    case.weights = NULL,
    num.threads = NULL,
    save.memory = FALSE,
    maxiter = 10L,
    seed = NULL,
    verbose = 1,
    returnOOB = FALSE,
    data_only = !keep_forests,
    keep_forests = FALSE,
    ...
  ) {
  if (verbose) {
    message("Missing value imputation by mixed effects random forest (MERF)")
  }
  
  # 1) INITIAL CHECKS
  bad_args <- c(
    "write.forest", 
    "probability", 
    "quantreg", 
    "oob.error", 
    "dependent.variable.name", 
    "classification"
  )
  stopifnot(
    "'data' should be a data.frame!" = is.data.frame(data), 
    "'data' should have at least one row and one column!" = dim(data) >= 1L, 
    "'pmm.k' should not be negative!" = pmm.k >= 0L,
    "'maxiter' should be positive!" = maxiter >= 1L,
    "Incompatible ranger() arguments in ..." = !(bad_args  %in% names(list(...)))
  )
  if (!is.null(case.weights)) {
    stopifnot(
      "Wrong number of 'case.weights'!" = length(case.weights) == nrow(data), 
      "Missing values in 'case.weights'!" = !anyNA(case.weights)
    )
  }
  
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  if (!data_only) {
    data_raw <- data
  }

  lhs_rhs <- .formula_parser(formula, data[1L, ])
  to_impute <- lhs_rhs[[1L]]  # lhs
  impute_by <- lhs_rhs[[2L]]  # rhs
  
  # 2) SELECT VARIABLES TO IMPUTE
  
  # 2a) Pick variables with some but not all missings
  ok <- vapply(
    data[, to_impute, drop = FALSE], 
    FUN = function(z) anyNA(z) && !all(is.na(z)),
    FUN.VALUE = logical(1L)
  )
  to_impute <- to_impute[ok]
  
  # 2b) Drop variables incompatible as responses in ranger()
  #  Note: We *could* do univariate imputation though. But at this stage we do not
  #  know this yet in all cases: impute_by might still contain bad variables.
  ok <- vapply(
    data[, to_impute, drop = FALSE], 
    FUN = function(z) .check_response(z),
    FUN.VALUE = logical(1L)
  )
  if (verbose && !all(ok)) {
    cat(
      "\nCan't impute these variables (wrong type): ",
      paste(to_impute[!ok], collapse = ", ")
    )
  }
  to_impute <- to_impute[ok]
  
  if (length(to_impute) == 0L) {
    if (verbose) {
      message("\nNothing to impute!")
    }
    if (data_only) {
      return(data) 
    } else {
      out <- structure(
        list(
          data = data,
          data_raw = data_raw,
          forests = NULL,
          to_impute = c(),
          impute_by = c(),
          best_iter = 0L,
          pred_errors = NULL,
          mean_pred_errors = NULL,
          pmm.k = pmm.k
        ), 
        class = "missRanger"
      )  
      return(out)
    }
  }
  
  # Get missing indicators, and sort variables by increasing number of missings
  data_NA <- is.na(data[, to_impute, drop = FALSE])
  to_impute <- names(sort(colSums(data_NA)))
  
  # 3) SELECT VARIABLES USED TO IMPUTE
  
  # Variables should either appear in "to_impute" or do not contain any missings
  ok <- impute_by %in% to_impute |
    !vapply(data[, impute_by, drop = FALSE], FUN = anyNA, FUN.VALUE = logical(1L))
  impute_by <- impute_by[ok]
  
  # 3b) Drop variables that can't be used as features in ranger()
  ok <- vapply(
    data[, impute_by, drop = FALSE],
    FUN = function(z) .check_feature(z),
    FUN.VALUE = logical(1L)
  )
  if (verbose && !all(ok)) {
    cat(
      "\nCan't use these variables for imputation (wrong type): ",
      paste(impute_by[!ok], collapse = ", ")
    )
  }
  impute_by <- impute_by[ok]
  
  # 3c) Drop constant features (NA does not count as value)
  ok <- vapply(
    data[, impute_by, drop = FALSE],
    FUN = function(z) length(unique(z[!is.na(z)])) > 1L,
    FUN.VALUE = logical(1L)
  )
  if (verbose && !all(ok)) {
    cat(
      "\nSkip constant features for imputation: ",
      paste(impute_by[!ok], collapse = ", ")
    )
  }
  impute_by <- impute_by[ok]

  if (verbose) {
    cat("\nVariables to impute:\t\t")
    cat(to_impute, sep = ", ")
    cat("\nVariables used to impute:\t")
    cat(impute_by, sep = ", ")
    cat("\n")
  }

  # 4) IMPUTATION
  
  # Initialization
  completed <- setdiff(impute_by, to_impute)  # Immediately used as features in ranger()
  j <- 1L                                     # Which iteration?
  crit <- TRUE                                # Iterate until criterium is FALSE
  dig <- 4L                                   # Only used if verbose = 2
  pred_error <- rep(1, length(to_impute))     # Within iteration OOB errors per feature
  names(pred_error) <- to_impute
  pred_errors <- list()                       # Keeps OOB errors per iteration
  if (keep_forests) {
    forests <- list()
  }
  
  if (verbose >= 2) {
    cat("\n", abbreviate(to_impute, minlength = dig + 2L), sep = "\t")
  }
  
  # Looping over iterations and variables to impute
  while (crit && j <= maxiter) {
    if (verbose) {
      if (verbose == 1) {
        i <- 1L
        cat("\niter", j, "\n")
        pb <- utils::txtProgressBar(0, length(to_impute), style = 3)
      } else if (verbose >= 2) {
        cat("\niter ", j, ":\t", sep = "")
      }
    }

    data_last <- data
    pred_error_last <- pred_error
    if (keep_forests) {
      forests_last <- forests
    }

    for (v in to_impute) {
      v.na <- data_NA[, v]
      xvars <- setdiff(completed, v)

      if (length(xvars) == 0L) {
        data[[v]] <- imputeUnivariate(data[[v]])
      } else {
        y <- data[[v]][!v.na]
        is_char <- is.factor(y)
        if (is_char) {
          y <- as.factor(y)
        }
        
        fit <- ranger::ranger(
          num.trees = num.trees,
          mtry = mtry,
          min.node.size = min.node.size,
          min.bucket = min.bucket,
          max.depth = max.depth,
          replace = replace,
          sample.fraction = sample.fraction,
          case.weights = if (!is.null(case.weights)) case.weights[!v.na],
          num.threads = num.threads,
          save.memory = save.memory,
          x = data[!v.na, xvars, drop = FALSE],
          y = y,
          verbose = verbose >= 1,
          ...
        )

	  #get predictions from ranger random forest
	  pred.rf <- predict(fit, data)
	  pred.rf1 <- pred.rf$predictions
	  #combine predictions into data frame to be used in a mixed model
	  data1 <- data.frame(cbind(data[[v]],data,pred.rf1,cluster_id))
	  colnames(data1) <- c("imputed_var",names(data),"pred.rf","cluster_id")


	  #run the mixed effects model with the predicted value from the random forest
	  if (!is_char) { 
		# fit.mixedmodel <- lmer(imputed_var~pred.rf+(1|cluster_id),data=data1,control = lmerControl(optimizer = "nloptwrap",
		#                                                                                             optCtrl = list(maxfun = 200000)))
		fit.mixedmodel <- glmmTMB(imputed_var ~ pred.rf + (1|cluster_id), 
		                          data = data1, 
		                          family = gaussian(),
		                          control = glmmTMBControl(optCtrl = list(iter.max = 200000, eval.max = 200000)))
	  	pred <- stats::predict(fit.mixedmodel,data1[v.na,],type="response",re.form=NULL,allow.new.levels=TRUE)
	  	pred_xtrain <- stats::predict(fit.mixedmodel,data1[!v.na,],type="response",re.form=NULL,allow.new.levels=TRUE)
	  }

	  if (is_char) {
		fit.mixedmodel <- glmer(imputed_var~pred.rf+(1|cluster_id),data=data1, binomial,  control = glmerControl(optimizer = "bobyqa",
		                                                                                                         optCtrl = list(maxfun = 200000)))
		pred <- stats::predict(fit.mixedmodel,data1[v.na,],type="response",re.form=NULL,allow.new.levels=TRUE)
	  	pred_xtrain <- stats::predict(fit.mixedmodel,data1[!v.na,],type="response",re.form=NULL,allow.new.levels=TRUE)
	  }
#print(fit.mixedmodel)

#print(summary(pred_xtrain))
#length(pred_xtrain)
#	  pred_xtrain1 <- pred_xtrain$predictions
#print(summary(pred))
#print(length(pred))
#print(length(y))
#print(length(pred_xtrain))

#pred function from original code pred <- stats::predict(fit, data[v.na, xvars, drop = FALSE])$predictions
        
        if (pmm.k >= 1L) {
          pred <- pmm(xtrain = pred_xtrain, xtest = pred, ytrain = y, k = pmm.k)
        } else if (is.logical(y)) {
          pred <- as.logical(pred)
        } else if (is_char) {
          pred <- as.character(pred)
        }

        data[v.na, v] <- pred
        
        if (fit$treetype == "Regression") {
          pred_error[[v]] <- 1 - fit$r.squared
        } else {  # Classification error
          pred_error[[v]] <- fit$prediction.error
        }
	 #note: did not update this for the fit.mixedmodel because it was giving an error about $ operator not defined for s4 class
        
        if (is.nan(pred_error[[v]])) {
          pred_error[[v]] <- 0
        }

        if (keep_forests) {
          forests[[v]] <- fit
        }
      }
      
      if (j == 1L && (v %in% impute_by)) {
        completed <- union(completed, v)
      }
      
      if (verbose) {
        if (verbose == 1) {
          utils::setTxtProgressBar(pb, i)
          i <- i + 1L
        } else if (verbose >= 2) {
          cat(format(round(pred_error[[v]], dig), nsmall = dig), "\t")  
        }
      }
    }
    
    pred_errors[[j]] <- pred_error
    crit <- mean(pred_error) < mean(pred_error_last)
    j <- j + 1L
  }
  
  if (verbose) {
    cat("\n")
  }
  
  # We take the current iteration if (a) the iteration before did not impute yet
  # or (b) we had to stop before performance worsened
  if (j == 2L || (j > maxiter && crit)) {
    data_last <- data
    pred_error_last <- pred_error
    best_iter <- j - 1L
    if (keep_forests) {
      forests_last <- forests
    }
  } else {
    best_iter <- j - 2L
  }
  
  if (data_only) {
    if (returnOOB) {
      attr(data_last, "oob") <- pred_error_last 
    }
    return(data_last)
  }

  
  out <- list(
    data = data_last,
    data_raw = data_raw,
    forests = if (keep_forests) forests_last,
    to_impute = to_impute,
    impute_by = impute_by,
    best_iter = best_iter,
    pred_errors = do.call(rbind, pred_errors),
    mean_pred_errors = vapply(pred_errors, FUN = mean, FUN.VALUE = numeric(1)),
    pmm.k = pmm.k
  )
  class(out) <- "missRanger"
  
  return(out)
}


# HELPER FUNCTIONS

# Extracts colnames of data from a string like "a + b + c"
.string_parser <- function(z, data) {
  if (z == ".") {
    return(colnames(data))
  }
  out <- attr(stats::terms.formula(stats::reformulate(z), data = data), "term.labels")
  return(trimws(out, whitespace = "`"))  # Remove annoying enclosing backticks
}

# Returns list with lhs and rhs variable name vectors
.formula_parser <- function(formula, data) {
  if (!inherits(formula, "formula")) {
    stop("'formula' should be a formula!")
  }
  out <- as.character(formula)
  if (length(out) == 1L) {
    # {formula.tools} seems to be loaded, which breaks base's as.character().
    # This is a workaround.
    out <- strsplit(out, "~", fixed = TRUE)[[1L]]
    if (any(out == "")) {
      stop("Formula must have left and right hand side.")
    }
    out <- c("~", out)
  }
  if (length(out) != 3L) {
    stop("Formula must have left and right hand side.")
  }
  return(lapply(out[2:3], FUN = .string_parser, data = data))
}

# Checks if response type can be used in ranger (or easily converted to)
.check_response <- function(x) {
  # is.numeric(1L) -> TRUE
  return(is.numeric(x) || is.factor(x) || is.character(x) || is.logical(x))
}

# Checks if feature type can be used in ranger (assumption)
.check_feature <- function(x) {
  # factor/integer/Date -> "numeric"
  return(mode(x) %in% c("numeric", "character", "logical"))
}