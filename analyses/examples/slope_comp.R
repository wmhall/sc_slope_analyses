library(tidyverse)
source("R/pvaluer.R")
library(lme4)

# read in data ------------------------------------------------------------

all_data <- 
  read_csv("data/preprocessed/all_data.csv")


# center variables --------------------------------------------------------


#group mean

all_data_person_centered <- 
  all_data %>% 
  group_by(ID) %>% 
  gather(var_name, var_resp, sit, burnout, 
         conv_pos_male, conv_pos_female) %>% 
  group_by(ID, var_name) %>% 
  summarise(var_mean = mean(var_resp, na.rm =T)) %>%
  mutate(var_name = paste0("person_mean_", var_name)) %>% 
  spread(var_name, var_mean) %>%
  left_join(all_data, .) %>% 
  mutate(
    sitC = sit - person_mean_sit, 
    conv_pos_maleC = conv_pos_male - 
      person_mean_conv_pos_male, 
    conv_pos_femaleC = conv_pos_female - 
      person_mean_conv_pos_female, 
    burnoutC = burnout - person_mean_burnout
  )

#grand mean
#cented with each study

all_dataC <- 
  all_data %>% 
  group_by(data_id) %>% 
  select(data_id,sc) %>% 
  summarise(study_mean_sc = mean(sc, na.rm=T)) %>% 
  left_join(all_data, .) %>% 
  mutate(scC = sc - study_mean_sc) %>% 
  select(ID, day_id, sc, scC, study_mean_sc) %>% 
  left_join(all_data_person_centered,.)

#define formulas

mf <- 
  c(male_p = 
      sit ~ 1 +  
      gender*conv_pos_maleC +
      gender*person_mean_conv_pos_male +
      (1 + conv_pos_maleC|ID), 
    female_p = 
      sit ~ 1 +  
      gender*conv_pos_femaleC +
      gender*person_mean_conv_pos_female +
      (1 + conv_pos_femaleC|ID))

mf_df <- data_frame(conv_pg = names(mf), mf = mf)
  

data_df <- 
data_frame(data = list(all_dataC)) 


model_df <- mf_df
model_df$data <- list(all_dataC)

fm_df <- 
model_df %>% 
  mutate(fm = map2(mf, data, lmer))

slope_comp <- function(fm_obj) {
  coef(fm_obj) %>% 
    .$ID %>% 
    mutate(., ID = row.names(.))
}

slope_df <- 
  fm_df %>% 
  mutate(slopes = map(fm, slope_comp))

#get slopes as split by study

model_df_by_study <- 
model_df %>%
  select(-mf) %>% 
  unnest %>% 
  nest(-data_id, -conv_pg) %>% 
  left_join(mf_df)

fm_df_by_study <- 
  model_df_by_study %>% 
  mutate(fm = map2(mf, data, lmer))

slope_df_by_study <- 
fm_df_by_study %>% 
  mutate(slopes = map(fm, slope_comp))
  

# write out the data ------------------------------------------------------

write_rds(slope_df, "output/slopes_overall.rds")
write_rds(slope_df_by_study, "output/slopes_by_study.rds")
