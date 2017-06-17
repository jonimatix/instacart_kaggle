

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
library(viridis)



orders <- readRDS('input/orders.rds')
orders$order_hw <- ((orders$order_dow * 24) + orders$order_hour_of_day)
orders_train <- orders[orders$eval_set == 'train',]
denorm <- readRDS('input/denorm.rds')
denorm_priors <- denorm[denorm$eval_set == 'prior',]
denorm_train <- denorm[denorm$eval_set == 'train',]


# so we have day of the week and hour of day...
# this can be converted to an "hour of week" figure which I think will be very useful for more granularity
# if we don't see anything there, then we'll take a step back up to either day of week or hour of day





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


# order train, day-hour group
ot_dhg <- dplyr::group_by(orders_train, order_dow, order_hour_of_day) %>%
    dplyr::summarise(count_of_zero_reorder_orders = sum(count_reordered_prods == 0),
                     count_of_all_orders = n_distinct(order_id))

ot_dhg$percent_zero_reord <- (ot_dhg$count_of_zero_reorder_orders / ot_dhg$count_of_all_orders) * 100


# This is actually a pretty interesting plot..
ggplot(ot_dhg, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reord)) +
    geom_tile(color='White', size=0.1) +
    scale_fill_viridis(name="Percent zero reorders") +
    coord_equal() + ggtitle("Train Orders: Percent of Zero-Reorder Orders by Day / Hour")

    #' The hours between 1 - 6 are very volatile, specifically hour 3. Hour 3 is one of 
    #' the most likely times to have a zero-reorder order on day-of-the-week (dotw) 3, but
    #' on dotw 1, it is one of the LEAST likely!
    #' Keep in mind this plot was created only from the "train" dataset. I'm thinking it would
    #' be beneficial to conduct the same plot on each user's train - 1 dataset (the order immediately
    #' prior to the train data being captured). That will help us determine the validity of our results.
    #' We should also do that for the test - 1 set as well.



#' let me be clear of my intentions here. I want to isolate the priors that are immediately before the
#' "train" and the "test" orders (but keep these groups separate). Then run the heatmap plot as done above.
orders <- dplyr::arrange(orders, user_id, order_number)
orders2 <- dplyr::group_by(orders, user_id) %>%
    dplyr::mutate(prev_order = lag(x=order_id, n=1, order_by=order_number)) %>%
    dplyr::ungroup() %>%
    dplyr::select(order_id, eval_set, prev_order) %>%
    data.frame()


# these aren't needed unless doing detailed analysis, not sure why I built these...
# orders_train_min1 <- orders2[orders2$eval_set == 'train',]
# denorm_train_min1 <- denorm[denorm$order_id %in% orders_train_min1$prev_order,]


# these are the order_id's of interest
order_id_train_m1 <- orders2$prev_order[orders2$eval_set == 'train']
order_id_test_m1 <- orders2$prev_order[orders2$eval_set == 'test']

# this is the orders data.frame filtered to the order_id's of interest
orders_train_m1 <- orders2[orders2$order_id %in% order_id_train_m1,]
orders_test_m1 <- orders2[orders2$order_id %in% order_id_test_m1,]

denorm_train_m1 <- denorm[denorm$order_id %in% order_id_train_m1,]
denorm_test_m1 <- denorm[denorm$order_id %in% order_id_test_m1,]


# this is where I was!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
reorder_per_order_train_m1 <- dplyr::group_by(denorm_train_m1)


# order train (minus 1) - day hour groups
otrain_m1_dhg <- dplyr::group_by(orders_train_m1, order_dow, order_hour_of_day) %>%
    dplyr::summarise(count_of_zero_reorder_orders = sum(count_reordered_prods == 0),
                     count_of_all_orders = n_distinct(order_id))





