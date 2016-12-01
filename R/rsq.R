library(tidyverse)
library(lmerTest)

rsq_compute <- function(raw_data) {
  test_this <- data_frame(mf = mf, 
                          mf_names = names(mf)) %>% 
    mutate(fm = map(mf, lmer, data = raw_data))
  anova_added <- 
    test_this %>% 
    mutate(anova_fm = map(fm, anova, ddf = "Kenward-Roger"), 
           anova_fm = map(anova_fm, ~ data.frame(., term = row.names(.))))
  rsq_df <- anova_added %>%  
    select(mf_names, anova_fm) %>% 
    unnest() %>% 
    rowwise() %>% 
    mutate(rsq = 
             ((NumDF/DenDF)*F.value)/(1 + ((NumDF/DenDF)*F.value)), 
           r = sqrt(rsq)) %>% 
    select(mf_names, term, rsq, r)
  return(rsq_df)
} 