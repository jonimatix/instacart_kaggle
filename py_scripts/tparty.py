
import math
import pandas as pd
import numpy as np
import tpot
from tpot import TPOTClassifier
from sklearn.model_selection import train_test_split
import sklearn
import scipy
import random
import os


# this will be our log file for capturing tpot results
res_file = "tparty_results.txt"
print(tpot.__version__)



# LOAD IN DATA ---------------------------------------------

train = pd.read_csv("input/fabienvs_train.csv")
test = pd.read_csv("input/fabienvs_test.csv")
print(train.shape, test.shape)




# ISOLATE LABELS AND COLUMN MATCH ---------------------------
# train labels and remove label from dataset
y = train['reordered'].values
del train['reordered']

# set these aside from test for now so that train and test are same shape
test_prod_id = test['product_id'].values
test_order_id = test['order_id'].values
del test['product_id']
del test['order_id']
print(train.shape, test.shape)


# DETERMINE WHAT NUMBER ITERATION WE'RE ON FOR EXPERIMENT ---------
# check if our results file exists
if os.path.isfile(res_file):
    # if it exists, read it in and grab the max id counter, add 1, set that to iterator value
    temp_res = pd.read_csv(res_file)
    row_ids = temp_res['id'].values
    row_ids.astype(int)
    ite = max(row_ids) + 1
else:
    # otherwise, just set iterator to 1
    ite = 1

print("iterator is currently: ", ite)





# WHILE TRUE STARTS HERE ----------------------------------------------------








# PICK CLASSIFICATION SCORING METHOD ------------------------------------------
scoring_methods = ['log_loss', 'balanced_accuracy', 'roc_auc']
this_scoring_method = random.choice(scoring_methods)
print("current scoring method: ", this_scoring_method)





# TAKE SAMPLE DATA AND CAPTURE SIZE ------------------------------------------
x_train, x_test, y_train, y_test = train_test_split(train, y, train_size=0.0001)

# capture the number of rows and features in the train dataset to be added in our results
xt_nrows = int(x_train.shape[0])
xt_numb_feats = int(x_train.shape[1])





# BUILD AND RUN THE TPOT -------------------------------------------------------
tpot = TPOTClassifier(generations=10, population_size=10, n_jobs=4, verbosity=2,
                      scoring=this_scoring_method, cv=5, random_state=1776, warm_start=True)

tpot.fit(x_train, y_train)





# DETERMINE BEST CV SCORE PIPELINE ----------------------------------------------
best_pipes = tpot.pareto_front_fitted_pipelines_
len_best_pipes = len(best_pipes)
best_pipe_key = list(best_pipes.keys())[(len_best_pipes - 1)]  # key is entire pipeline as string

best_cv = abs(tpot.evaluated_individuals_[best_pipe_key][1])




# HOLDOUT SCORE --------------------------------------------------------------
holdout_score = tpot.score(x_test, y_test)
print(holdout_score)



print(ite)                   # row_id
print(best_pipe_key)         # best_pipe
print(best_cv)               # best_cv
print(holdout_score)         # holdout_score
print(this_scoring_method)   # scoring_method
print(xt_nrows)              # xt_rows
print(xt_numb_feats)         # xt_numb_feats


# check if this file exists, if not, then append the header line to the file, followed by first iteration results




print(header_line)
print(content_line)

best_pipe_key_no_comma = best_pipe_key.replace(",", "-")
content_line = str.format("{0}, {1}, {2}, {3}, {4}, {5}, {6}\n",
                          ite, best_pipe_key_no_comma, best_cv, holdout_score,
                          this_scoring_method, xt_nrows,xt_numb_feats)

if os.path.isfile(res_file):
    temp_openres = open(res_file, "a+")
    temp_openres.write(content_line)
else:
    temp_openres = open(res_file, "a+")
    header_line = "ite, best_pipe_key, best_cv, holdout_score, this_scoring_method, xt_nrows, xt_numb_feats\n"
    temp_openres.write(header_line)
    temp_openres.write(content_line)

temp_openres.close()


