import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import plotly.graph_objects as go
import sys

filepath = "R/results/summary.csv"
df = pd.read_csv(filepath)

true = df[df['cat']==-1]
x =true[true['true']!=0]['day'],
x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
x_rev = x[::-1]

# Line 1
y1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
y1_upper = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
y1_lower = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

fig = go.Figure()

fig.add_trace(go.Scatter(
    x=true[true['true']==0]['day'],
    y=true['low'],
    line_color='rgba(255,139,15,0.8)',
    name='5th Percentile',
    showlegend=False,
    line=dict(dash='dash')
))

fig.add_trace(go.Scatter(
    y=true['high'],
    x=true[true['true']==0]['day'],
    showlegend = False,
    fill='tonexty',
    fillcolor='rgba(255,139,150,0.2)',
    line_color='rgba(255, 139, 15,.8)',
    name='95th Percentile',
    line=dict(dash='dash')
))

fig.add_trace(go.Scatter(
    x=x, y=true[true['true']!=0]['true'],
    line_color='rgb(0,0,0)',
    name='Historic',
))
fig.add_trace(go.Scatter(
    x=true[true['true']==0]['day'], 
    y=true['mle'],
    line_color='rgb(255,139,15)',
    name='Prediction',
))

fig.update_traces(mode='lines')
fig.show()
