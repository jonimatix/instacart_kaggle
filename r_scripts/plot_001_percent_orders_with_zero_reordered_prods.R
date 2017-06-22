



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


#' The goal here is to visualize what hours of each day make up the highest percentage of orders that
#' contain zero reordered products. In other words, we want to identify the hours within each day of the
#' week that contain the highest proportion of orders that contain entirely new items for that user_id


#' Steps:
#' 1) isolate order_products (orders with detailed line items) for train and test
#' 2) create a mapping table between train orders and train-1, train-2, train-3
#'     - "train-2" for example means the order_id two orders back for that user from their train order
#' 3) for whichever subset you're looking at, calculate the total number of reordered products for each order_id
#' 4) use that ^^^ to calculate the number of those orders that had zero reordered products, and those that had > zero.
#' 5) group that ^^^ by hour and week which may need to be joined in from a version of "orders" data
#' 6) plot
#' 7) profit



library(dplyr)
library(ggplot2)
library(viridis)

# read in data
list.files('input')
order_products_prior <- read.csv('input/order_products__prior.csv', stringsAsFactors = F)
order_products_train <- read.csv('input/order_products__train.csv', stringsAsFactors = F)
orders <- read.csv('input/orders.csv', stringsAsFactors = F)


# create an hour-in-week field (do this now, because we want it on both train and test)
orders$order_hw <- ((orders$order_dow * 24) + orders$order_hour_of_day)


# quick histogram to see what hours in the week are most popular for purchases
hist(orders$order_hw, col='light blue', main='Histogram: "Train" Orders at Each Hour of the Week',
     breaks=50, xlab="Hour of the Week")

#' ok cool, seeing the usual daily "seasonality" of peak hours as expected, let's combine this with a count of
#' reordered products per order. Not too helpful yet. This doesn't really tell us much, let's continue



# first, let's look at the train orders to see how 

# 1) order details are already isolated for train, we can isolate the aggregated order_id data for train and test though
orders_train <- orders[orders$eval_set == 'train',]
orders_test <- orders[orders$eval_set == 'test',]

# 2) we don't need to create the mapping table yet, so we can do that later
# 3) sum up the total number of reordered items per order_id in train
train_reordered_counts <- dplyr::group_by(order_products_train, order_id) %>%
    dplyr::summarise(count_reordered_products = sum(reordered)) %>%
    data.frame() %>%  
    dplyr::right_join(orders_train)  # 4)


# Minor detour! let's see if there are patterns between count of reordered products and order hour-in-week
ggplot(data=orders_train, aes(x=order_hw, y=count_reordered_products)) +
    geom_point(alpha=0.02, color='blue')

#' hour of the week vs the count of reordered products per order_id, not really much of a pattern to see here
#' other than just the standard seasonality type stuff.

# 5) order train, day-hour group
order_dayhour_grp_train <- dplyr::group_by(orders_train, order_dow, order_hour_of_day) %>%
    dplyr::summarise(count_of_zero_reorder_orders = sum(count_reordered_products == 0),
                     count_of_all_orders = n_distinct(order_id)) %>%
    dplyr::mutate(percent_orders_with_zero_reorders = (count_of_zero_reorder_orders / count_of_all_orders) * 100)

# 6) plot
ggplot(data=order_dayhour_grp_train, aes(x=order_hour_of_day, y=order_dow, fill=percent_orders_with_zero_reorders)) +
    geom_tile(color='White', size=0.1) +
    scale_fill_viridis(name="Percent zero reorders") +
    coord_equal() + ggtitle("Train Orders: Percent of Zero-Reorder Orders by Day / Hour")




# this corresponds to #2, creating the mapping table of previous orders
order_prev_order_mapping <- dplyr::group_by(orders, user_id) %>%
    dplyr::mutate(prev_order1 = lag(x=order_id, n=1, order_by=order_number),
                  prev_order2 = lag(x=order_id, n=2, order_by=order_number),
                  prev_order3 = lag(x=order_id, n=3, order_by=order_number),
                  prev_order4 = lag(x=order_id, n=4, order_by=order_number)) %>%
    dplyr::ungroup() %>%
    # dplyr::select(order_id, eval_set, prev_order) %>%  # I don't like this... it forces a join later on
    data.frame()



# now let's look at the order_ids that are immediately before the "test" order_ids for each user
order_id_test_m1 <- order_prev_order_mapping$prev_order1[order_prev_order_mapping$eval_set == 'test']
# order_products_prior_test_m1 <- order_products_prior[order_products_prior$



# these aren't needed unless doing detailed analysis, not sure why I built these...
# orders_train_min1 <- orders2[orders2$eval_set == 'train',]
# denorm_train_min1 <- denorm[denorm$order_id %in% orders_train_min1$prev_order,]


# these are the order_id's of interest
order_id_train_m1 <- orders2$prev_order[orders2$eval_set == 'train']
order_id_test_m1 <- orders2$prev_order[orders2$eval_set == 'test']


# this is the orders data.frame filtered to the order_id's of interest
orders_train_m1 <- orders2[orders2$order_id %in% order_id_train_m1,]
orders_test_m1 <- orders2[orders2$order_id %in% order_id_test_m1,]


# these are the order details necessary for determinine which orders had reordered products or not
denorm_train_m1 <- denorm[denorm$order_id %in% order_id_train_m1,]
denorm_test_m1 <- denorm[denorm$order_id %in% order_id_test_m1,]


# now group by to find the count of reordered products per order_id
reorder_per_order_train_m1 <- dplyr::group_by(denorm_train_m1, order_id) %>%
    dplyr::summarise(count_reordered_prods = sum(reordered))
reorder_per_order_test_m1 <- dplyr::group_by(denorm_test_m1, order_id) %>%
    dplyr::summarise(count_reordered_prods = sum(reordered))


# merge in the number of reordered products
orders_train_m1_2 <- merge(x=orders_train_m1, y=reorder_per_order_train_m1, by='order_id', all=T)
orders_test_m1_2 <- merge(x=orders_test_m1, y=reorder_per_order_test_m1, by='order_id', all=T)


# order train (minus 1) - day hour groups
otrain_m1_dhg <- dplyr::group_by(orders_train_m1_2, order_dow, order_hour_of_day) %>%
    dplyr::summarise(count_of_zero_reorder_orders = sum(count_reordered_prods == 0),
                     count_of_all_orders = n_distinct(order_id))
otest_m1_dhg <- dplyr::group_by(orders_test_m1_2, order_dow, order_hour_of_day) %>%
    dplyr::summarise(count_of_zero_reorder_orders = sum(count_reordered_prods == 0),
                     count_of_all_orders = n_distinct(order_id))


# now calculate the percent of orders with zero reordered products
otrain_m1_dhg$percent_zero_reord <- (otrain_m1_dhg$count_of_zero_reorder_orders / otrain_m1_dhg$count_of_all_orders) * 100
otest_m1_dhg$percent_zero_reord <- (otest_m1_dhg$count_of_zero_reorder_orders / otest_m1_dhg$count_of_all_orders) * 100


heatmap_desc <- "Percent of Orders with No Reordered Products by Day / Hour"


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


ggplot(otrain_m1_dhg, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reord)) +
    geom_tile(color='White', size=0.1) +
    scale_fill_viridis(name="Percent zero reorders") +
    coord_equal() + ggtitle("Train Minus-1 Orders: Percent of Zero-Reorder Orders by Day / Hour")

ggplot(otest_m1_dhg, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reord)) +
    geom_tile(color='White', size=0.1) +
    scale_fill_viridis(name="Percent zero reorders") +
    coord_equal() + ggtitle("Test Minus-1 Orders: Percent of Orders with No Reordered Products by Day / Hour")



# this is cool, but not as useful as I had thought it would be, because we need to group by user_id beforehand
x <- 1:10  # the values representing the number of records "back" we want to look, starting at 1
y <- 31:40 # the actual values that we're applying the lag to

# there must be a better way to do this, yea?
lag(y, 1)
lag(y, 2)

# create a wrapper! the wrapper switches the order of the parameters so we can use "apply" functions effectively
lagwrap <- function(numb, xvec, ord_by=NULL) {
    if(is.null(ord_by)) {
        return(dplyr::lag(xvec, numb))
    } else {
        return(dplyr::lag(xvec, numb, ord_by))
    }
}

sapply(x, lagwrap, y)




orders_lagged <- orders %>%
    dplyr::arrange(user_id, order_number) %>%
    dplyr::group_by(user_id) %>%
    dplyr::mutate(prev_order1 = lag(order_id, 1, order_by=order_number),
                  prev_order2 = lag(order_id, 2, order_by=order_number),
                  prev_order3 = lag(order_id, 3, order_by=order_number),
                  prev_order4 = lag(order_id, 4, order_by=order_number),
                  prev_order5 = lag(order_id, 5, order_by=order_number)) %>%
    dplyr::ungroup()



order_id_test <- orders_lagged$order_id[orders_lagged$eval_set == 'test']
order_id_train <- orders_lagged$order_id[orders_lagged$eval_set == 'train']
order_id_test_m1 <- orders_lagged$prev_order1[orders_lagged$eval_set == 'test']
order_id_test_m2 <- orders_lagged$prev_order2[orders_lagged$eval_set == 'test']
order_id_test_m3 <- orders_lagged$prev_order3[orders_lagged$eval_set == 'test']
order_id_train_m1 <- orders_lagged$prev_order1[orders_lagged$eval_set == 'train']
order_id_train_m2 <- orders_lagged$prev_order2[orders_lagged$eval_set == 'train']
order_id_train_m3 <- orders_lagged$prev_order3[orders_lagged$eval_set == 'train']



# can we define a function for this?
calc_percent_zero_reordered <- function(p_order_ids, p_order_details, p_order_header) {
    # p_order_ids     - the order id's we are interested in for this analysis
    # p_order_details - ALL order details; the function will be responsible for isolating what we need
    # p_order_header  - header-level order information such as day-of-week, hour-of-day, etc.
    
    
    print("Isolating the necessary order details...")
    dets <- p_order_details[p_order_details$order_id %in% p_order_ids, ]
    ords <- p_order_header[p_order_header$order_id %in% p_order_ids, ]
    
    
    print("Grouping and calculating the percent of orders with zero reordered products...")
    dets_sumreorder <- dplyr::group_by(dets, order_id) %>%
        dplyr::summarise(reordered_products_per_order = sum(reordered)) %>%
        dplyr::ungroup() %>%
        dplyr::right_join(ords) %>%
        dplyr::group_by(order_dow, order_hour_of_day) %>%
        dplyr::summarise(
            zero_reordered_prods = sum(reordered_products_per_order == 0),
            all_orders = n_distinct(order_id)
        ) %>%
        dplyr::mutate(percent_zero_reordered = (zero_reordered_prods / all_orders) * 100)
    
    return(dets_sumreorder)
}


# DRY: consistent plot labels for this first batch of plots
plot_subtitle_percent_zero_reorder <- "Percent of Orders with Zero Reordered Products"
plot_zero_reorder_x <- "Hour within Day"
plot_zero_reorder_y <- "Day within Week"
plot_zero_reorder_fill <- "Percent of Orders"


# calling the function we just wrote to produce the plot-ready data.frame
dow_hod_test_m1 <- calc_percent_zero_reordered(order_id_test_m1, order_products_prior, orders)

    # plotting the data
    ggplot(dow_hod_test_m1, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_zero_reorder_fill) +
        labs(x=plot_zero_reorder_x, y=plot_zero_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-1 Orders: ", plot_subtitle_percent_zero_reorder))

dow_hod_test_m2 <- calc_percent_zero_reordered(order_id_test_m2, order_products_prior, orders)

    ggplot(dow_hod_test_m2, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_zero_reorder_fill) +
        labs(x=plot_zero_reorder_x, y=plot_zero_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-2 Orders: ", plot_subtitle_percent_zero_reorder))

dow_hod_test_m3<- calc_percent_zero_reordered(order_id_test_m3, order_products_prior, orders)
    
    ggplot(dow_hod_test_m3, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_zero_reorder_fill) +
        labs(x=plot_zero_reorder_x, y=plot_zero_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-3 Orders: ", plot_subtitle_percent_zero_reorder))

# now train
dow_hod_train <- calc_percent_zero_reordered(order_id_train, order_products_train, orders)

    ggplot(dow_hod_train, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_zero_reorder_fill) +
        labs(x=plot_zero_reorder_x, y=plot_zero_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Orders: ", plot_subtitle_percent_zero_reorder))
        
    
dow_hod_train_m1 <- calc_percent_zero_reordered(order_id_train_m1, order_products_prior, orders)
    
    ggplot(dow_hod_train_m1, aes(x=order_hour_of_day, y=order_dow, fill=percent_zero_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_zero_reorder_fill) +
        labs(x=plot_zero_reorder_x, y=plot_zero_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Minus-2 Orders: ", plot_subtitle_percent_zero_reorder))
    
        #' maybe it isn't a good idea to calculate the percent of orders with zero reordered products. This is
        #' a little bit misleading, since those are the times of the day/week where there are fewest orders total, 
        #' so they are more susceptible to volatile data, plus there appears to be no distinct pattern. 
        #' 
        #' I think it would be better to determine the percent of products which are reorders based on the time
        #' the products were ordered
    
    
    
    
    
# percent of products ordered within a given day/hour slot that are reordered
    

order_details <- rbind(order_products_prior, order_products_train)

library(data.table)
setDT(order_details); setDT(orders)
order_details2 <- merge(x=order_details, y=orders, by='order_id', all.x=T, all.y=F)    
setDF(order_details2)    

sapply(order_details2, function(x) sum(is.na(x)))

head(order_details2)


# DRY: consistent plot labels
plot_subtitle_perc_prods_reordered <- "Percent of Products Reordered in Day/Hour Slot"
plot_perc_prods_reorder_x <- "Hour within Day"
plot_perc_prods_reorder_y <- "Day within Week"
plot_perc_prods_reorder_fill <- "Percent of Products"



# turn this into a function
calc_percent_prods_reordered <- function(p_order_ids, p_order_details) {
    
    print("isolating the required order details...")
    dets <- p_order_details[p_order_details$order_id %in% p_order_ids, ]
    
    print("grouping and calculating the percent of products reordered...")
    grpd <- dplyr::group_by(dets, order_dow, order_hour_of_day) %>%
        dplyr::summarise(
            count_reordered = sum(reordered),
            count_all = n()
        ) %>% ungroup() %>%
        dplyr::mutate(percent_reordered = (count_reordered / count_all) * 100)
      
    return(grpd)
}
    

# test minus 1
d_test_m1_grp <- calc_percent_prods_reordered(order_id_test_m1, order_details2)

    ggplot(d_test_m1_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-1 Orders: ", plot_subtitle_percent_zero_reorder))

    
# test minus 2
d_test_m2_grp <- calc_percent_prods_reordered(order_id_test_m2, order_details2)
    
    ggplot(d_test_m2_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-2 Orders: ", plot_subtitle_percent_zero_reorder))
    
    
# test minus 3
d_test_m3_grp <- calc_percent_prods_reordered(order_id_test_m3, order_details2)

    ggplot(d_test_m3_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Test Minus-3 Orders: ", plot_subtitle_percent_zero_reorder))
    
    
# train
    d_train_grp <- calc_percent_prods_reordered(order_id_train, order_details2)
    
    ggplot(d_train_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Orders: ", plot_subtitle_percent_zero_reorder))

        
# train minus 1
    d_train_m1_grp <- calc_percent_prods_reordered(order_id_train_m1, order_details2)
    
    ggplot(d_train_m1_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Minus-1 Orders: ", plot_subtitle_percent_zero_reorder))
    
    
# train minus 2
d_train_m2_grp <- calc_percent_prods_reordered(order_id_train_m2, order_details2)
    
    ggplot(d_train_m2_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Minus-2 Orders: ", plot_subtitle_percent_zero_reorder))
    
    
# train minus 2
d_train_m3_grp <- calc_percent_prods_reordered(order_id_train_m3, order_details2)
    

    ggplot(d_train_m3_grp, aes(x=order_hour_of_day, y=order_dow, fill=percent_reordered)) +
        geom_tile(color='White', size=0.1) +
        scale_fill_viridis(name=plot_perc_prods_reorder_fill) +
        labs(x=plot_perc_prods_reorder_x, y=plot_perc_prods_reorder_y) +
        coord_equal() + ggtitle(paste0("Train Minus-3 Orders: ", plot_subtitle_percent_zero_reorder))
    
    
    

