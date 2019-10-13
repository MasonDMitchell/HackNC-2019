import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import plotly.graph_objects as go
import sys

df = pd.read_csv('R/results/category_summary.csv')
df = df[df['cat']!=-1]
x = df['cat']

animals=['giraffes', 'orangutans', 'monkeys']

fig = go.Figure(data=[
    go.Bar(name='actual', x=x, y=df[df['cat']==x]['true']),
    go.Bar(name='predicted', x=x, y=df[df['cat']==x]['pred'])
])

# Change the bar mode
fig.update_layout(barmode='group')
fig.show()
