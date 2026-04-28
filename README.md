# Lattice Boltzmann Method

Report at [main.pdf](main.pdf)

![animation](animations/wing_angles.mp4)


## Pulling this repo
I'm using `git-lfs` to store the binary files on GitLab.

This means that for a `git pull` to download all the files, you must have `git-lfs` installed.

Instructions for that are here: https://git-lfs.com/


Otherwise, you can download any file directly from GitLab. If you click on a file, the top-right corner should give you an option to download the file.

## Installation
To install `Julia`, run
``` bash
curl -fsSL https://install.julialang.org | sh
```
source: https://julialang.org/install/

## Usage
Run

``` bash
julia  -O3 -i --threads=auto --project=.  main.jl
```

then all the function from the `workflows.jl` file will become available in the default namespace.

I made all the figures from running these workflows.



## Declaration of Originality

My writing would not show up on the declaration when I tried appending it to the `main.pdf` in latex, so I have included it in the repo as a standalone file.
[delaration](declaration-originality.pdf)
