


# load libraries
library(rstudioapi)
library(ggplot2)
library(data.table)
library(dplyr)


# recursively find the directory I want to be set to wd (setwd())
recursive_dirname <- function(target_dir, fp) {
    # supply target_dir (the first occurring directory name that we want our working directory to be)
    # supply fp (this will be user supplied, in this context, I'll use the rstudioapi::getActiveDocumentContext()$path)
    
    # will return either A) the file path ending with the target_dir or
    # B) NA if no file path ending with the target_dir name was found and we hit the top of the drive path
    
    # here we are isolating the character string after the last slash
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



#########################################################################
# Instacart Market Basket Analysis
# 
# Link: https://www.kaggle.com/c/instacart-market-basket-analysis
#
# This baseline approach predicts the content of new baskets based on 
# frequently ordered products per user. The support threshold can be 
# varied by adjusting the variable sugg_threshold. 
#
# Author: Marcel Spitzer
#
#########################################################################

# setup libraries
library(readr)
library(dplyr)
library(tidyr)

# read tables 
prior <- read_csv("input/order_products__prior.csv")
train <- read_csv("input/order_products__train.csv")
orders <- read_csv("input/orders.csv")
products <- read_csv("input/products.csv")
submission <- read_csv("input/sample_submission.csv")

# get products per user 
ordered_items_per_user <- rbind(prior, train) %>% 
    inner_join(products, by="product_id") %>% 
    inner_join(orders, by = "order_id") %>% 
    group_by(user_id) %>%
    summarise(ordered_items = as.vector(list(product_id)), 
              n_orders = length(unique(order_id))) 

# compute product frequencies
ordered_items_per_user$n_items_per_order <- round(sapply(ordered_items_per_user$ordered_items, length) / ordered_items_per_user$n_orders)
ordered_items_per_user$abs_freq <- ordered_items_per_user$ordered_items %>% lapply(function(x) {sort(table(x), decreasing=T)})
ordered_items_per_user$rel_freq <- Map("/", ordered_items_per_user$abs_freq, ordered_items_per_user$n_orders)

# retain frequently ordered products 
sugg_threshold <- 0.25 # the product has to be contained in at least 10 percent of all the baskets 
submissions_with_frequencies <- submission %>% 
    inner_join(orders, by="order_id") %>%
    inner_join(ordered_items_per_user, by="user_id") %>% 
    select(order_id, products, n_items_per_order, rel_freq) 

submissions_with_frequencies$rel_freq <- submissions_with_frequencies$rel_freq %>% lapply(function(x){names(x[x>sugg_threshold])})
submissions_with_frequencies$rel_freq <- Map(function(x,y){y <- min(length(x),y); x[1:y]}, submissions_with_frequencies$rel_freq, submissions_with_frequencies$n_items_per_order)

# write submission file 
submission$products <- as.character(Map(paste, submissions_with_frequencies$rel_freq, collapse=" "))
submission$products[which(submission$products=="NA")] <- "None"
write.csv(submission, file = paste0("subm_strat1.csv"), quote = F, row.names = F)
