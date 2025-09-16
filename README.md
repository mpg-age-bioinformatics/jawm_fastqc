# jawm_fastqc

Command line usage:
```
jawm fastqc.py -v yaml/demo.vars.yaml -p yaml/docker.params.yaml 
```

Example yaml files:
```
$ cat yaml/demo.vars.yaml
- scope: process
  name: "fastqc"
  var:
    extra_args: ""
    output: "test/test-output"
    f: "test/test.fastq.gz"

$ cat yaml/docker.params.yaml
- scope: process
  name: "fastqc"
  container: "mpgagebioinformatics/fastqc:0.11.9"
  environment: "docker"
  parallel: False  
  var:
    ncores: "2" 
```

Testing (requires docker):
```
# download test input data
jawm-dev download -f ./test/data.txt -o ./test/test-input

# run jawm 
jawm fastqc.py -p ./test/fastqc.yaml

# check the output
ls ./test/test-output
```
