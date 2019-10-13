import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import scipy as sci
import pandas as pd
import plotly.graph_objects as go
import numpy as np

x = np.array([-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10])
x_small = -2
x_large = 2
fig = go.Figure()

fig.add_trace(go.Scatter(
x=x, 
y=-x**2,
line_color='rgb(0,0,255)',
fillcolor='rgba(0,0,255,.2)',
fill='tonextx'
))

fig.add_trace(go.Scatter(
x=[x_small,x_large], 
y=[max(-x**2)]*2,
line_color='rgb(0,0,0)'
))
fig.add_trace(go.Scatter(
x = [x_small,x_small],
y = [0,999999]
))
fig.update_traces(mode='lines')
fig.show()
