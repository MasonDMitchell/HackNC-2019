print("hi")
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import sys


filepath = sys.argv[1]
filename = filepath[filepath.rfind('/')+1:]
data = pd.read_csv(filepath)
print(filepath)

users = data.NEWID.unique()
amt_purchased = []
amt_of_purchases = []
for user in users:
    user_data = data.loc[data['NEWID'] == user]
    amt_purchased.append(user_data['COST'].values.sum())
    amt_of_purchases.append(len(user_data))

df = pd.DataFrame()
df['USERS'] = users
df['Purchases'] = amt_of_purchases
df['Spent'] = amt_purchased
print(df.head())
df.to_csv('user_data.csv')
