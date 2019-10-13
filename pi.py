import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import plotly.graph_objects as go

pd = pd.read_csv('clean_data/expd081.csv')
pd = pd[pd.NEWID == 889261]
cat = []
for i in range(10):
    cat.append(pd[pd.category==i].COST.values.sum())
cat = [118,249.81,80.26,54.18]
fig = go.Figure(data=[go.Pie(labels=[1,2,7,8], values=cat)])
fig.show()
