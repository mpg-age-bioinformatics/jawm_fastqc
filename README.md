# jawm_fastqc

Command line usage:
```
jawm fastqc.py -v yaml/demo.vars.yaml -p yaml/docker.params.yaml 
```

Check out the example yaml files:
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
  environmnent: "docker"
  var:
    ncores: "2" 
```
