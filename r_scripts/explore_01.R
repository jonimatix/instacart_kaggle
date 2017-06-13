

library(rstudioapi)


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



View(order_prior[1:100,])
names(order_prior)  # order_id   product_id   add_to_cart_order   reordered

View(order_train[1:100,])
names(order_train)

sum(unique(order_train$order_id)  %in%  unique(order_prior$order_id))
length(intersect(unique(order_train$order_id), unique(order_prior$order_id)))  # how may are shared? none.
length(intersect(unique(order_train$order_id), unique(orders$order_id))) == length(unique(order_train$order_id))
length(intersect(unique(order_prior$order_id), unique(orders$order_id))) == length(unique(order_prior$order_id))



View(orders[1:100,])



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



