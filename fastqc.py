# ---
# jupyter:
#   jupytext:
#     cell_markers: '{{{,}}}'
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.17.0
#   kernelspec:
#     display_name: Python 3.10.8
#     language: python
#     name: py3.10.8
# ---

import jawm

# {{{
fastqc=jawm.Process( 
    name="fastqc",
    script="""#!/bin/bash
fastqc {{extra_args}} -t {{ncores}} -o {{output}} {{f}}
""",

    # example arguments :
    
    # var={
    #     "extra_args": "",
    #     "ncores":"<n.cores>", 
    #     "output":"<output_folder>",
    #     "f": "<input_file>",
    # },
    
    # manager="slurm",
    # manager_slurm={
    #     "-p":"cluster,dedicated", 
    #     "--mem":"20GB", 
    #     "-t":"1:00:00", 
    #     "-c":"8" 
    # },
    
    # container="docker://mpgagebioinformatics/fastqc:0.11.9",
    # environmnent="apptainer",
    # environment_apptainer={ '-B': [input_file, output_folder] }
    
    # container="mpgagebioinformatics/fastqc:0.11.9",
    # environmnent="docker",
    # environment_docker={ '-v': [input_file, output_folder] },


    # param_file="yaml/apptainer.params.yaml" ,
    # param_file=[ "yaml/apptainer.params.yaml" , "yaml/slurm.params.yaml" ],
  
)
# }}}


if __name__ == "__main__": 
    import sys
    import os
    from pathlib import Path
    
    if len(sys.argv) > 1 and sys.argv[1] == "test" :

        # usage: python3 fastqc.py test
        
        print("Running in test mode...")

        if ( not jawm.utils.docker_available() ) and ( not jawm.utils.apptainer_available() ) :

            print("Neither Docker nor Apptainer could be found, stopping test...")
            sys.exit(1)

        # define script input and output
        input_file=Path("demo/demo.fastq.gz").resolve()
        output_folder=Path("demo-output").resolve()

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
            fastqc.param_file="yaml/apptainer.params.yaml" 
            fastqc.environment_apptainer={ '-B': [input_file, output_folder] }
            
        if jawm.utils.docker_available(v=True) :
            fastqc.param_file="yaml/docker.params.yaml" 
            fastqc.environment_apptainer={ '-v': [input_file, output_folder] }

        # execute process
        fastqc.execute()

        # wait for all processes to complete
        jawm.Process.wait()

        # print the output
        print(fastqc.get_output())

        jawm.utils.write_hash_file(output_folder, "demo/build.hash")


