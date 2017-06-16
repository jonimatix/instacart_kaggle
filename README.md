# instacart_kaggle
kaggle competition for instacart market basket analysis


# Initial Thoughts

## Understanding the datasets

- **orders.csv** contains every single order in the data space. One row per order.
	* 3,421,083 rows x 7 cols
	* order_id
	* user_id 
	* eval_set (determines whether the order is in the "prior", "test", or "train" set - will explain in more detail later)
	* order_number (this is the chronological sequence in which the user placed their orders starting at 1 for the first order)
	* order_dow (order **d**ay **o**f the **w**eek)
	* order_hour_of_day
	* days_since_prior_order (We think this is 'NA' if it is their first order - these might just need to be removed?)
- **order_train** contains the itemized detail of the orders in the `orders.csv` file where `eval_set` is equal to `train`
	* 1,384,617 rows x 4 cols
	* order_id (this will be repeated for every item in the order)
	* product_id (this should be unique within the order? - `order_id` and `product_id` concatenated should be unique?)
	* add_to_cart_order (the order in which the products were added to the cart
	* reordered (whether the customer has ordered this product in any of their orders prior to this order - this is what will be used to develop the target variable)
- **order_prior** contains the itemized detail of the orders in the `orders.csv` file where `eval_set` is equal to `prior` - **note that the users who are associated with these orders can either have an order in the `train` or the `test` set - in other words, these are priors for both `train` and `test`)
	* 32,434,489 rows x 4 cols (same columns as the order_train dataset
	* order_id
	* product_id
	* add_to_cart_order
	* reordered
- **products.csv** contains the linkage between a `product_id` and the other dimensional information of the product itself (name, department, aisle)
	* 49,688 rows by 4 variables (this becomes a proxy for the classes we're trying to predict -- so this is a 50,000 class multi classification problem essentially)
	* we can reduce the number of classes for each user like so:
		* What is the likelihood of a user re-ordering a product they have already ordered in the past? If that doesn't meet a certain probability threshold, then just predict 'None' OR we can go ahead and add 'None' in there if we aren't confident, because **'None' acts as a product itself in a way**
		* You can guess a list of products as well as 'None' to "hedge your bets" - I think it does matter what order it is in though
	* product_id
	* product_name
	* aisle_id
	* department_id
- **department.csv** very simple department dimensional table
	* 21 rows x 2 cols
	* department_id
	* department (department name)
- **aisles.csv** very simple aisle dimensinal table
	* 134 rows x 2 cols
	* aisle_id
	* aisle (aisle name)
	

Note that there are some opportunities for some text analytics within the product, aisle, and department names. The keyword **Organic** seems to have proven useful to some people's models on Kaggle.

# Submissions

## Baseline

I just wrote my own baseline script (check the submission_descriptions.csv file for scriptfile name). This baseline script appears to be identical to the one someone
else wrote, because now my score is shared with about 400 other people. I'm wondering exactly how difficult it will be to beat this simple (yet effective) script.


## All "None"

I think it'll be useful (especially in these early days of the competition when I don't have any plans for using a lot of submissions) to submit a file of
all "None" values to get a feel for about how many of these things have a "None" value. Eventually I might want to build a model to see if I can predict the probability
for which of the test order_id's should receive a "None" value. Then I can start the threshold off incredibly low, and raise it little by little, making submissions 
along the way. I should then be able to tell where the "drop off" in accuracy is. The accuracy will never actually decrease, but the rate at which it is increasing will slow down
significantly. In the baseline file submission, about 7% of orders were given the value of "None". 

	