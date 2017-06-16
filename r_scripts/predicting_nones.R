

# predicting nones


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



#' ####################################################
#' Exploring and Predicting "None"
#' Author: Taylor Van Anne
#' This is going to be a submission where we just literally submit the users
#' products that were re-ordered on their order immediately before their "test" order
#' #####################################################


library(dplyr)
library(ggplot2)



orders <- readRDS('input/orders.rds')
orders_train <- orders[orders$eval_set == 'train',]
denorm <- readRDS('input/denorm.rds')
denorm_priors <- denorm[denorm$eval_set == 'prior',]
denorm_train <- denorm[denorm$eval_set == 'train',]


# so we have day of the week and hour of day...
# this can be converted to an "hour of week" figure which I think will be very useful for more granularity
# if we don't see anything there, then we'll take a step back up to either day of week or hour of day


orders$order_hw <- ((orders$order_dow * 24) + orders$order_hour_of_day)


hist(orders$order_hw, col='light blue', main='Histogram: Orders at Each "Hour of the Week"',
     breaks=50, xlab="Hour of the Week")

    #' ok cool, seeing the usual daily "seasonality" of peak hours as expected, let's combine this with a count of
    #' reordered products per order.


# this type of analysis should only be at the "train/test" (last order available) level, not the "priors" level (yet at least)
train_reo_per_o <- dplyr::group_by(denorm_train, order_id) %>%
    dplyr::summarise(count_reordered_prods = sum(reordered))

orders_train <- merge(x=orders_train, y=train_reo_per_o, by="order_id", all=T)

head(orders_train)



# this would likely be better displayed as a heatmap, each square would be a 1x1 unit square/rect and would show
# the % of orders that had zero re-ordered products (maybe it would be best to add DoW back in for y axis)
ggplot(data=orders_train, aes(x=order_hw, y=count_reordered_prods)) +
    geom_point(alpha=0.01)





