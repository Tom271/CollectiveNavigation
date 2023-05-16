#!/bin/sh
# Grid Engine options (lines prefixed with #$)
#$ -N LowKappaLaminarFlowHeatmaps
#$ -cwd
#$ -l h_rt=12:00:00
#$ -l h_vmem=8G
#$ -M s1415551@ed.ac.uk
#$ -m be
#  These options are:
#  job name: -N
#  use the current working directory: -cwd
#  runtime limit of 60 minutes: -l h_rt
#  memory limit of 6 Gbyte: -l h_vmem
#  Send email to <user>: -M <user>
#  choose reason for email (e=job end): -m e
# Initialise the environment modules
. /etc/profile.d/modules.sh

# Load Matlab
module load roslin/julia/1.9.0

# Run the program
julia ../../notebooks/final_figures/LaminarFlowHeatmapsLowKappaTest.jl
