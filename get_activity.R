# This function selects the recovery activity to include in the daily support message.
# date: 5/13/2026
# author: Kendra Wyant

# Inputs: 
#   subid
#   dttm_obs: date and time of observation that top feature is calculated for
#   top_feature: top feature for a single observation (calculated outside of this function)
#   path_data: path to data to read in and write out running df of past activity 
#   recommendations for all subids

# This script also references activities.csv, a file that contains all possible
# recommendations for each feature category. This file is pulled directly from the 
# aud_support github to ensure it is always up to date. 


get_activity <- function(subid, dttm_obs, top_feature, path_data) {
  
  # read in reference activity csv file from github
  ref_activities <- read_csv("https://raw.githubusercontent.com/jjcurtin/aud_support/refs/heads/main/modules/activities.csv",
                             show_col_types = FALSE)
  
  # read in past activities and save number of rows for check later 
  past_activities <- read_csv(here::here(path_data, "past_activities.csv"),
                              show_col_types = FALSE)
  
  # filter past_activities to subid and pull past activities
  # This will result in vector of qmd files for activities subid has seen
  # It includes all activities across features because some can be in more than
  # one category
  past_activities_subid <- past_activities |> 
    filter(.data$subid == subid) |> 
    pull(activity)
  
  # rename top_features that are combined for recommendation
  if (top_feature %in% c("efficacy_motivation_week", "efficacy_motivation_recent")) {
    top_feature <- "efficacy_motivation"
  }
  # this one can be deleted after JC updates his script to combine these categories
  if (top_feature %in% c("locs_hi_risk", "locs_mod_risk")) {
    top_feature <- "locs_risk"
  }
  
  # filter reference df to top_feature category and pull out activities in numeric order
  rec <- ref_activities |> 
    select(activity, all_of(top_feature), can_repeat) |> 
    filter(!is.na(.data[[top_feature]])) |> 
    arrange(.data[[top_feature]])
  
  # pull out next sequential activity that has not been shown to subid
  # if none left start over and return first activity that can repeat
  activity <-  rec |> 
    filter(!activity %in% past_activities_subid) |> 
    slice(1) 

  if (nrow(activity) == 0) {
    # revisit all activities for a category. 
    # Filter out ones that cannot be retained
    # take first sequential activity and update counter
    final_activity <- enframe(past_activities_subid, value = "activity") |>
      group_by(activity) |> 
      count() |> 
      ungroup() |> 
      right_join(rec |> 
                  filter(can_repeat), by = "activity") |>
      arrange(n, .data[[top_feature]]) |> 
      slice(1) |> 
      pull(activity)
  } else {
    final_activity <- activity |> 
      pull(activity)
  }
  
  # add activity to running df log of activities
  # this method will only append the line and not overwrite the entire df
  tibble(subid = subid, dttm_obs = dttm_obs, top_feature = top_feature, activity = final_activity) |> 
    write_csv(here::here(path_data, "past_activities.csv"), append = TRUE) 
    
  
  return(activity)
  
}
