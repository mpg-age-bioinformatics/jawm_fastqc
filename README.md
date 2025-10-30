# jawm_fastqc

Installing jawm:
```
pip install git+ssh://git@github.com/mpg-age-bioinformatics/jawm.git
```

For more information on jawm please visit jawm's repo on [GitHub.com](https://github.com/mpg-age-bioinformatics/jawm/tree/main).

Example usage:
```
# clone this module
git clone git@github.com:mpg-age-bioinformatics/jawm_fastqc.git

# download test data
cd jawm_fastqc
jawm-test -r download

# docker
jawm fastqc.py fastqc -p ./yaml/docker.yaml

# slurm & apptainer with multiple yaml files
jawm fastqc.py fastqc -p ./yaml/vars.yaml ./yaml/hpc.yaml
```
