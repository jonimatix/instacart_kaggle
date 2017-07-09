


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


###########################################################################################################
#
# Kaggle Instacart competition
# Fabien Vavrand, June 2017
# Simple xgboost starter, score 0.3791 on LB
# Products selection is based on product by product binary classification, with a global threshold (0.21)
#
###########################################################################################################

library(data.table)
library(dplyr)
library(tidyr)


# Load Data ---------------------------------------------------------------
path <- "input"

aisles <- fread(file.path(path, "aisles.csv"))
departments <- fread(file.path(path, "departments.csv"))
orderp <- fread(file.path(path, "order_products__prior.csv"))  # orderp is order_prior (priors for train and test)
ordert <- fread(file.path(path, "order_products__train.csv"))  # ordert is order_train (last orders of train users)
orders <- fread(file.path(path, "orders.csv"))
products <- fread(file.path(path, "products.csv"))




# Reshape data ------------------------------------------------------------
aisles$aisle <- as.factor(aisles$aisle)
departments$department <- as.factor(departments$department)
orders$eval_set <- as.factor(orders$eval_set)
products$product_name <- as.factor(products$product_name)



#tv map in aisle and department, then remove those datasets
products <- products %>% 
    inner_join(aisles) %>% 
    inner_join(departments) %>% 
    select(-aisle_id, -department_id)
rm(aisles, departments)




#tv map in the user_id to order_train
ordert$user_id <- orders$user_id[match(ordert$order_id, orders$order_id)]  # match only returns FIRST match




# join orders (header level) with order prior (item level)
orders_products <- orders %>% inner_join(orderp, by = "order_id")



# no longer need order prior -- this data is now captured in orders_products
rm(orderp)
gc()


# Products ----------------------------------------------------------------
prd <- orders_products %>%                              # start with detailed order prior data
    arrange(user_id, order_number, product_id) %>%      # sort by user, order number, product id
    group_by(user_id, product_id) %>%                   # group by user id and product id
    mutate(product_time = row_number()) %>%             # generate a sequential number called product_time
    #' This will now be an incrementer per product per user starting at 1
    ungroup() %>%                                       
    group_by(product_id) %>%                            # group by product id: all summaries below here are BY PRODUCT
    summarise(
        prod_orders = n(),                                  # count number of orders the product shows up in
        prod_reorders = sum(reordered),                     # count all of the times the product was reordered
        prod_first_orders = sum(product_time == 1),         # count all first-time (by user) orders of this product
        prod_second_orders = sum(product_time == 2)         # count all second-time (by user) orders of this product
    )

# most of these are self explanatory
prd$prod_reorder_probability <- prd$prod_second_orders / prd$prod_first_orders  # number of second-time purchases over first-time purchases
prd$prod_reorder_times <- 1 + prd$prod_reorders / prd$prod_first_orders          
prd$prod_reorder_ratio <- prd$prod_reorders / prd$prod_orders

# 
prd <- prd %>% select(-prod_reorders, -prod_first_orders, -prod_second_orders)

rm(products)
gc()

# Users -------------------------------------------------------------------
users <- orders %>%                      # using the 'orders' (header level) data...
    filter(eval_set == "prior") %>%      # filter down to "prior" data
    group_by(user_id) %>%                # group by userid
    summarise( 
        user_orders = max(order_number),         # identify maximum order_number per userid
        user_period = sum(days_since_prior_order, na.rm = T),   # sum of all days_since_prior_order will give us user time period
        user_mean_days_since_prior = mean(days_since_prior_order, na.rm = T)  # average days between purchases
    )



us <- orders_products %>%            # starting with orders_products (item detail) data...
    group_by(user_id) %>%            # group by userid
    summarise( 
        user_total_products = n(),        # total number of products per user
        user_reorder_ratio = sum(reordered == 1) / sum(order_number > 1),   # number of reordered over total number of orders (not including first order)
        user_distinct_products = n_distinct(product_id)  # total number of distinct products
    )



# join in the header-level and item-level user data together
users <- users %>% inner_join(us)
users$user_average_basket <- users$user_total_products / users$user_orders



us <- orders %>%
    filter(eval_set != "prior") %>%
    select(user_id, order_id, eval_set,
           time_since_last_order = days_since_prior_order)



users <- users %>% inner_join(us)


rm(us)
gc()


# Database ----------------------------------------------------------------
data <- orders_products %>%
    group_by(user_id, product_id) %>% 
    summarise(
        up_orders = n(),
        up_first_order = min(order_number),
        up_last_order = max(order_number),
        up_average_cart_position = mean(add_to_cart_order))

rm(orders_products, orders)

data <- data %>% 
    inner_join(prd, by = "product_id") %>%
    inner_join(users, by = "user_id")

data$up_order_rate <- data$up_orders / data$user_orders
data$up_orders_since_last_order <- data$user_orders - data$up_last_order
data$up_order_rate_since_first_order <- data$up_orders / (data$user_orders - data$up_first_order + 1)

data <- data %>% 
    left_join(ordert %>% select(user_id, product_id, reordered), 
              by = c("user_id", "product_id"))

rm(ordert, prd, users)
gc()


# Train / Test datasets ---------------------------------------------------
train <- as.data.frame(data[data$eval_set == "train",])
train$eval_set <- NULL
train$user_id <- NULL
train$product_id <- NULL
train$order_id <- NULL
train$reordered[is.na(train$reordered)] <- 0

test <- as.data.frame(data[data$eval_set == "test",])
test$eval_set <- NULL
test$user_id <- NULL
test$reordered <- NULL

rm(data)
gc()


# Model -------------------------------------------------------------------
library(xgboost)

params <- list(
    "objective"           = "reg:logistic",
    "eval_metric"         = "logloss",
    "eta"                 = 0.1,
    "max_depth"           = 6,
    "min_child_weight"    = 10,
    "gamma"               = 0.70,
    "subsample"           = 0.76,
    "colsample_bytree"    = 0.95,
    "alpha"               = 2e-05,
    "lambda"              = 10
)

subtrain <- train %>% sample_frac(0.1)
X <- xgb.DMatrix(as.matrix(subtrain %>% select(-reordered)), label = subtrain$reordered)
model <- xgboost(data = X, params = params, nrounds = 80)

importance <- xgb.importance(colnames(X), model = model)
xgb.ggplot.importance(importance)

rm(X, importance, subtrain)
gc()


# Apply model -------------------------------------------------------------

# write.csv(train, "put_this_in_tpot.csv", row.names = F)
# write.csv(test, "put_this_in_tpot_test.csv", row.names = F)

X <- xgb.DMatrix(as.matrix(test %>% select(-order_id, -product_id)))
test$reordered <- predict(model, X)

test$reordered <- (test$reordered > 0.21) * 1

submission <- test %>%
    filter(reordered == 1) %>%
    group_by(order_id) %>%
    summarise(
        products = paste(product_id, collapse = " ")
    )

missing <- data.frame(
    order_id = unique(test$order_id[!test$order_id %in% submission$order_id]),
    products = "None"
)

submission <- submission %>% bind_rows(missing) %>% arrange(order_id)
write.csv(submission, file = "submit_this001.csv", row.names = F)