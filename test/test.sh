#!/bin/bash -e

############################################################
# Parse arguments
############################################################

# Default values
RUNNER=""
DISPATCHED=false
OVERRIDE=false   # default is true
IGNORE=false

# Single tests file
TESTS_FILE="./test/tests.txt"
DOWNLOADS_FILE="./test/data.txt"
LOGS_FOLDER="./test/logs"
JAWM_REPO=github.com/mpg-age-bioinformatics/jawm.git

# Arrays for versions
MODULE_VERSIONS=()
PYTHON_VERSIONS=()
JAWM_VERSIONS=()
SKIP_PYTHON_VERSIONS=()

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
    -y|--yaml)
      shift
      while [[ $# -gt 0 && $1 != -* ]]; do
        YAML_FILES+=("$1")
        shift
      done
      ;;
    -o|--override)
      OVERRIDE=true
      shift
      ;;
    --no-override)
      OVERRIDE=false
      shift
      ;;
    -i|--ignore)
      IGNORE=true
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
    --skip_python_versions)
      shift
      while [[ $# -gt 0 && $1 != -* ]]; do
        SKIP_PYTHON_VERSIONS+=("$1")
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
    --jawm_repo)
      JAWM_REPO="$2"
      shift 2
      ;;
    -t|--tests_file)
      TESTS_FILE="$2"
      shift 2
      ;;
    --downloads_file)
      DOWNLOADS_FILE="$(readlink -f $2)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 -r <local|github> [-d|--dispatch] [-y|--yaml] [-o|--override|--no-override] [-i|--ignore][-m module_versions] [-p python_versions] [--skip_python_versions] [-j jawm_versions] [--jawm_repo] [-t tests_file] [--downloads_file]"

      echo "./test.sh -d -r local --skip_python_versions 3.14.0"
      echo "./test.sh -r local -p 3.13.7"
      echo "./test.sh -r local -p system --jawm_repo ~/jawm"
      echo "./test.sh -r local -y ./yaml/build.yaml -p 3.13.7 --jawm_repo ~/jawm"

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

if [[ -d ${JAWM_REPO} ]] ; then 

    echo "WARNING: You have given a local path to jawm's source code." 
    echo "         Fixing -j|--jawm_versions to local"
    JAWM_VERSIONS=("local")

fi

# Example usage
echo "Runner: $RUNNER"
echo "Dispatched: $DISPATCHED"
echo "Extra yaml files: ${YAML_FILES[@]:-None}"
echo "Override existing hashes: $OVERRIDE"
echo "Ignore failed tests: $IGNORE"
echo "Test file:" ${TESTS_FILE:-None}
echo "Downloads file:" ${DOWNLOADS_FILE:-None}
echo "jawm repo/folder:" ${JAWM_REPO}

# Display versions if provided
echo "Specified module Versions: ${MODULE_VERSIONS[@]:-None}"
echo "Specified Python Versions: ${PYTHON_VERSIONS[@]:-None}"
echo "Skip Python Versions: ${SKIP_PYTHON_VERSIONS[@]:-None}"
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

if [ -f ${DOWNLOADS_FILE} ] ; then

  cd ${TESTPATH}
  mkdir -p test-input
  while read -r _ filename url _ ;
  do
      if [ ! -f "./test-input/${filename}" ]; then
        wget -O "./test-input/${filename}" "$url"
      fi
  done < ${DOWNLOADS_FILE}
  awk '{print $1, "./test-input/"$2}' data.txt | md5sum -c -

fi

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
echo "sourcing your ~/.bashrc"
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

for skip in ${SKIP_PYTHON_VERSIONS[@]} ; do

  PYTHON_VERSIONS=$(echo "$PYTHON_VERSIONS" | sed -E "s/\b$skip\b//g" | xargs)
  
done


for PYTHON_VERSION in ${PYTHON_VERSIONS} ; 
    do

        if [[ "${PYTHON_VERSION}" == "system" ]] ; then continue ; fi

        if pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
            echo "Python $PYTHON_VERSION is already installed"
        else
            echo "Python $PYTHON_VERSION not found, installing..."
            pyenv install "$PYTHON_VERSION" || { echo "Python $PYTHON_VERSION could not be installed, removing it from the list" ; PYTHON_VERSIONS=$(echo "$PYTHON_VERSIONS" | sed -E "s/\b$PYTHON_VERSION\b//g" | xargs); }
        fi
done

echo "Your python versions and environments can be found under: ~/.pyenv/versions/"

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
                ENV_NAME="py${PYTHON_VERSION}-jawm.${JAWM_VERSION}"

                if pyenv virtualenvs --bare | grep -qx "$ENV_NAME"; then
                    echo "Virtual environment '$ENV_NAME' already exists."
                else
                    echo "Creating virtual environment '$ENV_NAME'"
                    pyenv virtualenv "$PYTHON_VERSION" "$ENV_NAME"
                fi

                #pyenv prefix "$ENV_NAME"

                pyenv activate "$ENV_NAME"

                export PATH=~/.pyenv/versions/${ENV_NAME}/bin/:${PATH}

                if [[ "${JAWM_VERSION}" == "local" ]] ; then 

                    if [[ -d "${JAWM_REPO}" ]] ; then

                        echo "Installing jawm from ${JAWM_REPO} in $ENV_NAME."
                        pip install --force-reinstall ${JAWM_REPO}

                    fi

                else 

                    if pyenv shell "$ENV_NAME" >/dev/null 2>&1 && pyenv exec pip show jawm >/dev/null 2>&1; then
                        echo "'jawm@${JAWM_VERSION}' is already installed in $ENV_NAME."
                    else
                        echo "Installing 'jawm@${JAWM_VERSION}' in $ENV_NAME."
                        pip install git+ssh://git@${JAWM_REPO}@${JAWM_VERSION}
                    fi

                fi

                echo $(which jawm)

                pyenv deactivate

        done
done


############################################################
# set tag
############################################################

if [[ -z ${MODULE_VERSIONS} ]] ; then 

    if [[ "${RUNNER}" == "local" ]] ; 
        then

            # running locally and testing the current code state
            cd ${DIRPATH}
            CODE_TAG="current"

            if [[ "$DISPATCHED" == true ]]; then

                # if running locally and dispach is true than also test the lates released tag
                VERSION_TAG=$(git describe --tags --abbrev=0 || echo "")

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

        ENV_NAME="py${PYTHON_VERSION}-jawm.${JAWM_VERSION}"
        pyenv activate "$ENV_NAME"
        export PATH=~/.pyenv/versions/${ENV_NAME}/bin/:${PATH}

        for MODULE_VERSION in ${MODULE_VERSIONS} ; do
            # OUTPUT_PATH=${TESTPATH%/}/test-output/py${PYTHON_VERSION}_jawm${JAWM_VERSION}_mod${MODULE_VERSION}

            # if [[ "$OVERRIDE" == true ]] ; then
            #     if [[ -d "${OUTPUT_PATH}" ]] ; then rm -rf ${OUTPUT_PATH} ; fi                       
            # fi

            # if [[ ! -d "${OUTPUT_PATH}" ]] ; then mkdir -p ${OUTPUT_PATH} ; fi

            cd ${DIRPATH}

            if [ "${MODULE_VERSION}" != "current" ] ; then git checkout ${MODULE_VERSION} ; fi

            rm -rf .${TESTS_FILE}.tmp
            head -n 1 ${TESTS_FILE} > ${TESTS_FILE}.tmp

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
                echo "STORED HASH: ${STORED_HASH:-None}"
                echo "PYTHON VERSION: ${PYTHON_VERSION}"
                echo "JAWM VERSION: ${JAWM_VERSION}"
                echo "MODULE VERSION: ${MODULE_VERSION}"
                echo "JAWM COMMAND: jawm ${MOD} ${WORKFLOW} -l ${LOGS_FOLDER} -p $PARAM ${YAML_FILES[@]}"
                echo "------"

                FAILED=false

                if [[ ${IGNORE} == false ]] ; then
                    jawm ${MOD} ${WORKFLOW} -l ${LOGS_FOLDER} -p $PARAM "${YAML_FILES[@]}"|| { echo 'Error: jawm failed. Test failed.'; rm -rf ${TESTS_FILE}.tmp ; exit 1 ; }
                else
                    jawm ${MOD} ${WORKFLOW} -l ${LOGS_FOLDER} -p $PARAM "${YAML_FILES[@]}" || { echo 'Warning: jawm failed. Test failed.'; FAILED=true ; }
                fi


                if [[ ${FAILED} == false ]] ; then

                    NEW_HASH=$(cat ${LOGS_FOLDER}/jawm_hashes/$(basename ${MOD%.py}).hash )

                    echo "Stored HASH:    ${STORED_HASH}"
                    echo "Generated HASH: ${NEW_HASH}"
                    
                    if [[ "$STORED_HASH" == "" ]] ; then

                        ORIGINAL_LINE="$MOD;$WORKFLOW;$PARAM;\"$NAME\";${NEW_HASH}"

                        echo "$MOD;$WORKFLOW;$PARAM;\"$NAME\";${NEW_HASH}" >> ${TESTS_FILE}.tmp

                    else

                        if [[ "${NEW_HASH}" != "${STORED_HASH}" ]] ; then

                            ORIGINAL_LINE="$MOD;$WORKFLOW;$PARAM;\"$NAME\";$STORED_HASH"
                            
                            echo "Warning: Hashes do not match!"

                            if [[ ${OVERRIDE} == true ]] ; then

                                echo "Overwriting existing HASH."

                                echo "$MOD;$WORKFLOW;$PARAM;"$NAME";${NEW_HASH}" >> ${TESTS_FILE}.tmp

                            else

                                if [[ ${IGNORE} == false ]] ; then

                                  echo "Error: Hashes do not match! Test failed."
                                  rm -rf ${TESTS_FILE}.tmp
                                  exit 1

                                else 

                                  echo "Keeping stored HASH."
                                  echo "$MOD;$WORKFLOW;$PARAM;\"$NAME\";${STORED_HASH}" >> ${TESTS_FILE}.tmp

                                fi

                            fi

                        else 

                            echo "$MOD;$WORKFLOW;$PARAM;\"$NAME\";${STORED_HASH}" >> ${TESTS_FILE}.tmp

                        fi

                      fi

                fi

            done < ${TESTS_FILE}

            tail -n 1 ${TESTS_FILE} >> ${TESTS_FILE}.tmp
            mv ${TESTS_FILE}.tmp ${TESTS_FILE}
   
        done

        pyenv deactivate

    done
done
