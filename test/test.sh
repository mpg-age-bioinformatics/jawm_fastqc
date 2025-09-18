#!/bin/bash -e

############################################################
# Parse arguments
############################################################

# Default values
RUNNER=""
DISPATCHED=false
OVERRIDE=true   # default is true
# Single tests file
TESTS_FILE="./test/tests.txt"

# Arrays for versions
MODULE_VERSIONS=()
PYTHON_VERSIONS=()
JAWM_VERSIONS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--runner)
      RUNNER="$2"
      shift 2
      ;;
    -d|--dispatch)
      DISPATCHED=true
      shift
      ;;
    -o|--override)
      OVERRIDE=true
      shift
      ;;
    --no-override)
      OVERRIDE=false
      shift
      ;;
    -m|--module_versions)
      shift
      while [[ $# -gt 0 && $1 != -* ]]; do
        MODULE_VERSIONS+=("$1")
        shift
      done
      ;;
    -p|--python_versions)
      shift
      while [[ $# -gt 0 && $1 != -* ]]; do
        PYTHON_VERSIONS+=("$1")
        shift
      done
      ;;
    -j|--jawm_versions)
      shift
      while [[ $# -gt 0 && $1 != -* ]]; do
        JAWM_VERSIONS+=("$1")
        shift
      done
      ;;
    -t|--tests_file)
      TESTS_FILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 -r <local|github> [-d|--dispatch] [-o|--override|--no-override] [-m module_versions] [-p python_versions] [-j jawm_versions] [-t tests_file]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate runner argument
if [[ -z "$RUNNER" ]] ; then
  echo "Error: --runner is required (must be 'local' or 'github')."
  exit 1
fi

if [[ "$RUNNER" != "local" && "$RUNNER" != "github" ]] ; then
  echo "Error: Invalid runner '$RUNNER'. Must be 'local' or 'github'."
  exit 1
fi

# Example usage
echo "Runner: $RUNNER"
echo "Dispatched: $DISPATCHED"
echo "Override: $OVERRIDE"

# Display versions if provided
echo "Specified module Versions: ${MODULE_VERSIONS[@]:-None}"
echo "Specified Python Versions: ${PYTHON_VERSIONS[@]:-None}"
echo "Specified jawm Versions: ${JAWM_VERSIONS[@]:-None}"

############################################################
# set paths
############################################################
FULLPATH=$( readlink -f $0 )
TESTPATH=$( dirname ${FULLPATH} )
DIRPATH=$( dirname ${TESTPATH} )


############################################################
# download data
############################################################
cd ${TESTPATH}
mkdir -p test-input
while read -r _ filename url _ ;
do
    if [ ! -f "./test-input/${filename}" ]; then
    wget -O "./test-input/${filename}" "$url"
    fi
done < data.txt
awk '{print $1, "./test-input/"$2}' data.txt | md5sum -c -


############################################################
# preparing pyenv
############################################################
export PATH="$HOME/.pyenv/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
    echo "pyenv is already installed"
else
    echo "pyenv not found, installing..."
    # Install pyenv
    curl https://pyenv.run | bash
    echo "pyenv installed successfully."
fi

# Add pyenv to shell config (bash example)
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
source ~/.bashrc

############################################################
# installing different python versions
############################################################

if [[ -z ${PYTHON_VERSIONS} ]] ; then 

    PYTHON_VERSIONS=$(pyenv install --list \
      | grep -Eo '^[[:space:]]*3\.[0-9]+\.[0-9]+' \
      | sort -V \
      | awk -F. '$2 >= 10 {ver=$1"."$2; patch[ver]=$3} END {for (v in patch) print v"."patch[v]}' \
      | sort -V)

else 

  PYTHON_VERSIONS="${PYTHON_VERSIONS[@]}"
  
fi

for PYTHON_VERSION in ${PYTHON_VERSIONS} ; 
    do
        if pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
            echo "Python $PYTHON_VERSION is already installed"
        else
            echo "Python $PYTHON_VERSION not found, installing..."
            pyenv install "$PYTHON_VERSION" || { echo "Python $PYTHON_VERSION could not be installed, removing it from the list" ; PYTHON_VERSIONS=$(echo "$PYTHON_VERSIONS" | sed -E "s/\b$PYTHON_VERSION\b//g" | xargs); }
        fi
done

############################################################
# get latest jawm tag and latest commit
############################################################

if [[ -z ${JAWM_VERSIONS} ]] ; then 

  SHORT_JAWM_HASH=$(git ls-remote git@github.com:mpg-age-bioinformatics/jawm.git HEAD | awk '{print substr($1,1,7)}')

  LATEST_JAWM_TAG=$(git ls-remote --tags git@github.com:mpg-age-bioinformatics/jawm.git \
    | awk -F/ '{print $NF " " $1}' \
    | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+ ' \
    | sort -V \
    | tail -n 1)
  LATEST_JAWM_TAG=$(echo $LATEST_JAWM_TAG | awk '{print $1}')

  JAWM_VERSIONS="${SHORT_JAWM_HASH} ${LATEST_JAWM_TAG}" 

else 

  JAWM_VERSIONS="${JAWM_VERSIONS[@]}"

fi


############################################################
# install different jawm versions
############################################################
for PYTHON_VERSION in ${PYTHON_VERSIONS} ; 
    do
        for JAWM_VERSION in ${JAWM_VERSIONS} ;
            do
                ENV_NAME="py${PYTHON_VERSION}-jawm-${JAWM_VERSION}"
                # # Check if an environment with this name exists AND uses the specified Python version
                # EXISTS=$(pyenv virtualenvs --bare --skip-aliases | while read venv; do
                #     # Get the Python version used by this virtualenv
                #     VENV_PYTHON=$(pyenv prefix "$venv" 2>/dev/null)/bin/python
                #     if [ -f "$VENV_PYTHON" ]; then
                #         VENV_VERSION=$($VENV_PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')
                #         if [ "$venv" = "$ENV_NAME" ] && [ "$VENV_VERSION" = "$PYTHON_VERSION" ]; then
                #             echo "$venv"
                #         fi
                #     fi
                # done)

                if pyenv virtualenvs --bare | grep -qx "$ENV_NAME"; then
                    echo "Virtual environment '$ENV_NAME' already exists."
                else
                    echo "Creating virtual environment '$ENV_NAME'"
                    pyenv virtualenv "$PYTHON_VERSION" "$ENV_NAME"
                fi

                pyenv activate "$ENV_NAME"

                if pyenv shell "$ENV_NAME" >/dev/null 2>&1 && pyenv exec pip show jawm >/dev/null 2>&1; then
                    echo "Package 'jawm@${JAWM_VERSION}' is installed in $ENV_NAME."
                else
                    echo "Installing 'jawm@${JAWM_VERSION}' in $ENV_NAME."
                    pip install git+ssh://git@github.com/mpg-age-bioinformatics/jawm.git@${JAWM_VERSION}
                fi

                pyenv deactivate

        done
done


############################################################
# set tag
############################################################

echo "repo tag"

if [[ -z ${MODULE_VERSIONS} ]] ; then 

    if [[ "${RUNNER}" == "local" ]] ; 
        then

            # running locally and testing the current code state
            cd ${DIRPATH}
            CODE_TAG="current"

            if [[ "$DISPATCHED" == true ]]; then

                echo "1"
                # if running locally and dispach is true than also test the lates released tag
                VERSION_TAG=$(git describe --tags --abbrev=0 || echo "")
                echo "2: ${VERSION_TAG}"

            fi

            MODULE_VERSIONS="${CODE_TAG} ${VERSION_TAG}"


    elif [[ "${RUNNER}" == "github" ]] ; 
        then

            VERSION_TAG=${GITHUB_REF_NAME}
            echo "VERSION_TAG=${GITHUB_REF_NAME}" >> $GITHUB_ENV

            # if running on github but not driven by a new tag also test the latest commit
            CODE_TAG=$(git rev-parse --short HEAD)
            echo "CODE_TAG=${CODE_TAG}" >> $GITHUB_ENV

            if [[ "$DISPATCHED" == true ]]; then

                MODULE_VERSIONS="${CODE_TAG} ${VERSION_TAG}"

            elif [[ "${GITHUB_REF_TYPE}" == "tag" ]]; then

                # running on GitHub and tesing the latest tag
                VERSION_TAG=${GITHUB_REF_NAME}
                echo "VERSION_TAG=${GITHUB_REF_NAME}" >> $GITHUB_ENV

            else

                # if running on github but not driven by a new tag also test the latest commit
                CODE_TAG=$(git rev-parse --short HEAD)
                echo "CODE_TAG=${CODE_TAG}" >> $GITHUB_ENV

            fi


    fi

else 

    MODULE_VERSIONS="${MODULE_VERSIONS[@]}"

fi


for PYTHON_VERSION in ${PYTHON_VERSIONS} ; do
    for JAWM_VERSION in ${JAWM_VERSIONS} ; do

        ENV_NAME="py${PYTHON_VERSION}-jawm-${JAWM_VERSION}"
        pyenv activate "$ENV_NAME"

        for MODULE_VERSION in ${MODULE_VERSIONS} ; do
            OUTPUT_PATH=${TESTPATH%/}/test-output/py${PYTHON_VERSION}_jawm${JAWM_VERSION}_mod${MODULE_VERSION}

            if [[ "$OVERRIDE" == true ]] ; then
                if [[ -d "${OUTPUT_PATH}" ]] ; then rm -rf ${OUTPUT_PATH} ; fi                       
            fi

            if [[ ! -d "${OUTPUT_PATH}" ]] ; then mkdir -p ${OUTPUT_PATH} ; fi

            cd ${DIRPATH}

            if [ "${MODULE_VERSION}" != "current" ] ; then git checkout ${MODULE_VERSION} ; fi

            echo $(pwd)
            echo ${TESTS_FILE}

            while IFS=';' read -r MOD WORKFLOW PARAM NAME STORED_HASH; do
                # Skip empty lines or lines starting with #
                [[ -z "$MOD" || "$MOD" == \#* ]] && continue

                # Remove surrounding quotes from NAME
                NAME="${NAME%\"}"
                NAME="${NAME#\"}"

                echo "MODULE: $MOD"
                echo "WORKFLOW: $WORKFLOW"
                echo "PARAMETERS: $PARAM"
                echo "NAME: $NAME"
                echo "STORED HASH: $STORED_HASH"
                echo "------"

                #jawm ${MOD} ${WORKFLOW} -l ./test/logs -p $PARAM
                jawm ${MOD} -l ./test/logs -p $PARAM

                # need to implement when <HASH>
                # need to implement -o usage 

                # NEW_HASH=$(cat ./test/logs/jawm_hashes/$(basename ${MOD}_${WORKFLOW} ).hash )
                # ORIGINAL_LINE="$MOD;$WORKFLOW;$PARAM;$NAME;$STORED_HASH"
                # NEW_LINE="$MOD;$WORKFLOW;$PARAM;$NAME;$NEW_HASH"

                # sed -i "s|^${ORIGINAL_LINE}$|${NEW_LINE}|" ${TESTS_FILE}

            done < ${TESTS_FILE}

            # get the different tests to perform from tests.txt and run jawm 

        done

        pyenv deactivate
    done
done
