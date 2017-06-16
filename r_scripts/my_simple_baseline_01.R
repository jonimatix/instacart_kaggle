

# load libraries
library(rstudioapi)
library(ggplot2)
library(data.table)
library(dplyr)


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
#' My Baseline
#' Author: Taylor Van Anne
#' This is going to be a submission where we just literally submit the users
#' products that were re-ordered on their order immediately before their "test" order
#' #####################################################

library(dplyr)

# load data
orders <- readRDS('input/orders.rds')
denorm <- readRDS('input/denorm.rds')



# we really only need the users who are in the "test" group since we're only building a calcualted model

test_users <- unique(orders$user_id[orders$eval_set == 'test'])
test_denorm <- denorm[denorm$user_id %in% test_users,]
test_orders <- orders[orders$user_id %in% test_users,]


# filter it down to just re-ordered products then arrange test_denorm how we want it
test_denorm <- test_denorm[test_denorm$reordered == 1,]


# group by user, create ("mutate") a new field that will be equal to the previous order_id of that user (if available)
test_orders2 <- dplyr::group_by(test_orders, user_id) %>%
    dplyr::mutate(prev_order_id = lag(order_id, n=1, order_by=order_number)) %>%
    data.frame()


# all we really need are the rows where eval_set == 'test', because now we also have that attached to it's previous order_id
test_to_prev_order_mapping <- test_orders2[test_orders2$eval_set == 'test', c('order_id', 'prev_order_id')]



# clear up some space in memory if necessary:
rm(test_orders, test_orders2); gc()
    
    

    
# lets work out an example with this order ID combo:
test_to_prev_order_mapping[2,]
# 1402502 -- need to look up the reordered product id's from here
# 2774568  -- and apply them to this order
    

# limit this denormalized object down to just what we need (order_id's prior to the same user's "test" order_id)
test_denorm2 <- test_denorm[ test_denorm$order_id %in% test_to_prev_order_mapping$prev_order_id, ]



# this isn't a good "pure" function because we depend on "test_denorm2" which is in the global environment
# we'll test efficiency using this impure function as well as passing in the entire "test_denorm2" object
collapse_reordered_prods <- function(p_order_id) {
    
    # quick and dirty check
    if(length(p_order_id) != 1) {stop("length of p_order_id paramter should be 1")}
    
    # subset and return in one fell swoop
    return(paste0(test_denorm2$product_id[test_denorm2$order_id == p_order_id], collapse = ' '))
}


# function testing on solo orders:
collapse_reordered_prods(1402502)
collapse_reordered_prods(2557754)




# applying function to all 75,000 prior orders to "test" orders
prods_prior_to_test <- sapply(test_to_prev_order_mapping$prev_order_id, collapse_reordered_prods)




# replace the empty ("") product baskets with the word "None"
prods_prior_to_test[prods_prior_to_test == ""] <- "None"
sum(prods_prior_to_test == "None")
# Note: 5,237 / 75,000 (about 7 percent) of the orders immediately before "test" orders had zero reordered products




# attach to our mapping dataframe
submissions <- cbind(test_to_prev_order_mapping, prods_prior_to_test)
submissions$prev_order_id <- NULL
names(submissions) <- c("order_id", "products")

write.csv(submissions, 'submissions/001_immediately_previous_order_reordered_products.csv', row.names = F)



# lets try out an "All None" file for kicks to see what that gives us.
all_none_submission <- data.frame(order_id=submissions$order_id, products="None", stringsAsFactors = F)
head(all_none_submission)
sapply(all_none_submission, class)

write.csv(all_none_submission, 'submissions/002_all_None.csv', row.names = F)



