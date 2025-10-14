import jawm

# {{{
fastqc=jawm.Process( 
    name="fastqc",
    script="""#!/bin/bash
fastqc {{extra_args}} -t {{ncores}} -o {{mk.output}} {{map.f}}
""",

    # example arguments :
    
    # var={
    #     "extra_args": "",
    #     "ncores":"<n.cores>", 
    #     "mk.output":"<output_folder>",
    #     "map.f": "<input_file>",
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


if __name__ == "__main__":
    import sys
    from jawm.utils import workflow

    workflows, args, unknown_args = jawm.utils.parse_arguments(["main","fastqc","test"],)

    if workflow( ["main","fastqc","test"], workflows ) :

        # execute process
        fastqc.execute()

        # wait for all processes to complete
        jawm.Process.wait()

        # print the output
        print(fastqc.get_output())

    if workflow( "test", workflows ) :
        print("Test completed.")


    sys.exit(0)