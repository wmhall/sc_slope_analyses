library(tidyverse)

compute_r_tidy <- function(lmer_model, meth = "nsj") {
  vars_to_square <- c("Rsq", "upper.CL", "lower.CL")
  lmer_model %>% r2glmm::r2beta(method = meth) %>% 
    map_at(vars_to_square, sqrt) %>% 
    map_if(is.numeric, round, 2) %>% 
    as_data_frame %>% 
    select(Effect, r = Rsq, upper.CL, lower.CL)  
}
