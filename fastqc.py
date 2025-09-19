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
# }}}



if __name__ == "__main__":
    import sys
    import os
    import argparse


    ######################################################################
    # move this function to jawm utils
    def parse_arguments(available_workflows=["main"],description="A jawm module.",extra_args={}):
        """
        Parse command-line arguments to determine which workflows to run.

        This function uses argparse to read a positional argument `workflows`
        from the command line. The argument can be a single submodule name
        or a comma-separated list of workflows. It validates the input
        against a list of available workflows and exits if any invalid
        workflows are provided.

        Parameters
        ----------
        available_workflows : list of str, optional
            A list of valid submodule names that the user is allowed to run.
            Default is ["main"].

        description: str, 
            The module description.
            Default is "A jawm module.".

        extra_args: dictionary
            An { "arg":"Help text"} dictionary.
            Default is {}.

        Returns
        -------
        list of str
            A list of submodule names that were specified in the command line
            and validated against `available_workflows`.

        Raises
        ------
        SystemExit
            If any of the provided workflows are not found in `available_workflows`,
            the function prints an error message and exits the program.

        Examples
        --------
        Command line usage:
            $ python my_program.py main
            $ python my_program.py main,submodule2

        In code:
            workflows = parse_arguments(["main", "submodule2"])
        """

        parser = argparse.ArgumentParser(
            description=description
        )

        parser.add_argument(
            "workflows",
            nargs="+",
            help="The workflows to run. Eg. 'main' for running all modules or a comma separated list of workflows."
        )

        for arg in list(extra_args.keys()) :
             parser.add_argument(arg, help=extra_args[arg] )

        args, unknown_args=parser.parse_known_args()
                
        workflows=args.workflows

        script_name = os.path.basename(sys.argv[0])
        workflows=[ s for s in workflows if s != script_name ]
        if not workflows :
            workflows=["main"]
        else :
            workflows=workflows[0]

            if "," in workflows :
                workflows=workflows.split(",")
            else:
                workflows=[workflows]

        
        ######## DEV (while waiting for jawm to take arguments accordingly)
        
        # workflows=[ s.replace("fastqc.py","main") for s in workflows ]
        # workflows=[ s for s in workflows if s != "fastq.py" ]
        # print("Workflows:", workflows)

        ########
        
        not_found=[ s for s in workflows if s not in available_workflows ] 

        if not_found :
            print("The following workflows could not be found:", ",".join(not_found) )
            print("Available workflows:", ",".join(available_workflows) )
            sys.exit(1)

        return workflows, args, unknown_args

    ######################################################################

    # workflows = jawm.utils.parse_arguments(["main","fastqc"])

    workflows, args, unknown_args = parse_arguments(["main","fastqc"])

    if "main" in workflows or "fastqc" in workflows :

        # execute process
        fastqc.execute()

        # wait for all processes to complete
        jawm.Process.wait()

        # print the output
        print(fastqc.get_output())

sys.exit(0)