library(smcfcs)
library(survival)
context("Flexible parametric proportional hazards model testing")

test_that("Flexsurv imputation of missing normal covariate is approximately unbiased", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- z + rnorm(n)
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
        smformula = "Surv(t, d)~x+z",
        method = c("", "", "norm", ""),
        k=2
      )
      library(mitools)
      impobj <- imputationList(imps$impDatasets)
      models <- with(impobj, flexsurv::flexsurvspline(Surv(t, d) ~ x + z, k=2))
      MIcombineRes <- summary(MIcombine(models))
      # 95% CI includes true value
      (MIcombineRes$`(lower`[5] < 1) & (MIcombineRes$`upper)`[5]>1)
    },
    TRUE
  )

})

test_that("Flexsurv imputation of missing binary covariate is approximately unbiased", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2
      )
      library(mitools)
      impobj <- imputationList(imps$impDatasets)
      models <- with(impobj, flexsurv::flexsurvspline(Surv(t, d) ~ x + z, k=2))
      MIcombineRes <- summary(MIcombine(models))
      # 95% CI includes true value
      (MIcombineRes$`(lower`[5] < 1) & (MIcombineRes$`upper)`[5]>1)
    },
    TRUE
  )

})

test_that("Flexsurv imputation of censored times checks", {
  # check that event indicator equals 1 for all
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE,
                              m=1
      )
      identical(mean(imps$impDatasets[[1]]$d),1)
    },
    TRUE
  )

})


test_that("Flexsurv imputation of missing binary covariate is approximately unbiased,
          imputing covariate and censored times", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE
      )
      library(mitools)
      impobj <- imputationList(imps$impDatasets)
      # note that in the following fits flexsurvspline will choose knots based
      # on the obs+imputed event times in the imputed datasets, rather than in the
      # original obs times (which is what smcfcs.flexsurv has done above)
      models <- with(impobj, flexsurv::flexsurvspline(Surv(t, d) ~ x + z, k=2))
      MIcombineRes <- summary(MIcombine(models))
      # 95% CI includes true value
      (MIcombineRes$`(lower`[5] < 1) & (MIcombineRes$`upper)`[5]>1)
    },
    TRUE
  )

})



test_that("Flexsurv imputation, imputing covariate and censored times,
          passing new common censoring time. Check censoring is as specified", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      c <- rexp(n)
      d <- 1 * (t < c)
      t[d==0] <- c[d==0]
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE,
                              censtime=10,
                              m=1
      )
      identical(mean(imps$impDatasets[[1]]$t[imps$impDatasets[[1]]$d==0]),10)
    },
    TRUE
  )
})

test_that("Flexsurv imputation, imputing covariate and censored times,
          passing new vector of censorings. Check censoring is as specified", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      c <- rexp(n)
      d <- 1 * (t < c)
      t[d==0] <- c[d==0]
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE,
                              censtime=t[d==0]+0.1,
                              m=1
      )
      identical(mean(imps$impDatasets[[1]]$t[imps$impDatasets[[1]]$d==0]),
                mean(t[imps$impDatasets[[1]]$d==0]+0.1))
    },
    TRUE
  )
})

test_that("Flexsurv imputation, imputing censored times only. Check it runs.", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      c <- rexp(n)
      d <- 1 * (t < c)
      t[d==0] <- c[d==0]

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "", ""),
                              k=2,
                              imputeTimes=TRUE,
                              censtime=t[d==0]+0.1,
                              m=1
      )
      identical(mean(imps$impDatasets[[1]]$t[imps$impDatasets[[1]]$d==0]),
                mean(t[imps$impDatasets[[1]]$d==0]+0.1))
    },
    TRUE
  )
})

test_that("Flexsurv imputation of missing binary covariate is approximately unbiased,
          imputing covariate and censored times, originalKnots=FALSE", {
  skip_on_cran()
  expect_equal(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE,
                              originalKnots=FALSE
      )
      library(mitools)
      impobj <- imputationList(imps$impDatasets)
      models <- with(impobj, flexsurv::flexsurvspline(Surv(t, d) ~ x + z, k=2))
      MIcombineRes <- summary(MIcombine(models))
      # 95% CI includes true value
      (MIcombineRes$`(lower`[5] < 1) & (MIcombineRes$`upper)`[5]>1)
    },
    TRUE
  )

})

test_that("Flexsurv imputation errors if NA in event time variable", {
            skip_on_cran()
            expect_error(
              {
                set.seed(1234)
                n <- 1000
                z <- rnorm(n)
                x <- 1*(runif(n)<plogis(z))
                t <- -log(runif(n)) / (1 * exp(x + z))
                d <- 1 * (t < 10)
                t[d == 0] <- 10
                x[(runif(n) < 0.5)] <- NA
                t[1] <- NA

                simData <- data.frame(t, d, x, z)

                imps <- smcfcs.flexsurv(simData,
                                        smformula = "Surv(t, d)~x+z",
                                        method = c("", "", "logreg", ""),
                                        k=2,
                                        imputeTimes=TRUE,
                                        originalKnots=FALSE
                )
              }
            )

})

test_that("Flexsurv imputation errors if NA in event indicator variable", {
  skip_on_cran()
  expect_error(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA
      d[1] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z",
                              method = c("", "", "logreg", ""),
                              k=2,
                              imputeTimes=TRUE,
                              originalKnots=FALSE
      )
    }
  )

})


test_that("Flexsurv imputation errors if time-varying effect used for fully obs cts cov", {
  skip_on_cran()
  expect_error(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      z[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z+gamma1(z)",
                              method = c("", "", "", "norm"),
                              k=2
      )
    }
    )

})

test_that("Flexsurv imputation doesn't error if time-varying effect used for fully obs cts cov", {
  skip_on_cran()
  expect_error(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z+gamma1(z)",
                              method = c("", "", "logreg", ""),
                              k=2
      )
    }
  , NA)

})


test_that("Flexsurv imputation doesn't error if time-varying effect used for partial binary cov", {
  skip_on_cran()
  expect_error(
    {
      set.seed(1234)
      n <- 1000
      z <- rnorm(n)
      x <- 1*(runif(n)<plogis(z))
      t <- -log(runif(n)) / (1 * exp(x + z))
      d <- 1 * (t < 10)
      t[d == 0] <- 10
      x[(runif(n) < 0.5)] <- NA

      simData <- data.frame(t, d, x, z)

      imps <- smcfcs.flexsurv(simData,
                              smformula = "Surv(t, d)~x+z+gamma1(x)",
                              method = c("", "", "logreg", ""),
                              k=2
      )
    }
    , NA)

})

