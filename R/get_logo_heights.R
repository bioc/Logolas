#' @title Get heights of logos in nlogomaker() under different scoring schemes
#'
#' @description Generates total heights of the stack of logos in the positive 
#' and negative
#' scales of the nlogomaker() logo plot along with the proportion of the height
#' distributed between the logos to be plotted in the positive and the negative
#' scales respectively under different scoring schemes.
#'
#' @param table The input table (data frame or matrix) of compositional counts
#' or relative frequencies across different logos or symbols (specified along
#' the rows) for different sites or positions or groups
#' (specified along the columns).
#'
#' @param ic Boolean, denoting whether information content based scaling is used
#' on top of the scoring scheme used or not. Default is FALSE
#'
#' @param score Can take either of the options - \code{diff},
#' \code{log}, \code{log-odds}, \code{probKL}, \code{ratio}, 
#' \code{unscaled_log},
#' \code{wKL}. Each option corresponds to a different scoring scheme. The most
#  recommended option is \code{log}.
#'
#' @param bg The background probability, which defaults to NULL, in which case
#' equal probability is assigned to each symbol. The user can however specify a
#' vector (equal to in length to the number of symbols) which specifies the
#' background probability for each symbol and assumes this background 
#' probability to be the same across the columns (sites), or a matrix, 
#' whose each cell specifies the background probability of the symbols 
#' for each position.
#'
#' @param epsilon An additive constant added to the PWM before scaling to 
#' eliminate log (0) type errors.
#'
#' @param opt Option parameter - taking values 1 and 2 - depending on whether
#' median adjustment is done based on background corrected proportions or 
#' without background correction.
#'
#' @param symm A bool input, which if TRUE, the function uses symmetric KL 
#' divergence whereas if FALSE, the function uses non-symmetric KL divergence.
#'
#' @param alpha The Renyi entropy tuning parameter which is used in case of
#' scaling of the bar heights by information criterion. The default tuning
#' parameter value is 1, which corresponds to Shannon entropy.
#'
#' @param hist Whether to use the hist method or the information criterion
#' method to determine the heights of the logos.
#'
#' @param quant The quantile to be adjusted for in computing enrichment and
#' depletion scores. Defaults to 0.5, which corresponds to the median.
#'
#' @importFrom  stats quantile
#'
#' @return Returns the heights of enrichment and depletion for
#' diff approach to EDLogo.
#'
#' @examples
#'
#' m = matrix(rep(0,48),4,12)
#' m[1,] = c(0,0,2.5,7,0,0,0,0,0,0,1,0)
#' m[2,] = c(4,6,3,1,0,0,0,0,0,5,0,5)
#' m[3,] = c(0,0,0,0,0,1,8,0,0,1,1,2)
#' m[4,] = c(4,2,2.5,0,8,7,0,8,8,2,6,1)
#' rownames(m) = c("A", "C", "G", "T")
#' colnames(m) = 1:12
#' m=m/8
#' get_logo_heights(m, score = "log")
#' get_logo_heights(m, score = "log", ic = TRUE)
#' get_logo_heights(m, score = "wKL")
#' get_logo_heights(m, score = "probKL", ic = TRUE)
#' @export

get_logo_heights <- function (table,
                              ic = FALSE,
                              score = c("diff", "log", "log-odds", "probKL",
                                        "ratio", "unscaled_log", "wKL"),
                              bg = NULL, epsilon = 0.01, opt=1, symm = TRUE,
                              alpha = 1, hist=FALSE, quant = 0.5){

  if(ic & score == "unscaled_log"){
    warning("ic = TRUE not compatible with score = `unscaled-log`: switching to
            ic = FALSE")
    ic = FALSE
  }
  if(ic & score == "wKL"){
    warning("ic = TRUE not compatible with score = `wKL`: switching to 
            ic = FALSE")
    ic = FALSE
  }
  if(length(score) != 1){
    stop("score can be wither diff, log, log-odds, probKL, ratio, 
         unscaled_log or wKL")
  }

  if (is.vector(bg)==TRUE){
    if(length(bg) != dim(table)[1]){
      stop("If background prob (bg) is a vector, the length of bg must
           equal the number of symbols for the logo plot")
    }else if(length(which(is.na(table))) > 0){
      stop("For NA in table, a vector bg is not allowed")
    }else{
      bgmat <- bg %*% t(rep(1, dim(table)[2]))
      bgmat[which(is.na(table))] <- NA
      bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
    }
  }else if (is.matrix(bg)==TRUE){
    if(dim(bg)[1] != dim(table)[1] | dim(bg)[2] != dim(table)[2]){
      stop("If background prob (bg) is a matrix, its dimensions must
           match that of the table")
    }else{
      bgmat <- bg
      bgmat[which(is.na(table))] <- NA
      bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
    }
  }else {
    message ("using a background with equal probability for all symbols")
    bgmat <- matrix(1/dim(table)[1], dim(table)[1], dim(table)[2])
    bgmat[which(is.na(table))] <- NA
    bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
  }

  table <- apply(table+0.0001,2,normalize4)
  bgmat <- apply(bgmat+0.0001,2,normalize4)

  if (class(table) == "data.frame"){
    table <- as.matrix(table)
  }else if (class(table) != "matrix"){
    stop("the table must be of class matrix or data.frame")
  }
  table_mat_norm <-  apply(table, 2, function(x) return(x/sum(x[!is.na(x)])))
  bgmat <-  apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))

  npos <- ncol(table_mat_norm)
  chars <- as.character(rownames(table_mat_norm))


  if(!ic){
    if (score == "diff"){
      table_mat_adj <- apply((table_mat_norm+epsilon) - (bgmat+epsilon), 
                             2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }else if (score == "log") {
      table_mat_adj <- apply(log((table_mat_norm+epsilon)/(bgmat+epsilon), 
                                 base=2), 2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }else if (score == "log-odds"){

      if(opt == 1){
        table_mat_adj <- apply((table_mat_norm + epsilon)/(bgmat + epsilon), 
                               2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            # x <- x
            y = log(x/(sum(x)-x), base=2)
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            w <- x[!is.na(x)]
            #w <- w + scale
            y <- log(w/(sum(w)-w), base=2)
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply((table_mat_norm + epsilon), 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            # x <- x
            y = log(x/(sum(x)-x), base=2)
            z <- y - quantile(y, quant)
            return(z)
          }else{
            w <- x[!is.na(x)]
            #w <- w + scale
            y <- log(w/(sum(w)-w), base=2)
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }
    }else if (score == "probKL"){
      table_mat_adj <- apply((table_mat_norm+epsilon) * log((table_mat_norm+epsilon)/(bgmat+epsilon), base=2), 2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }else if (score == "ratio"){
      table_mat_adj <- apply((table_mat_norm+epsilon)/(bgmat+epsilon), 
                             2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }else if (score == "unscaled_log"){
      table_mat_adj <- apply(log((table_mat_norm+epsilon)/(bgmat+epsilon), 
                                 base=2), 
                             2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }else if (score == "wKL"){
      table_mat_adj <- apply(log((table_mat_norm+epsilon)/(bgmat+epsilon), 
                                 base=2),
                               2, function(x)
      {
        indices <- which(is.na(x))
        if(length(indices) == 0){
          y = x
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          return(z)
        }else{
          y <- x[!is.na(x)]
          if(quant != 0){
            qq <- quantile(y, quant)
          }else{
            qq <- 0
          }
          z <- y - qq
          zext <- array(0, length(x))
          zext[indices] <- 0
          zext[-indices] <- z
          return(zext)
        }
      })
    }
    else{
      stop("The value of score chosen is not compatible")
    }

  }else{
    if(score == "diff"){
      if(opt == 1){
        table_mat_adj <- apply((table_mat_norm+epsilon) - (bgmat+epsilon), 
                               2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            y <- x[!is.na(x)]
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply(table_mat_norm+epsilon, 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            z <- y - quantile(y, quant)
            return(z)
          }else{
            y <- x[!is.na(x)]
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }
    }else if(score == "log"){
      if(opt == 1){
        table_mat_adj <- apply(log((table_mat_norm+epsilon)/(bgmat+epsilon),
                                   base=2), 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            y <- x[!is.na(x)]
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply(log(table_mat_norm+epsilon, base=2), 
                               2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            z <- y - quantile(y, quant)
            return(z)
          }else{
            y <- x[!is.na(x)]
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }
    }else if (score == "log-odds"){
      if(opt == 1){
        table_mat_adj <- apply((table_mat_norm + epsilon)/(bgmat + epsilon), 
                               2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            # x <- x
            y = log(x/(sum(x)-x), base=2)
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            w <- x[!is.na(x)]
            #w <- w + scale
            y <- log(w/(sum(w)-w), base=2)
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply((table_mat_norm + epsilon), 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            # x <- x
            y = log(x/(sum(x)-x), base=2)
            z <- y - quantile(y, quant)
            return(z)
          }else{
            w <- x[!is.na(x)]
            #w <- w + scale
            y <- log(w/(sum(w)-w), base=2)
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }


    }else if (score == "probKL"){
      if(opt == 1){
        table_mat_adj <- apply((table_mat_norm+epsilon)*log((table_mat_norm+epsilon)/(bgmat+epsilon), base=2), 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            y <- x[!is.na(x)]
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply((table_mat_norm+epsilon)*log(table_mat_norm+epsilon, 
                                                base=2), 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            z <- y - quantile(y, quant)
            return(z)
          }else{
            y <- x[!is.na(x)]
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }

    }else if (score == "ratio"){
      if(opt == 1){
        table_mat_adj <- apply((table_mat_norm+epsilon)/(bgmat+epsilon), 
                               2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            return(z)
          }else{
            y <- x[!is.na(x)]
            if(quant != 0){
              qq <- quantile(y, quant)
            }else{
              qq <- 0
            }
            z <- y - qq
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }else{
        table_mat_adj <- apply(table_mat_norm+scale, 2, function(x)
        {
          indices <- which(is.na(x))
          if(length(indices) == 0){
            y = x
            z <- y - quantile(y, quant)
            return(z)
          }else{
            y <- x[!is.na(x)]
            z <- y - quantile(y, quant)
            zext <- array(0, length(x))
            zext[indices] <- 0
            zext[-indices] <- z
            return(zext)
          }
        })
      }
    }else{
      stop("The value of score chosen is not compatible")
    }
  }


  if(!ic){

    table_mat_pos <- table_mat_adj
    table_mat_pos[table_mat_pos<= 0] = 0
    table_mat_pos_norm  <- apply(table_mat_pos, 2, 
                                 function(x) return(x/sum(x)))
    table_mat_pos_norm[table_mat_pos_norm == "NaN"] = 0

    table_mat_neg <- table_mat_adj
    table_mat_neg[table_mat_neg >= 0] = 0
    table_mat_neg_norm  <- apply(abs(table_mat_neg), 2, 
                                 function(x) return(x/sum(x)))
    table_mat_neg_norm[table_mat_neg_norm == "NaN"] = 0

    pos_ic <- colSums(table_mat_pos)
    neg_ic <- colSums(abs(table_mat_neg))


    ll <- list()
    ll$pos_ic <- pos_ic
    ll$neg_ic <- neg_ic
    ll$table_mat_pos_norm <- table_mat_pos_norm
    ll$table_mat_neg_norm <- table_mat_neg_norm

  }else{
    table_mat_pos <- table_mat_adj
    table_mat_pos[table_mat_pos<= 0] = 0
    table_mat_pos_norm  <- apply(table_mat_pos, 2, 
                                 function(x) return(x/sum(x)))
    table_mat_pos_norm[table_mat_pos_norm == "NaN"] = 0

    table_mat_neg <- table_mat_adj
    table_mat_neg[table_mat_neg >= 0] = 0
    table_mat_neg_norm  <- apply(table_mat_neg, 2, 
                                 function(x) return(x/sum(x)))
    table_mat_neg_norm[table_mat_neg_norm == "NaN"] = 0

    table_mat_norm <- replace(table_mat_norm, is.na(table_mat_norm), 0)

    for(j in 1:dim(table_mat_neg_norm)[2]){
      if(sum(table_mat_neg_norm[,j]) == 0){
        table_mat_neg_norm[,j] <- normalize4(table_mat_neg_norm[,j]+1e-3)
      }
    }

    for(j in 1:dim(table_mat_pos_norm)[2]){
      if(sum(table_mat_pos_norm[,j]) == 0){
        table_mat_pos_norm[,j] <- normalize4(table_mat_pos_norm[,j]+1e-3)
      }
    }

    if(symm==TRUE){
      table_mat_norm[which(is.na(table))] <- NA
      ic <- 0.5*(ic_computer(table_mat_norm, alpha, hist=hist, bg = bgmat) 
                 + ic_computer(bgmat, alpha, hist=hist, bg = table_mat_norm))
    }else{
      table_mat_norm[which(is.na(table))] <- NA
      ic <- ic_computer(table_mat_norm, alpha, hist=hist, bg = bgmat)
    }

    tab_neg <- apply(table_mat_adj, 2, function(x) {
      y = x[x < 0]
      if(length(y) == 0){
        return(0)
      }else{
        return(abs(sum(y)))
      }
    })

    tab_pos <- apply(table_mat_adj, 2, function(x) {
      y = x[x > 0]
      if(length(y) == 0){
        return(0)
      }else{
        return(abs(sum(y)))
      }
    })

    tab_pos[tab_pos == 0] <- 1e-3
    tab_neg[tab_neg == 0] <- 1e-3

    pos_neg_scaling <- apply(rbind(tab_pos, tab_neg), 2,
                             function(x) return(x/sum(x)))
    pos_ic <- pos_neg_scaling[1, ] * ic
    neg_ic <- pos_neg_scaling[2, ] * ic

    ll <- list()
    ll$pos_ic <- pos_ic
    ll$neg_ic <- neg_ic
    ll$table_mat_pos_norm <- table_mat_pos_norm
    ll$table_mat_neg_norm <- table_mat_neg_norm
  }

  return(ll)
}

ic_computer <-function(mat, alpha, hist=FALSE, bg = NULL) {

  if (is.vector(bg)==TRUE){
    if(length(bg) != dim(mat)[1]){
      stop("If background prob (bg) is a vector, the length of bg 
           must equal the number of symbols for the logo plot")
    }else if(length(which(is.na(mat))) > 0){
      stop("For NA in table, a vector bg is not allowed")
    }else{
      bgmat <- bg %*% t(rep(1, dim(mat)[2]))
      bgmat[which(is.na(mat))] <- NA
      bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
    }
  }else if (is.matrix(bg)==TRUE){
    if(dim(bg)[1] != dim(mat)[1] | dim(bg)[2] != dim(mat)[2]){
      stop("If background prob (bg) is a matrix, its dimensions must match
           that of the table")
    }else{
      bgmat <- bg
      bgmat[which(is.na(mat))] <- NA
      bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
    }
  }else {
    message ("using a background with equal probability for all symbols")
    bgmat <- matrix(1/dim(mat)[1], dim(mat)[1], dim(mat)[2])
    bgmat[which(is.na(mat))] <- NA
    bgmat <- apply(bgmat, 2, function(x) return(x/sum(x[!is.na(x)])))
  }

  bgmat <- apply(bgmat+0.1,2,normalize4)

  if(!hist){
    mat <- apply(mat, 2, function(x) return(x/sum(x[!is.na(x)])))
    npos<-ncol(mat)
    ic <-numeric(length=npos)
    for (i in 1:npos) {
      if(alpha == 1){
        if(is.null(bg)){
          tmp <- mat[,i]
          tmp <- tmp[!is.na(tmp)]
          ic[i] <- log(length(which(tmp!=0.00)), base=2) + 
              sum(sapply(tmp, function(x) {
            if (x > 0) { x*log2(x) } else { 0 }
          }))
        }else{
          tmp <- mat[!is.na(mat[,i]), i]
          bgtmp <- bgmat[!is.na(mat[,i]), i]
          ic[i] <- sum(sapply(1:length(tmp), function(x) {
            if (x > 0) { tmp[x]*log2(tmp[x]) } else { 0 }
          })) - sum(sapply(1:length(tmp), function(x) {
            if (x > 0) { tmp[x]*log2(bgtmp[x]) } else { 0 }
          }))
        }
      }
      else if(alpha == Inf){
        tmp <- mat[!is.na(mat[,i]), i]
        ic[i] <- log(length(which(tmp!=0.00)), base=2) + log(max(tmp))
      }
      else if(alpha <= 0){
        stop("alpha value must be greater than 0")
      }
      else{
        if(is.null(bg)){
          tmp <- mat[!is.na(mat[,i]), i]
          ic[i] <- log(length(which(tmp !=0.00)), base=2) - 
              (1/(1-alpha))* log (sum(tmp^{alpha}), base=2)
        }else{
          tmp <- mat[!is.na(mat[,i]), i]
          bgtmp <- bgmat[!is.na(mat[,i]), i]
          ic[i] <- abs((log(length(which(tmp !=0.00)), base=2) - 
                            (1/(1-alpha))* log2(sum(tmp^{alpha}))) -
                         (log(length(which(tmp !=0.00)), base=2) -
                              (1/(1-alpha))* log2(sum(bgtmp^{alpha}))))
        }
      }
    }
    return(ic)
  }else{
    mat <- mat/sum(mat[!is.na(mat)])
    ic <- colSums(mat, na.rm = TRUE)
    return(ic)
  }
}


normalize4 = function(x){return(x/sum(x[!is.na(x)]))}

