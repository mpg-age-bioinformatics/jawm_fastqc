import jawm
import os
from pathlib import Path


# {{{
fastqc=jawm.Process( 
    name="fastqc",
    when=lambda p: not os.path.isfile( os.path.join( p.var["fastqc_output"], os.path.basename( str(p.var["f"]).lstrip().split(" ")[0].split( ".fastq.gz"  )[0].split( ".fq.gz"  )[0] )+"_fastqc.html" )  ) ,
    script="""#!/bin/bash
fastqc {{extra_args}} -t {{cpus}} -o {{fastqc_output}} {{f}}
""",
    
    # example arguments :
    var={"extra_args": ""}, 
    # var={
    #     "extra_args": "",
    #     "cpus":"<n.cores>", 
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

def report_files(fastqc_output) :
    report_paths={}
    dic={ 
        fastqc_output : { 
            "fastqc":"*_fastqc.html",
            }
        }

    for path in dic :
        directory = Path( path )
        for folder in dic[path] :
            files=[ f.resolve() for f in directory.glob( dic[path][folder] ) ]
            if files :
                report_paths[folder]=files

    return report_paths




def unzip_file(zip_path, destination=None):
    from pathlib import Path
    from zipfile import ZipFile
    """Extract a zip file into destination and return the destination path."""
    zip_path = Path(zip_path)
    destination = zip_path.parent if destination is None else Path(destination)
    destination.mkdir(parents=True, exist_ok=True)

    with ZipFile(zip_path, "r") as zip_ref:
        for member in zip_ref.infolist():
            target_path = destination / member.filename
            if not target_path.resolve().is_relative_to(destination.resolve()):
                raise ValueError(f"Unsafe zip entry: {member.filename}")
        zip_ref.extractall(destination)

    return destination

if __name__ == "__main__":
    import sys
    from jawm.utils import workflow

    workflows, var, args, unknown_args = jawm.utils.parse_arguments(["main","fastqc","test"],)

    if workflow( ["main","fastqc","test"], workflows ) :

        if "f" in fastqc.var.keys() :
            if fastqc.var["f"] != "" : 

                print( "Found:", fastqc.var["f"] )

                # execute process
                fastqc.execute()

                # wait for all processes to complete
                jawm.Process.wait()


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

        zip_path=os.path.join( fastqc.var["fastqc_output"], os.path.basename( str(fastqc.var["f"]).lstrip().split(" ")[0].split( ".fastq.gz"  )[0]+"_fastqc.zip" ) )

        unzip_file(zip_path)

        print("Test completed.")


    sys.exit(0)
