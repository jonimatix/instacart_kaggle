

# ALL this script is responsible for is to create a "denormalized" version of all of the data. I want a single
# object that holds ALL of the data in a single table.


# on a scale of "backwards compatible" to "burn it down and start fresh," I'm a "burn it down and start fresh" guy
# this is that fresh script growing out of the ashes of what I just burnt down


# SCRIPT SETUP ----------------------------------------------------------------------------------------

# load libraries
library(rstudioapi)
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









# LOAD DATA --------------------------------------------------------------------------------------

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


    
    
# DENORMALIZE THE DATA -----------------------------------------------------------------------------
    
    #' this will eliminate the need to load in:
    #' - order_products__prior
    #' - order_products__train
    #' - aisles
    #' - dept
    #' - prods
    #' 
    #' All that remains to be loaded in will be "orders"
    #' 
    #' For any Kaggle scripts, be sure to include this denorm step
    
    
    # make these nerds all data.tables for faster merges (hooray for generic function dispatch!)
    setDT(order_prior)
    setDT(order_train)
    setDT(orders)
    
    # combine order_prior and order_train
    denorm <- rbind(order_prior, order_train)
        
    
    # so denorm contains both train and test, as well as the priors for both train and test
    # test orders will only have one row, as we don't know what products were included in these orders
    denorm <- merge(x=denorm, y=orders, by='order_id', all.x=T, all.y=T)
    
    
    # merge in remaining tables
    denorm <- merge(x=denorm, y=prods, by='product_id', all.x=T, all.y=F)
    denorm <- merge(x=denorm, y=dept, by='department_id', all.x=T, all.y=F)
    denorm <- merge(x=denorm, y=aisles, by='aisle_id', all.x=T, all.y=F)
    denorm <- dplyr::arrange(denorm, order_id, add_to_cart_order)
        
    
    
    # denorm6 looks like what we want
    order_detail <- denorm
    rm(denorm)
    gc()
    
    
    
    
    
# WRITE THE FILE OUT -----------------------------------------------------------------
    
    
    if(file.exists('input/order_detail.rds')) {
        print("it already exists, we're good!")
    } else {
        print("let's save this object as RDS so we can load it in faster later")
        saveRDS(order_detail, 'input/order_detail.rds')    
    }
    






