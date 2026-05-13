# This function selects the recovery activity to include in the daily support message.

# Inputs: 
#   subid
#   top feature (calculated outside of this function)
#   data frame that serves as running record of past activity recommendations for all subids

# This script also references a reference activity csv file that contains all possible
# recommendations for each feature category. This file is pulled directly from the 
# aud_support github to ensure it is always up to date. 


get_activity <- function(s)