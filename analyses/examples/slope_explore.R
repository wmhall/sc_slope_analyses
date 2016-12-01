library(tidyverse)

file_names <- c(by_study = 
                  "output/slopes_by_study.rds", 
                overall = 
                  "output/slopes_overall.rds")

slopes_list <- 
  map(file_names, read_rds)

sc_data <- 
  read_csv("data/preprocessed/all_data.csv") %>% 
  select(ID, gender, data_id, sc) %>% 
  distinct()


clean_slopes <- . %>% 
  select(conv_pg, slopes) %>% 
  unnest %>% 
  select(ID, conv_pg, conv_pos_femaleC, conv_pos_maleC) %>% 
  gather(var_id, slope, conv_pos_femaleC, conv_pos_maleC) %>% 
  select(-conv_pg) %>% 
  drop_na() %>% 
  spread(var_id, slope) %>% 
  mutate(ID = as.integer(ID))


slope_overall_df <- 
  slopes_list$overall %>% clean_slopes

model_data <- 
  left_join(sc_data, slope_overall_df)

mf <- 
  c(male_cp = conv_pos_maleC ~ 1 + sc*gender, 
    female_cp = conv_pos_femaleC ~ 1 + sc*gender)

mf_df <- 
  data_frame(mid = names(mf), mf= mf )

femaleC_df <- model_data %>% mutate(gender = if_else(gender == "Female", 0, 1))
maleC_df <- model_data %>% mutate(gender = if_else(gender == "Male", 0, 1))

data_df <- 
  data_frame(gender_id = c("female", "male"), 
             data = list(femaleC_df, maleC_df))

model_df <- 
  data_df %>% tidyr::expand(gender_id, mid = mf_df$mid) %>% 
  left_join(data_df) %>% 
  left_join(mf_df)

fm_df <- 
  model_df %>% 
  mutate(fm = map2(mf, data, lm), 
         fm_tidy = map(fm, broom::tidy))

fm_df %>% 
  select(gender_id, fm_tidy, mid) %>% 
  unnest %>% 
  filter(term == "sc")


plot_lm <- function(m_data) {
  ggplot(m_data, aes(y = slope, x = sc, color = gender)) +
    geom_point() + 
    geom_smooth(method = "lm", se = F) 
}


plot_data_overall <- 
  model_data %>% 
  gather(slope_name, slope, conv_pos_femaleC, conv_pos_maleC) %>% 
  nest(-slope_name) %>%
  mutate(plots = map(data, plot_lm))



# slope anlyses, split by study -------------------------------------------

slope_data_by_study_df <- 
  slopes_list$by_study %>%
  split(.$data_id) %>% 
  map(clean_slopes) %>% 
  bind_rows(.id = "data_id")

model_data_by_study <- 
  left_join(sc_data, slope_data_by_study_df) %>% 
  nest(-data_id) %>% 
  mutate(female = map(data, mutate, gender = if_else(gender == "Female",0, 1))) %>% 
  mutate(male = map(data, mutate, gender = if_else(gender == "Female",1, 0))) %>% 
  select(-data) %>% 
  gather(gender_id, data, female, male)

model_df_by_study <- 
  model_df %>% tidyr::expand(gender_id, mid, data_id = slope_data_by_study_df$data_id) %>% 
  left_join(model_data_by_study) %>% 
  left_join(mf_df)

fm_by_study <- 
  model_df_by_study %>% 
  mutate(fm = map2(mf, data, lm), 
         fm_tidy = map(fm, broom::tidy))

fm_by_study %>% 
  select(gender_id, mid, data_id, fm_tidy) %>% 
  unnest() %>% 
  filter(term == "sc" & data_id == "ees")


plots_by_study <- 
  model_data_by_study %>% 
  filter(gender_id == "female") %>% 
  mutate(data = map(data, mutate, gender = if_else(gender == 0, "Female", "Male"))) %>% 
  unnest() %>% 
  gather(slope_name, slope, conv_pos_femaleC, conv_pos_maleC) %>% 
  nest(-data_id, -slope_name) %>% 
  mutate(plots = map(data, plot_lm))


# write out the analyses --------------------------------------------------

files_to_write <- 
  list(fm_slope_overall.rds = fm_df,
       fm_slope_by_study.rds = fm_by_study,
       plots_overall.rds = plot_data_overall,
       plots_by_study.rds = plots_by_study)

#write files

walk2(files_to_write, 
      paste0("output/", 
             names(files_to_write)), write_rds)
