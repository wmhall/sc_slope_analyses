source("R/pvaluer.R")

# function to get model estimates -----------------------------------------

get_estimates <- . %>% 
  gather(model_key, fm, female_ps_fm, male_ps_fm) %>% 
  mutate(tidy_fm = map(fm, tidy, effects = "fixed")) %>% 
  select(mf_name, model_key, tidy_fm) %>% 
  unnest() %>% 
  mutate(est_var = std.error^2) %>% 
  select(-std.error, -statistic)


# function to get covariance info -----------------------------------------

get_eb_covar <- function(model_df, patha_term, pathb_term) {
  gather(model_df, model_key, fm, female_ps_fm, male_ps_fm) %>% 
    mutate(slopes = map(fm, ~coef(.) %>% .$ID %>% mutate(., ID = row.names(.)))) %>% 
    select(mf_name, model_key, slopes) %>% 
    unnest() %>% 
    gather(slope_key, slope, -mf_name, -model_key, -ID) %>% 
    filter(slope_key == pathb_term & mf_name == "path_b" | 
             slope_key == patha_term & mf_name == "path_a") %>% 
    select(-slope_key) %>% 
    spread(mf_name, slope) %>% 
    nest(-model_key) %>% 
    mutate(covar = map_dbl(data, ~cov(.$path_a, .$path_b))) %>% 
    select(-data)
} 


# function to get data for boot sample ------------------------------------

get_med_data <- function(estimates_df, covar_data, patha_term, pathb_term, int = F) {
  
  df <- left_join(estimates_df, covar_data) %>% 
    filter(term == pathb_term & mf_name == "path_b" | 
             term == patha_term & mf_name == "path_a") %>% 
    select(-term) %>% 
    nest(-model_key) %>% 
    mutate(estimates = map(data, ~ select(., mf_name, estimate) %>% 
                             spread(., mf_name, estimate)), 
           est_var = map(data, ~ select(., mf_name, est_var) %>% 
                           spread(., mf_name, est_var) %>% 
                           rename(var_path_a = path_a, var_path_b = path_b)), 
           covar = map(data, ~ select(.,covar) %>%  distinct(.))) %>% 
    select(-data) %>% 
    unnest()
  
  if (int == T) {
    return(df %>% mutate(model_key = "int", covar = 0))
  } else return(df)
  
}

get_boot_data <- . %>% 
  mutate(pest = map2(path_a, path_b, c),
         cov_data = pmap(list(var_path_a, covar, covar, var_path_b), c), 
         acov = map(cov_data, matrix, 2,2), 
         mcmc = pmap(list(20000, pest, acov), 
                     MASS::mvrnorm, empirical = FALSE)) 

get_med_output <- . %>% 
  select(model_key, path_a, path_b, covar, mcmc) %>%
  mutate(ab = path_a*path_b,
         ab_dist = map(mcmc, ~ .[,1]*.[,2]),
         sd = map_dbl(ab_dist, ~ sd(.)), 
         z = (ab + covar)/sd, 
         p.value = map_dbl(z, z2p), 
         lwr_ci = map_dbl(ab_dist, quantile, 0.025), 
         upr_ci = map_dbl(ab_dist, quantile, 0.975)) %>% 
  select(model_key, ab, lwr_ci, upr_ci, z, p.value)

# test mediation using combined data --------------------------------------


test_mediation <- function(raw_data, model_fomrulas, 
                           patha_main, pathb_main, patha_int, pathb_int) {
  
  model_data <- get_model_data(raw_data, model_fomrulas)
  model_estimates <- model_data %>% get_estimates
  eb_covar <- model_data %>% get_eb_covar(patha_main, pathb_main)
  
  med_data <- 
    get_med_data(model_estimates, eb_covar,patha_main ,pathb_main)
  
  int_med_data <- 
    get_med_data(model_estimates, eb_covar, patha_int, pathb_int, int =T) 
  
  med_data_all <- 
    bind_rows(med_data, int_med_data)
  
  boot_data <- 
    med_data_all %>% get_boot_data
  
  med_output <- boot_data %>% get_med_output
  
  mediation_tidy <- 
    med_output %>% 
    map_if(is.numeric, round, 2) %>%
    map_at("p.value", format_pval) %>% 
    as_data_frame
  
  mediation_tidy  
}
