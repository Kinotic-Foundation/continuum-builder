#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

# Set magic variables for current file & dir
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
SCRIPT="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
# shellcheck disable=SC2034
__base="$(basename "${SCRIPT}" .sh)"
# shellcheck disable=SC2034
__root="$(cd "$(dirname "${SCRIPT_DIR}")" && pwd)"


function -h {
cat <<USAGE
USAGE: builder.sh (presented with defaults)
                  (--gitRepo "")? required
                  (--gitBranch "")?
                  (--awsRegion "")? required
                  (--ecrRepository "")? required
                  (--folder "")?
                  (--sshKeysFolder "")?

       The script performs the following operations.
          - Checks out source from git repo
          - Builds specified sub-folder with docker
          - Builds Docker Image if Dockerfile is present
          - Pushes Docker Image to ECR

USAGE
};
function --help { -h ;}

err() { echo "$*" >&2; exit 1; }

function options {
  while [[ ${1:+isset} ]]
  do
    case "$1" in
      --gitRepo)             		        gitRepo="$2"                 ; shift ;;
      --gitBranch)             		      gitBranch="$2"               ; shift ;;
      --awsRegion)             	        awsRegion="$2"               ; shift ;;
      --ecrRepository)             	    ecrRepository="$2"           ; shift ;;
      --folder)             		        folder="$2"                  ; shift ;;
      --sshKeysFolder)             		  sshKeysFolder="$2"           ; shift ;;
      --*)                              echo "No such option: $1" && exit 1; ;;
    esac
    shift
  done
}

function validate {
   if [ -z ${gitRepo+x} ]; then
      echo "You must provide the --gitRepo parameter."
      exit 1
   fi
   if [ -z ${gitBranch+x} ]; then
      gitBranch=""
   fi
   if [ -z ${awsRegion+x} ]; then
      echo "You must provide the --awsRegion parameter."
      exit 1
   fi
   if [ -z ${ecrRepository+x} ]; then
      echo "You must provide the --ecrRepository parameter."
      exit 1
   fi
   if [ -z ${folder+x} ]; then
      folder=""
   fi
   if [ -z ${sshKeysFolder+x} ]; then
      sshKeysFolder=""
   fi
}

function process {

  if [ -n "${sshKeysFolder}" ] && [ -d "${sshKeysFolder}" ]; then
    echo "SSH key folder found ${sshKeysFolder} will copy id_rsa and id_rsa.pub"
    cd "${sshKeysFolder}"

    if [ -f id_rsa ]; then
      echo "id_rsa found"
      cp id_rsa ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
    fi

    if [ -f id_rsa.pub ]; then
      echo "id_rsa.pub found"
      cp id_rsa.pub ~/.ssh/id_rsa.pub
      chmod 600 ~/.ssh/id_rsa.pub
    fi
    cd /media/continuum/work
  fi

  # TODO: remove once published to maven
  if [ -d vertx-stomp-lite ]; then
    echo "Updating vertx-stomp-lite from git"
    cd vertx-stomp-lite
    git pull
    cd ..
  else
    echo "Checking out vertx-stomp-lite from git"
    git clone https://github.com/kinotic-io/vertx-stomp-lite.git
  fi

  repo=$(basename "${gitRepo}" .git)

  if [ -d "${repo}" ]; then
    echo "Updating project from git"
    cd "${repo}"

    git reset --hard

    if [ -n "${gitBranch}" ]; then
      git checkout "${gitBranch}"
    fi

    git pull
    cd ..
  else
    echo "Checking out project"
    if [ -n "${gitBranch}" ]; then
      git clone --branch "${gitBranch}" "${gitRepo}"
    else
      git clone "${gitRepo}"
    fi
  fi

  cd "${repo}"

  if [ -n "${folder}" ]; then
    echo "Folder ${folder} will be used"
    cd "${folder}"
  fi

  if [ -f gradlew ]; then
    chmod +x gradlew
    ./gradlew build
  fi

  if [ -f Dockerfile ]; then

    echo "Getting AWS Account Id"
    awsAccountId=$(aws sts get-caller-identity --region "${awsRegion}" --output json |grep Account |awk -F ': "' '{print$2}' |sed 's/\".*//')

    echo "Building Dockerfile"
    docker build -t "${awsAccountId}".dkr.ecr."${awsRegion}".amazonaws.com/"${ecrRepository}" .

    export AWS_DEFAULT_REGION="${awsRegion}"

    echo "Pushing to ECR"
    aws ecr get-login-password --region "${awsRegion}" | docker login --username AWS --password-stdin "${awsAccountId}".dkr.ecr."${awsRegion}".amazonaws.com

    # create ECR repo if it does not exist
    aws ecr describe-repositories --region "${awsRegion}" --repository-names "${ecrRepository}" || aws ecr create-repository --region "${awsRegion}" --repository-name "${ecrRepository}"

    docker push "${awsAccountId}".dkr.ecr."${awsRegion}".amazonaws.com/"${ecrRepository}"
  else
    echo "No Dockerfile found!"
  fi

  echo
  echo "Completed."
}

## function that gets called, so executes all defined logic.
function main {

    options "$@"
    validate
    process

}

if [[ ${1:-} ]] && declare -F | cut -d' ' -f3 | fgrep -qx -- "${1:-}"
then "$@"
else main "$@"
fi
