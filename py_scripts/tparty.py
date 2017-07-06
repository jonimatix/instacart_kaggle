
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
import time

os.chdir()

# this will be our log file for capturing tpot results
res_file = "py_scripts/tparty_results.csv"  # the csv with aggregated results
res_py_file = "py_scripts/tparty_exported_pipelines/tparty_pipeline_id_"
res_pred_file = "py_scripts/tparty_exported_testpreds/tparty_preds_id_"


print(os.getcwd())

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
    row_ids = temp_res['row_number'].values
    row_ids.astype(int)
    ite = max(row_ids) + 1
else:
    # otherwise, just set iterator to 1
    ite = 1

print("iterator is currently: ", ite)





# WHILE TRUE STARTS HERE ----------------------------------------------------

while(True):

    this_respyfile = res_py_file + str(ite) + ".py"
    this_respredfile = res_pred_file + str(ite) + ".csv"

    print("entering loop now...")

    # PICK CLASSIFICATION SCORING METHOD ------------------------------------------
    scoring_methods = ['log_loss', 'balanced_accuracy', 'roc_auc']
    this_scoring_method = random.choice(scoring_methods)
    print("current scoring method: ", this_scoring_method)


    # TAKE SAMPLE DATA AND CAPTURE SIZE ------------------------------------------
    x_train, x_test, y_train, y_test = train_test_split(train, y, train_size=0.001)

    # capture the number of rows and features in the train dataset to be added in our results
    xt_nrows = int(x_train.shape[0])
    xt_numb_feats = int(x_train.shape[1])


    # BUILD AND RUN THE TPOT -------------------------------------------------------
    my_tpot = TPOTClassifier(generations=50, population_size=50, n_jobs=4, verbosity=2,
                             scoring=this_scoring_method, cv=5, random_state=1776, warm_start=True)

    my_tpot.fit(x_train, y_train)



    # DETERMINE BEST CV SCORE PIPELINE ----------------------------------------------
    best_pipes = my_tpot.pareto_front_fitted_pipelines_
    len_best_pipes = len(best_pipes)
    best_pipe_key = list(best_pipes.keys())[(len_best_pipes - 1)]  # key is entire pipeline as string

    best_cv = abs(my_tpot.evaluated_individuals_[best_pipe_key][1])


    # HOLDOUT SCORE --------------------------------------------------------------
    holdout_score = my_tpot.score(x_test, y_test)
    print(holdout_score)

    print(ite)                   # row_id
    print(best_pipe_key)         # best_pipe
    print(best_cv)               # best_cv
    print(holdout_score)         # holdout_score
    print(this_scoring_method)   # scoring_method
    print(xt_nrows)              # xt_rows
    print(xt_numb_feats)         # xt_numb_feats



    # replace commas in best pipeline with dashes (this is the only field with risk of commas
    best_pipe_key_no_comma = best_pipe_key.replace(",", "-")

    # generate content line regardless of if the file exists already or not
    content_line = str.format("{0}, {1}, {2}, {3}, {4}, {5}, {6}\n",
                              ite, best_pipe_key_no_comma, best_cv, holdout_score,
                              this_scoring_method, xt_nrows,xt_numb_feats)


    if os.path.isfile(res_file):
        # file exists, open it with append status and write our content line
        temp_openres = open(res_file, "a+")
        temp_openres.write(content_line)
    else:
        # file didn't exist, open it with append status and write header & content lines
        temp_openres = open(res_file, "a+")
        header_line = "row_number, best_pipe_key, best_cv, holdout_score, this_scoring_method, xt_nrows, xt_numb_feats\n"
        temp_openres.write(header_line)
        temp_openres.write(content_line)


    # close file to "write" results to disk
    temp_openres.close()


    # export python code pipeline
    my_tpot.export(this_respyfile)


    # write out the test predictions here (test refers to PBL test dataset) -- uncompiled down to products
    pbl_test_preds = my_tpot.predict_proba(x_test)
    pbl_test_preds2 = pd.DataFrame(pbl_test_preds)
    del pbl_test_preds2[0]  # only interested in the positive "1" prediction which is just 1 - "0" pred
    pbl_test_preds2.to_csv(path_or_buf=this_respredfile)


    # increment
    ite += 1
    print("ite iterator has now shifted to: ", ite)
    print("sleeping...")
    time.sleep(5)



