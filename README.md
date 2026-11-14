# Vector Forge: Flutter Recreation

## Overview

It plots two vectors on a coordinate plane in 2D or 3D, performs the four core vector operations, and shows the key measurements. It uses no external packages: all drawing is done with Flutter's `CustomPainter`.

## Vector operations

The four operations are selected from tabs at the top of the screen.

- Add (A + B): draws the resultant vector and a parallelogram guide.
- Subtract (A − B): draws the difference vector and the connecting guide between the two tips.
- Dot (A · B): shows the dot product, with the projection of B onto A.
- Cross (A × B): shows the cross product vector in 3D. In 2D it shows a ⊙ or ⊗ symbol for the direction of the result along the Z axis.

## 2D and 3D modes

- A 2D/3D switch in the header changes the view at any time.
- 2D: a coordinate plane with a grid, axis labels, and number ticks that adapt as you zoom.
- 3D: a perspective view with a floor grid and X, Y and Z axes.
- In 2D the Z field is disabled and Z is treated as 0.

## Inputs and interaction

- Each vector has X, Y and Z number fields, and an On/Off switch to show or hide it.
- Drag the tips (2D): the X and Y fields update live as you move a vector.
- Pinch to zoom and two-finger pan: work in both modes.
- 3D orbit: drag to rotate the view.
- Recenter button: resets zoom, pan and rotation.

## Visual aids

- Components: a toggle that shows dashed lines from each vector tip to the axes, with the component values.
- Arc: a toggle that shows the angle between A and B as a shaded arc.

## Readouts

- The result of the selected operation is shown at the top of the graph.
- A row of values shows |A|, |B|, the result magnitude (or B along A for dot product), and the angle between the vectors.
- A Direction angles card shows α, β and γ for each vector.

## Responsive layout

- Phones: the graph sits on top and the controls scroll below it.
- Tablets and landscape: the graph is on the left with a side control panel on the right.
- The layout adjusts when the keyboard opens, so the fields stay usable.

## Design

A dark petrol-blue theme with brass for vector A, rose for vector B and ice-white for results. The X, Y and Z axes use muted terracotta, sage and slate blue.
