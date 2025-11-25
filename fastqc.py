import jawm
import os

# {{{
fastqc=jawm.Process( 
    name="fastqc",
    when=lambda p: not os.path.isfile( os.path.join( p.var["fastqc_output"], os.path.basename( str(p.var["f"]).lstrip().split(" ")[0].split( ".fastq.gz"  )[0].split( ".fq.gz"  )[0] )+"_fastqc.html" )  ) ,
    script="""#!/bin/bash
fastqc {{extra_args}} -t {{ncores}} -o {{fastqc_output}} {{f}}
""",
    
    # example arguments :
    var={"extra_args": ""}, 
    # var={
    #     "extra_args": "",
    #     "ncores":"<n.cores>", 
    #     "mk.output":"<output_folder>",
    #     "map.f": "<input_file>",
    # },
    
    # manager="slurm",
    manager_slurm={
        "--mem":"20GB", 
        "-t":"1:00:00", 
        "-c":"4" 
    },
    
    # container="docker://mpgagebioinformatics/fastqc:0.11.9",
    # environmnent="apptainer",
    # environment_apptainer={ '-B': [input_file, output_folder] }
    
    container="mpgagebioinformatics/fastqc:0.11.9",
    # environmnent="docker",
    # environment_docker={ '-v': [input_file, output_folder] },


    # param_file="yaml/apptainer.params.yaml" ,
    # param_file=[ "yaml/apptainer.params.yaml" , "yaml/slurm.params.yaml" ],
  
)


if __name__ == "__main__":
    import sys
    from jawm.utils import workflow
    from pathlib import Path

    workflows, vars, args, unknown_args = jawm.utils.parse_arguments(["main","fastqc","test"],)

    if workflow( ["main","fastqc","test"], workflows ) :

        if "f" in fastqc.var.keys() :
            if fastqc.var["f"] != "" : 

                print( "Found:", fastqc.var["f"] )

                # execute process
                fastqc.execute()

                # wait for all processes to complete
                jawm.Process.wait()

                # print the output
                print(fastqc.get_output())


        if "fastq_folder" in fastqc.var.keys() :
            if fastqc.var["fastq_folder"] != "" :

                read_files = list(Path( fastqc.var["fastq_folder"] ).glob(f'*{fastqc.var["read1_sufix"]}'))

                fastqc_jobs=[]

                for f in read_files :

                    fastqc_=fastqc.clone()
                    fastqc_.var["map.f"]=f
                    fastqc_.execute()
                    fastqc_jobs.append(fastqc_.hash)

                jawm.Process.wait( fastqc_jobs )



    if workflow( "test", workflows ) :
        print("Test completed.")


    sys.exit(0)
