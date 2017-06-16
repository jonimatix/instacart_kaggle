


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



#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Kaggle Instacart competition
#
# Starter script to set submission equal to prior order
#
# https://www.kaggle.com/c/instacart-market-basket-analysis
#
# Nigel Carpenter May 2017
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# 01 Load libraries ----

library(data.table)

# 02 Load data ----

#dt_aisles <- fread('../input/aisles.csv')
#dt_departments <- fread('../input/departments.csv')
#dt_products <- fread('../input/products.csv')
dt_orders <- fread('input/orders.csv')
dt_prior <- fread('input/order_products__prior.csv')
#dt_train <- fread('../input/order_products__train.csv')
dt_submission <- fread('input/sample_submission.csv')


# 03 identify prior order ID----

# how many user_id only have 1 order?
table(dt_orders[,.(max=max(order_number)), by=user_id]$max)
hist(dt_orders[,.(max=max(order_number)), by=user_id]$max)

#good minimum number of orders is 4 so everyone has a prior order to copy

# setkey to ensure correct roworder
setkey(dt_orders, user_id, order_number)

# add new field containing previous order_id using the shift function
dt_orders[,order_id_lag1:=shift(order_id, 1)]

# add previous order_id to submissions file
setkey(dt_orders,order_id)
setkey(dt_submission,order_id)

#dt_submission <- merge(dt_submission, dt_orders, all.x = TRUE)
dt_submission <- dt_orders[dt_submission]


# 04 extract products from previous order----
setkey(dt_prior,order_id)
setkey(dt_submission,order_id_lag1)

dt_prior <- dt_prior[dt_submission]

# now only keep products that have been re-ordered
dt_prior <- dt_prior[dt_prior$reordered == 1, ]

# concatenate product list by previous i.order_id
# this will be our "predictions" file
dt_preds <- dt_prior[,.(pred_products = paste(product_id, collapse = " ")),  by = i.order_id]
setnames(dt_preds, "i.order_id", "order_id")

# 05 now create our submission file ----
dt_sub <- data.table(order_id = dt_submission$order_id,
                     products = "None")

setkey(dt_preds,order_id)
setkey(dt_sub,order_id)

dt_sub <- merge(dt_sub, dt_preds, all.x = TRUE)
dt_sub[!is.na(dt_sub$pred_products)]$products <- dt_sub[!is.na(dt_sub$pred_products)]$pred_products
dt_sub$pred_products <- NULL

#write out submission
write.csv(dt_sub, "sub_previousrepeat.csv", row.names=FALSE)

