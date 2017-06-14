

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

#' ok so here is what we're trying to do now 


# load smaller data sets with read.csv
aisles <- read.csv('input/aisles.csv', stringsAsFactors = F)
dept <- read.csv('input/departments.csv', stringsAsFactors = F)
prods <- read.csv('input/products.csv', stringsAsFactors = F)
samp_sub <- read.csv('input/sample_submission.csv', stringsAsFactors = F)

# make rds of larger files, load them if they are available, otherwise create them
if ( !(file.exists('input/order_prior.rds'))  ||  !(file.exists('input/order_train.rds')) || !(file.exists('input/orders.rds')) ) {
    print("rds didn't exist, making them now")
    order_prior <- read.csv('input/order_products__prior.csv', stringsAsFactors = F)
    order_train <- read.csv('input/order_products__train.csv', stringsAsFactors = F)
    orders <- read.csv('input/orders.csv', stringsAsFactors = F)
    saveRDS(order_prior, 'input/order_prior.rds')
    saveRDS(order_train, 'input/order_train.rds')
    saveRDS(orders, 'input/orders.rds')
} else {
    print("rds DO exist, loading them now")
    order_prior <- readRDS('input/order_prior.rds')
    order_train <- readRDS('input/order_train.rds')
    orders <- readRDS('input/orders.rds')
}



# View(order_prior[1:100,])
names(order_prior)  # order_id   product_id   add_to_cart_order   reordered

# View(order_train[1:100,])
names(order_train)

sum(unique(order_train$order_id)  %in%  unique(order_prior$order_id))
length(intersect(unique(order_train$order_id), unique(order_prior$order_id)))  # how may are shared? none.
length(intersect(unique(order_train$order_id), unique(orders$order_id))) == length(unique(order_train$order_id))
length(intersect(unique(order_prior$order_id), unique(orders$order_id))) == length(unique(order_prior$order_id))



# View(orders[1:100,])



hist(table(orders$user_id), col='light blue', main='Number of Orders per User', xlab='Number of Orders')

# now what does that look like separated by train/test? are they pretty even?

train_users <- unique(orders$user_id)[orders$eval_set == 'train']
test_users <- unique(orders$user_id)[orders$eval_set == 'test']


num_ord_p_user <- data.frame(table(orders$user_id))
names(num_ord_p_user) <- c("user_id", "Freq")
num_ord_p_user$eval_set <- ifelse(num_ord_p_user$user_id %in% train_users, 'train', 'test')

library(ggplot2)

# answer: basically identical
ggplot(data=num_ord_p_user, aes(x=Freq, fill=eval_set)) +
    geom_density(alpha=0.3)

rm(num_ord_p_user)


names(order_train)
sapply(order_train, class)    
ggplot(data=order_train, aes(x=add_to_cart_order, fill=as.factor(reordered))) +
    geom_density(alpha=0.3)




# denormalization effort:

# most detailed fact tables are order_prior and order_train

library(data.table)
setDT(order_prior)
setDT(order_train)
setDT(orders)

names(order_prior)
names(orders)


denorm1 <- rbind(order_prior, order_train)


length(unique(denorm1$order_id))
length(unique(orders$order_id[orders$eval_set != 'test']))
length(unique(orders$order_id))

# so denorm2 contains both train and test, as well as the priors for both train and test
# test orders will only have one row, as we don't know what products were included in these orders
denorm2 <- merge(x=denorm1, y=orders, by='order_id', all.x=T, all.y=T)

# View(denorm2[denorm2$eval_set == 'test', ][1:100,])  # view first 100 rows belonging to test

denorm3 <- merge(x=denorm2, y=prods, by='product_id', all.x=T, all.y=F)
denorm4 <- merge(x=denorm3, y=dept, by='department_id', all.x=T, all.y=F)
denorm5 <- merge(x=denorm4, y=aisles, by='aisle_id', all.x=T, all.y=F)
denorm6 <- dplyr::arrange(denorm5, order_id, add_to_cart_order)


# denorm6 looks like what we want
denorm <- denorm6
rm(denorm1, denorm2, denorm3, denorm4, denorm5, denorm6)
gc()


saveRDS(denorm, 'input/denorm.rds')



# split test and train users for priors splitting:
test_user_ids <- unique(denorm$user_id[denorm$eval_set == 'test'])
test_order_ids <- unique(denorm$order_id[denorm$eval_set == 'test'])
test_prior_order_ids <- unique(denorm$order_id[denorm$eval_set == 'prior' & denorm$user_id %in% test_user_ids])
train_user_ids <- unique(denorm$user_id[denorm$eval_set == 'train'])
train_order_ids <- unique(denorm$order_id[denorm$eval_set == 'train'])
train_prior_order_ids <- unique(denorm$order_id[denorm$eval_set == 'prior' & denorm$user_id %in% train_user_ids])

denorm_test_prior <- denorm[denorm$order_id %in% test_prior_order_ids,]


# these should all be zero
length(intersect(test_user_ids, train_user_ids))
length(intersect(train_prior_order_ids, test_prior_order_ids))


# test example
denorm[denorm$user_id == 36855 & denorm$product_id == 47766,]


# ideas from here...

# if we want to use Bayes:
# https://stats.stackexchange.com/questions/21822/understanding-naive-bayes/21849#21849
# https://stats.stackexchange.com/questions/142505/how-to-use-naive-bayes-for-multi-class-problems


# there are two pieces to this... first you have to predict which ones will not have a reordered item. so predict
# the exclusively "None" order ids. 
# Second: you have those that require a top n predictions for items that will be in the basket of their next purchase.
# Then those who are on the fringe (since this is a probabilistic binary classification
# problem) can have both a top n prediction of items as well as a 'None' to bridge the gaps


# keep in mind that we are missing order size of test... maybe in a prelim step we can time series or ML our way into
# predicting a size of order / cart per user

# we also are given no ordering of the order_ids


# 0)
# lets separate train, test, train_priors, and test_priors within the denorm object


# 1)
# if we remove user id, a ML algorithm shouldn't be able to classify the priors into whether they fall
# into the "train" or "test" category at a balanced accuracy greater than 50% (might need to downsample 
# the 'train' records) -- lets test that, it could identify some data leaks


# 2)
# What is the breakdown of total orders with / without at least a single reordered product
# create a super simple calculated model (or simple ML model) that identifies the users / orders most likely to result
# in a 'None' (no products were re-orders). This should be a probabilistic output so we can start with a threshold of
# 0 (Zero 'None' values) to a threshold of 1 (All 'None' values), this will enable us to find the optimal threshold
# where the results start to taper off. The values where we don't include a 'None' value will be left blank... Keep in 
# mind, the results of this analysis will ALWAYS INCREASE. All we're looking for is where our accuracy begins to plateau. 
# That threshold will likely be the best spot for us to start including 'None' values. This will also be useful as a potential
# piece to an ensemble model
# I'm not sure how big of a piece of this puzzle this will be yet, but I'd like to start here
# features to consider would be, unusual purchase times relative to the users previous purchase times
# unusual pattern with the "days since last purchase" field
# clustering users and then coloring based on average repurchases per order -- is there a super low group?


# 3)
# Text analytics on products / department / aisle -- think w2v type stuff -- this should be a ensembling weighted type of thing

# 4) -- data cleansing
# days since prior order has NA values, if there is 1 NA value per individual then we might be able to assume that
# this is the first order for that user? I really don't want to interpolate a value if we shouldn't be doing that.
# I'll also need to see if it makes sense to just take that out altogether
# Can something have an NA for days_since_prior_order AND have at least a single reordered product?


# 5) chronological ordering of orders by user
# we can figure out chronology of orders within user_id by determining on which order a particular item goes from a 
# reorder value of 0 to a reorder value of 1, this isn't fool proof but it might be worth investigating. Then we could
# stagger the orders so we can see the order immediately prior and group them like that. that would help with potential
# binary classification of products -- https://www.kaggle.com/c/instacart-market-basket-analysis/discussion/33501

