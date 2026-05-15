![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Language: Lua](https://img.shields.io/badge/Language-Lua-blue.svg)
![Version: 2026](https://img.shields.io/badge/Version-2026-green.svg)

# NAME
**ezr.fun** — explainable multi-objective optimization via decision trees,
written in the **fun** language (a tiny Lua-targeted DSL).

# SYNOPSIS
**./fun ezr.fun** [*-b bins*] [*-B Budget*] [*-C Check*] [*-c cliffs*] [*-e eps*]
             [*-f file*] [*-k ksconf*] [*-l leaf*] [*-p p*] [*-s seed*]
             [*-S Show*] [*-h*] [*COMMAND*]

# DESCRIPTION
**ezr.fun** is a decision tree learner designed for multi-objective optimization.
It identifies regions of the search space that maximize objective scores by
recursively partitioning data. Unlike black-box optimizers, **ezr.fun** provides
human-readable rules (branches) explaining why certain decisions lead
to better outcomes.

The engine processes data where:
* Columns starting with uppercase letters are treated as **NUM**eric.
* Columns ending with **-** are goals to minimize.
* Columns ending with **+** or **!** are goals to maximize.
* Columns ending with **X** are ignored.

The optimization uses a distance-to-ideal metric ($disty$) to rank rows, then 
builds a tree to minimize the variance of these scores.

# OPTIONS
**-b bins**=4
    Number of candidate cut points per numeric column (stride length
    through sorted values).

**-B Budget**=50
    Initial building budget. Defines the number of rows sampled to construct 
    the initial model.

**-C Check**=5
    Final check budget. Number of top-ranked candidates to validate in the 
    final optimization stage.

**-c cliffs**=0.195
    Threshold for Cliff's Delta non-parametric effect size test.

**-e eps**=0.35
    Cohen's threshold. Used to determine if the difference between two 
    distributions is negligible.

**-f file**
    Path to the input CSV file (default in help).

**-k ksconf**=1.36
    Kolmogorov-Smirnov test confidence threshold.

**-l leaf**=3
    Minimum number of rows required to create a leaf node in the tree.

**-p p**=2
    The coefficient for Minkowski distance (2 = Euclidean).

**-s seed**=1
    Seed for the pseudo-random number generator to ensure reproducibility.

**-S Show**=30
    The display width for the left-hand side (LHS) of the tree visualization.

**-h**
    Show the help message and exit.

# COMMANDS
All commands read the input file from `-f` (default in `-h` output).

**--the**
    Print the current `the` config table.

**--csv**
    Read input CSV and print every 30th row.

**--data**
    Print median for each goal column.

**--tree**
    Build and display a decision tree from a budget-sized sample.

**--ranks**
    Demonstrate statistical ranking via Weibull samples.

**--test**
    Cross-validation: predict "winning" rows via the tree.

**--testNum**, **--testSym**, **--testTree**, **--testStat**
    Assert-based unit tests.

**--all**
    Run every command above; print assert pass count.

**-h**
    Show help and exit.

# STATISTICS
The tool employs three distinct checks to determine if two groups of rows 
belong to the same "rank":
1.  **Cohen's Delta**: Checks if the difference in medians is greater than 
    a small fraction of the standard deviation ($spread \times eps$).
2.  **Cliff's Delta**: A non-parametric measure of how often values in one 
    distribution exceed values in another.
3.  **KS-Test**: Checks if the maximum distance between the cumulative 
    distribution functions of two samples exceeds a critical value.

# AUTHOR
Written by Tim Menzies <timm@ieee.org>.

# COPYRIGHT
(c) 2026 Tim Menzies. MIT License.
Vim: set et sw=2 tw=85 :
