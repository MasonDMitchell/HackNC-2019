import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import plotly.graph_objects as go
import math
import sys

filepath = sys.argv[1]
cat = filepath[filepath.rfind('cat')+3:filepath.rfind('cat')+4]
day = filepath[filepath.rfind('y')+1:filepath.rfind('.')]

data = pd.read_csv(filepath)
total = pd.read_csv('R/results/summary.csv')
x = data['expenditure']
y = data['density']
x_small = total[total['day']==int(day)][total['cat']==int(cat)]['low']
x_large = total[total['day']==int(day)][total['cat']==int(cat)]['high']
x_middle = total[total['day']==int(day)][total['cat']==int(cat)]['mle']
fig = go.Figure()
print(x_small)
print(min(y))
print(max(y))
print(x_large)
fig.add_trace(go.Scatter(
x=x, 
y=y,
line_color='rgb(0,0,255)',
fillcolor='rgba(0,0,255,.2)',
fill='tonextx',
name = 'Distribution'
))

fig.add_trace(go.Scatter(
x = [float(x_middle),float(x_middle)],
y = [min(y)-1,max(y)+1],
line = dict(dash='dash'),
line_color='rgb(150,150,150)',
name = 'Prediction'
))

fig.add_trace(go.Scatter(
x = [float(x_small),float(x_small)],
y = [min(y)-1,max(y)+1],
line_color='rgb(120,120,120)',
name = "5th Percentile"
))
fig.add_trace(go.Scatter(
x = [float(x_large),float(x_large)],
y = [min(y)-1,max(y)+1],
line_color='rgb(120,120,120)'
name = "95th Percentile"
))
fig.update_yaxes(range=[min(y),max(y)])
fig.show()
