


# instacart workflow -- this is the master R script which controls everything else

# SCRIPT SETUP -----------------------------------------------------------------------------------------------------

    # load libraries
        library(rstudioapi)
    
    
    # recursively find the directory I want to be set to wd (setwd())
        recursive_dirname <- function(target_dir, fp) {
            
            rgx_after_last_slash <- regexpr("([^/]+$)", fp)
            char_after_last_slash <- substr(fp, rgx_after_last_slash, attr(rgx_after_last_slash, 'match.length') + rgx_after_last_slash)
            
            if(fp == dirname(fp)) {
                warning("the target_dir was not found")
                return(NA)
            }
            
            if (target_dir == char_after_last_slash) {
                print(paste0('found it, returning: ', fp))
                return(fp)
            } else {
                print(fp)
                return(recursive_dirname(target_dir, dirname(fp)))
            }
        }
        
        
        
    # recursively search for the correct directory to set our wd to
    mywd <- recursive_dirname('kaggle_instacart', rstudioapi::getActiveDocumentContext()$path)
    setwd(mywd)
    list.files('input')
        



# WORKFLOW STARTS HERE ----------------------------------------------------------------------------    
    
# "conserve_ram" boolean variable set within the script
source("denormalize.R")


    
    
    
    
    
    
    
    
    


