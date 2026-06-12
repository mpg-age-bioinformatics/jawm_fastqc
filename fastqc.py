import jawm
import sys
import os
import logging
logger = logging.getLogger("jawm_fastqc")

# define our fastqc process
fastqc=jawm.Process(

  # Logical statement to be validated prior to execution
  when=lambda p: not os.path.isfile(
                        os.path.join(
                          p.var["fastqc_output"],
                          os.path.basename( str(p.var["f"]).lstrip().split(" ")[0].split( ".fastq.gz"  )[0].split( ".fq.gz"  )[0] )+"_fastqc.html"
                        )
                      ),

  # Process name
  name="fastqc",

  # Script to be run when process is executed
  script="""#!/bin/bash
fastqc {{extra_args}} -t {{cpus}} -o {{fastqc_output}} {{f}}
""",

  # Description of the variables
  desc={
    "extra_args":"Any fastqc argument with its respective value.",
    "cpus":"Number of cpus to be used.",
    "fastqc_output":"Output dir.",
    "f":"Input fastq file."
  },

  # Default variable values
  var={
    "extra_args":"",
    "cpus":1
  },

  # image and respective environment
  container="mpgagebioinformatics/fastqc:0.11.9", # defaults to docker://mpgagebioinformatics/fastqc:0.11.9
  environment="docker", # docker or apptainer

  # slurm default arguments
  manager_slurm={
    "--mem":"20GB",
    "-t":"1:00:00",
    "-c":"4"
  }

)

def unzip(zip_path):
  from pathlib import Path
  from zipfile import ZipFile

  zip_path = Path(zip_path)
  destination = zip_path.parent
  destination.mkdir(parents=True, exist_ok=True)

  with ZipFile(zip_path, "r") as zip_ref:
    for member in zip_ref.infolist():
      target_path = destination / member.filename
      if not target_path.resolve().is_relative_to(destination.resolve()):
        raise ValueError(f"Unsafe zip entry: {member.filename}")
    zip_ref.extractall(destination)

if __name__ == "__main__":

  from jawm.utils import workflow

  # parse the command line jawm call
  # if no workflow was called, workflows will default to 'main' 
  workflows, var, args, unknown_args = jawm.utils.parse_arguments(["main","fastqc","test"])

  # check which workflow was called from the command line
  if workflow( ["main","fastqc","test"], workflows ) :

    # handle single file calls
    if "f" in fastqc.var:
      # clone the fastqc process
      fastqc_=fastqc.clone()
      # execute the process
      fastqc_.execute()

    # handle folder calls
    if "fastq_folder" in fastqc.var :

      # list all the fastq files in the input folder
      fastq_files = [
          os.path.join( fastqc.var["fastq_folder"], f )
          for f in os.listdir( fastqc.var["fastq_folder"] )
          if f.endswith( (".fastq.gz", ".fq.gz") )
      ]

      for f in fastq_files :
        # for each fastq file clone the fastqc process
        fastqc_=fastqc.clone()
        # attribute the input file
        fastqc_.var["map.f"] = f
        # execute the process
        fastqc_.execute()

  # Wait for all processes to complete
  jawm.Process.wait()

  # when running the test workflow we do also unzip the output file
  if workflow( ["test"], workflows ) :

    # unzip the output file
    zip_path=os.path.join( fastqc.var["fastqc_output"], os.path.basename( str( fastqc.var["f"] ).lstrip().split(" ")[0].split( ".fastq.gz"  )[0].split( ".fq.gz"  )[0] )+"_fastqc.zip" )
    unzip(zip_path)

    logger.info("Test completed.")

sys.exit(0)