import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import numbers
import csv
import sys

filepath = sys.argv[1]
filename = filepath[filepath.rfind('/')+1:]
print(filepath)
data = pd.read_csv(filepath)

print("Adding year column")
data['year'] = data.apply(lambda row: str(row.QREDATE)[-6:-2], axis=1)
print("Adding month column")
data['month'] = data.apply(lambda row: str(row.QREDATE)[-10:-8].lstrip('0'), axis=1)
print("Adding day column")
data['day'] = data.apply(lambda row: str(row.QREDATE)[-8:-6].lstrip('0'), axis=1)

print('Removing invalid users')
invalid_users = []
users = data.NEWID.unique()
for user in users:
    user_data = data.loc[data['NEWID'] == user]
    #Finding invalid users by determining if their QREDATE is invalid
    invalid = user_data.loc[user_data['QREDATE_'] == 'B']
    if len(invalid) > 0:
        invalid_users.append(user)
        data = data[data.NEWID != user]
    invalid2 = user_data.loc[user_data.year == 'n'] 
    if len(invalid2) > 0 and user not in invalid_users:
        invalid_users.append(user)
        data = data[data.NEWID != user]

print("Mapping UCC to Category")
uccdata = pd.read_csv("categorized_ucc_dictionary.csv")
data['category'] = data['UCC'].map(uccdata.set_index('UCC')['CATEGORY'])

print("Dropping unneeded columns")
data = data.drop(columns=["UCC","ALLOC","GIFT","PUB_FLAG","QREDATE","QREDATE_"],axis=1)

data.to_csv('clean_data/'+filename,index=False)
