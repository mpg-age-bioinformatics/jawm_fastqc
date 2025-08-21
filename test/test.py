
# usage: python3 test.py

import sys
import os
from pathlib import Path

# add parent folder to sys.path to be able to import module
sys.path.append("..")
from fastqc import *

if ( not jawm.utils.docker_available() ) and ( not jawm.utils.apptainer_available() ) :

    print("Neither Docker nor Apptainer could be found, stopping test...")
    sys.exit(1)

# define script input and output
input_file=Path("test.fastq.gz").resolve()
output_folder=Path("test-output").resolve()

# make sure output folder exists
if not os.path.isdir(output_folder):
    os.makedirs(output_folder)

# add variables to script
fastqc.var={
    "output":output_folder,
    "f":input_file,
    "extra_args": "",
} 

# set environment docker/apptainer
if jawm.utils.apptainer_available(v=True) :
    # fastqc.param_file="../yaml/apptainer.params.yaml"
    fastqc.update_params("../yaml/apptainer.params.yaml")
    fastqc.environment_apptainer={ '-B': [input_file, output_folder] }
    
if jawm.utils.docker_available(v=True) :
    # fastqc.param_file="../yaml/docker.params.yaml"
    fastqc.update_params("../yaml/docker.params.yaml")
    fastqc.environment_apptainer={ '-v': [input_file, output_folder] }

print(fastqc.environment)
print(fastqc.params)

# execute process
fastqc.execute()

# wait for all processes to complete
jawm.Process.wait()

# print the output
print(fastqc.get_output())

jawm.utils.write_hash_file(output_folder, "test.hash")