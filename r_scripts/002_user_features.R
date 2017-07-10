

# round one of all user based features generation


# SCRIPT SETUP -----------------------------------------------------------------------------------------------------

    # load libraries
    library(rstudioapi)
    library(dplyr)
    # library(data.table)
    
    
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

    


        
# LOAD DATA -----------------------------------------------------------------------------------
    
    # this should be all we need
    order_detail <- readRDS('input/order_detail.rds')
    order <- readRDS('input/orders.rds')
    
    
    # to reset quicker
    order_detail_og <- order_detail
    order_detail <- order_detail_og
    
            
# USER ORDER-DETAIL FEATURES -------------------------------------------------------------------------------
    
    
    # JUST FOR TESTING TO MAKE THINGS MOVE A BIT QUICKER WHILE BUILDING FEATURES
    order_detail <- order_detail[1:100000,]
    
    
    # users pre - isolating only the reordered items
    users_od_pre1 <- order_detail %>%
        dplyr::filter(reordered == 1) %>%
        dplyr::filter(eval_set == 'prior') %>%
        dplyr::group_by(user_id) %>%
        dplyr::summarise(
            user_od_dist_reorder_prod = n_distinct(product_id)
        )
        
    
    
    # users1 - going to go for 
    users_od1 <- order_detail %>%
        dplyr::filter(eval_set == 'prior') %>%
        dplyr::group_by(user_id) %>%
        dplyr::summarise(
            user_od_total_products = n(),  # this is at the product/item dimension 
            user_od_total_reorder_prod = sum(reordered == 1, na.rm=T),
            user_od_reorder_ratio = user_od_total_reorder_prod / sum(order_number > 1, na.rm=T),
            user_od_distinct_products = n_distinct(product_id),
            user_od_product_variety = user_od_distinct_products / user_od_total_products,
            user_od_reorder_prod_ratio = sum(reordered == 1, na.rm=T) / sum(order_number > 1, na.rm=T)
        )
        
    
    # quick join
    users_od2 <- merge(users_od1, users_od_pre1, by='user_id', all.x=T, all.y=F)
    sum(is.na(users_od2$user_od_dist_reorder_prod))
    users_od2$user_od_dist_reorder_prod[is.na(users_od2$user_od_dist_reorder_prod)] <- 0
    users_od2$user_od_total_reorder_prod[is.na(users_od2$user_od_total_reorder_prod)] <- 0
    
    
    # more features -- this is currently creating 3045 NaN values, need to fix that next
    users_od2$user_od_reorder_dist_to_all_dist_prod <- users_od2$user_od_dist_reorder_prod / users_od2$user_od_total_reorder_prod
    
    sum(is.na(users_od2$user_od_total_reorder_prod))
    sum(is.na(users_od2$user_od_dist_reorder_prod))
    users_od2[is.na(users_od2$user_od_reorder_dist_to_all_dist_prod), ]
    
    
    
    sapply(users_od2, function(x) sum(is.na(x)))
    
    
    
    
    
    
    
    
    
    
    
    
    