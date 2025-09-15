
# usage: python3 test.py

#########################################################

# General tests framework

#########################################################

import sys
import os
from pathlib import Path
import urllib.request
import socket
import re


# add parent folder to sys.path to be able to import module
sys.path.append("..")
from fastqc import *


if ( not jawm.utils.docker_available() ) and ( not jawm.utils.apptainer_available() ) :
    print("Neither Docker nor Apptainer could be found, stopping test...")
    sys.exit(1)


# check if there is a defined yaml
if "YAML" in os.environ:
    fastqc.update_params(os.environ.get("YAML"))

else:

    # set environment docker/apptainer
    if jawm.utils.apptainer_available(v=True) :
        fastqc.update_params("../yaml/apptainer.params.yaml")
        
    if jawm.utils.docker_available(v=True) :
        fastqc.update_params("../yaml/docker.params.yaml")

    # if on the raven or hpc studio cluster load the respective yamls
    hostname = socket.gethostname()
    if "raven" in hostname.lower():
        fastqc.update_params("../yaml/slurm-raven.params.yaml")
        
    elif re.search(r"hpc..\.bioinformatics\.studio", hostname) or ( hostname == "hpc-bioinformatics-studio" ):
        fastqc.update_params("../yaml/slurm-studio.params.yaml")


# check if there is a common space for raw_data
if "RAW_DATA" in os.environ:
    raw_data=os.environ.get("RAW_DATA")
else:
    raw_data="./"


#########################################################

# Processes' specific testing

#########################################################

# online files should not be bigger than 90mb 
online_input_file="https://github.com/mpg-age-bioinformatics/jawm_fastqc/raw/refs/heads/main/test/test.fastq.gz"

# define script input and output
input_file=os.path.join(raw_data,"test.fastq.gz")
input_file=Path(input_file).resolve()
output_folder=Path("test-output").resolve()

# download input files if not available
if not os.path.isfile(input_file):
    urllib.request.urlretrieve(online_input_file, input_file)
    
# make sure output folder exists
if not os.path.isdir(output_folder):
    os.makedirs(output_folder)

# add variables to script
fastqc.var={
    "mk.output":output_folder,
    "map.f":input_file,
    "extra_args": "",
} 

# print out paramerers, useful for debugging
print("parameters:", fastqc.params)

# execute process
fastqc.execute()

# wait for all processes to complete
jawm.Process.wait()

# print the output
print(fastqc.get_output())

# write out and compare output hash
jawm.utils.write_hash_file(os.path.join(output_folder,"test_fastqc.html"), "test.hash")