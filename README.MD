# Continuum Builder 1.0.12
Builds and pushes Docker projects to AWS ECR. 

## Build

* Build
```shell script
docker build -t continuum-builder .
```

* Run Prerequisites Below then..

* Run
```shell script

# run builder 
docker run -it --rm -v /deploy-keys-folder:/media/continuum/deploy-keys  --network dind-net \
       -e AWS_ACCESS_KEY_ID='' \
       -e AWS_SECRET_ACCESS_KEY='' continuum-builder --gitRepo mygit-repo --gitBranch develop --awsRegion us-east-2 --ecrRepository some/ecr/repo  --folder folder-in-repo --sshKeysFolder /media/continuum/deploy-keys

# run builder persisting git repo to host
docker run -it --rm -v /deploy-keys-folder:/media/continuum/deploy-keys  -v /path/to-local-repo:/media/continuum/work --network dind-net \
       -e AWS_ACCESS_KEY_ID='' \
       -e AWS_SECRET_ACCESS_KEY='' continuum-builder --gitRepo mygit-repo --gitBranch develop --awsRegion us-east-2 --ecrRepository some/ecr/repo  --folder folder-in-repo --sshKeysFolder /media/continuum/deploy-keys
```


## Prerequisites
Requires a docker daemon to be running in a sibling container.
```shell script
# launch docker daemon as standalone container ( network must already exist )
docker run --privileged --name dind-notls -d \
       --network dind-net --network-alias docker \
       -e DOCKER_TLS_CERTDIR='' \
       docker:dind
```
