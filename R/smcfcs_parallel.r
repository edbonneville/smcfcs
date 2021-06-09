#' Parallel substantive model compatible imputation
#'
#' Runs substantive model compatible imputation using parallel cores
#'
#' This function can be used to call one of the substantive model compatible imputation
#' methods using parallel cores, to reduce computation time. You must specify
#' the arguments required for the standard smcfcs call, and then specify your
#' the arguments for how to use parallel cores.
#'
#' @author Edouard Bonneville \email{e.f.bonneville@@lumc.nl}
#' @author Jonathan Bartlett \email{j.w.bartlett@@bath.ac.uk}
#'
#' @param smcfcs_func Specifies which base smcfcs function to call. Possible values
#' are `smcfcs`, `smcfcs.casecohort`, `smcfcs.dtasam`, `smcfcs.nestedcc`. Defaults
#' to `smcfcs`.
#' @param seed Optional seed, set as `set.seed` when `n_cores = 1`,
#' or as `parallel::clusterSetRNGStream` when `n_cores > 1`.
#' @param m Number of imputed datasets to generate.
#' @param n_cores Number of cores over which to split the `m` imputations. If
#' `n_cores` is not divisible exactly by `m`, one of the cores will perform
#' more/less imputations that the rest such that the final result still contains
#' `m` imputed datasets.
#' @param m_per_core Optional number of imputations per core.
#' Default is `floor(m / n_cores)`, which it cannot be larger than.
#' @param cl_type Either "PSOCK" or "FORK". If running on a Windows system
#' "PSOCK" is recommended, otherwise for Linux/Mac machines "FORK" tends to
#' offer faster computation - see \link[mice]{parlmice}.
#' @param outfile Optional character path to location for
#' output from the workers. Useful to diagnose rejection sampling warnings.
#' File path must be formulated as "path/to/filename.txt".
#' @param ... Additional arguments to pass on to \link[smcfcs]{smcfcs},
#' \link[smcfcs.casecohort]{smcfcs.casecohort},
#' \link[smcfcs.dtsam]{smcfcs.dtsam}, or
#' \link[smcfcs.nestedcc]{smcfcs.nestedcc}.
#'
#' @return An object of type "smcfcs", as would usually be returned from
#' \link[smcfcs]{smcfcs}.
#' @export
#'
#' @examples
#' \dontrun{
#' # Detect number of cores
#' parallel::detectCores()
#'
#' imps <- smcfcs.parallel(
#' smcfcs_func="smcfcs",
#' seed = 2021,
#' n_cores = parallel::detectCores() - 1,
#' originaldata = smcfcs::ex_compet,
#' m = 10,
#' smtype = "compet",
#' smformula = list(
#' "Surv(t, d == 1) ~ x1 + x2",
#' "Surv(t, d == 2) ~ x1 + x2"
#' ),
#' method = c("", "", "norm", "norm")
#' )
#' }
smcfcs.parallel <- function(smcfcs_func="smcfcs",
                       seed = NULL,
                       m = 5,
                       m_per_core = NULL,
                       n_cores = parallel::detectCores() - 1,
                       cl_type = "PSOCK",
                       outfile = "",
                       ...) {

  checkmate::matchArg(x= smcfcs_func, choices=c("smcfcs", "smcfcs.casecohort",
                                                "smcfcs.dtsam", "smcfcs.nestedcc"))

  # Check smcfcs arguments
  args <- list(...)
  if (smcfcs_func=="smcfcs") {
    args_smcfcs <- names(formals(smcfcs::smcfcs))
  } else if (smcfcs_func=="smcfcs.casecohort") {
    args_smcfcs <- names(formals(smcfcs::smcfcs.casecohort))
  } else if (smcfcs_func=="smcfcs.dtsam") {
    args_smcfcs <- names(formals(smcfcs::smcfcs.dtsam))
  } else {
    #smcfcs.nestedcc
    args_smcfcs <- names(formals(smcfcs::smcfcs.nestedcc))
  }
  check_args <- !(names(args) %in% args_smcfcs)

  if (any(check_args)) {
    wrong_args <- paste(names(args)[check_args], collapse = ", ")
    if (smcfcs_func=="smcfcs") {
      mssg <- paste0("The following are not valid arguments of smcfcs::smcfcs : ", wrong_args)
    } else if (smcfcs_func=="smcfcs.casecohort") {
      mssg <- paste0("The following are not valid arguments of smcfcs::smcfcs.casecohort : ", wrong_args)
    } else if (smcfcs_func=="smcfcs.dtsam") {
      mssg <- paste0("The following are not valid arguments of smcfcs::smcfcs.dtsam : ", wrong_args)
    } else {
      #smcfcs.nestedcc
      mssg <- paste0("The following are not valid arguments of smcfcs::smcfcs.nestedcc : ", wrong_args)
    }
    stop(mssg)
  }

  # Check parallel arguments
  checkmate::assert_numeric(x = seed, null.ok = TRUE, any.missing = FALSE, len = 1)
  checkmate::assert_int(x = m, lower = 1)
  checkmate::assert_int(x = m_per_core, lower = 1, upper = floor(m / n_cores), null.ok = TRUE)
  checkmate::matchArg(x = cl_type, choices = c("PSOCK", "FORK"))
  checkmate::assert_int(x = n_cores, lower = 1, upper = min(parallel::detectCores(), m))
  if (outfile != "") checkmate::assert_path_for_output(x = outfile, overwrite = TRUE)

  # Standard smcfcs if n_cores = 1
  if (n_cores == 1) {
    if (!is.null(seed)) set.seed(seed)
    args$m <- m

    res <- do.call(paste("smcfcs::", smcfcs_func, sep=""), args)

  } else {

    # Determine number of imputations per core
    imp_specs <- determine_imp_specs(n_cores, m, m_per_core)

    # Set up the cluster
    cl <- parallel::makeCluster(n_cores, type = cl_type, outfile = outfile)
    if (!is.null(seed)) parallel::clusterSetRNGStream(cl, seed)

    parallel::clusterExport(
      cl = cl,
      varlist = c("args", "imp_specs", "seed", "m", "n_cores", "cl_type", "Surv", "strata",
                  "smcfcs", "smcfcs.casecohort", "smcfcs.dtsam", "smcfcs.nestedcc"),
      envir = environment()
    )

    # Run the imputations
    if (smcfcs_func=="smcfcs") {
      imps <- parallel::parLapply(cl = cl, X = 1:length(imp_specs), function(x) {
        args$m <- imp_specs[x]
        do.call(smcfcs::smcfcs, args)
      })
    } else if (smcfcs_func=="smcfcs.casecohort") {
      imps <- parallel::parLapply(cl = cl, X = 1:length(imp_specs), function(x) {
        args$m <- imp_specs[x]
        do.call(smcfcs::smcfcs.casecohort, args)
      })
    } else if (smcfcs_func=="smcfcs.dtsam") {
      imps <- parallel::parLapply(cl = cl, X = 1:length(imp_specs), function(x) {
        args$m <- imp_specs[x]
        do.call(smcfcs::smcfcs.dtsam, args)
      })
    } else {
      #smcfcs.nestedcc
      imps <- parallel::parLapply(cl = cl, X = 1:length(imp_specs), function(x) {
        args$m <- imp_specs[x]
        do.call(smcfcs::smcfcs.nestedcc, args)
      })
    }

    parallel::stopCluster(cl)

    # Combine imputations
    res <- combine_smcfcs_objects(imps)
  }

  return(res)
}


# Prepare imputations per core
determine_imp_specs <- function(n_cores,
                                m,
                                m_per_core) {

  if (!is.null(m_per_core)) {
    imp_specs <- rep(m_per_core, times = floor(m / m_per_core))
    modul <- m %% m_per_core
  } else {
    imp_specs <- rep(floor(m / n_cores), times = n_cores)
    modul <- m %% n_cores
  }

  # Add remaining imps to add to m
  if (modul != 0) imp_specs[length(imp_specs)] <- imp_specs[length(imp_specs)] + modul
  return(imp_specs)
}


# Helper to combine smcfcs objects
combine_smcfcs_objects <- function(smcfcs_list) {

  # Combine imputed datasets
  ls_impdats <- do.call("c",  lapply(smcfcs_list, "[[", "impDatasets"))

  # Combine monitoring of imputations
  coef_array <- abind::abind(lapply(smcfcs_list, "[[", "smCoefIter"), along = 1)

  # Polish and return
  res <- list(
    impDatasets = ls_impdats,
    smCoefIter = coef_array,
    smInfo = list(
      smtype = smcfcs_list[[1]]$smInfo$smtype,
      smformula = smcfcs_list[[1]]$smInfo$smformula
    )
  )

  class(res) <- "smcfcs"
  return(res)
}