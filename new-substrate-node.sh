#!/usr/bin/env bash

COLOR_WHITE=$(tput setaf 7);
COLOR_MAGENTA=$(tput setaf 5);
FONT_BOLD=$(tput bold);
FONT_NORMAL=$(tput sgr0);

echo
echo -e "$COLOR_WHITE $FONT_BOLD Substrate Template Setup $FONT_NORMAL";

while getopts v:c:b:n:a: option
do
  case "${option}"
    in
    v) version=${OPTARG};;
    c) commit=${OPTARG};;
    b) branch=${OPTARG};;
    n) name=${OPTARG};;
    a) author=${OPTARG};;
  esac
done

if [[ "$name" == "" || "$name" == "-"* ]]
then
  echo "  Usage: new-substrate-node.sh [ | -c commit | -b branch ] -v 1|2 -n chainname -a auth"
  echo "  If commit or branch not provided, this script will use the head commit"
  echo 
  exit 1
fi
if [[ "$author" == "" || "$author" == "-"* ]]
then
  echo "  Usage: new-substrate-node.sh [ | -c commit | -b branch ] -v 1|2 -n chainname -a auth"
  echo "  If commit or branch not provided, this script will use the head commit"
  echo
  exit 1
fi
if [[ "$version" == "" || "$version" == "-"* ]]
then
  echo "  Usage: new-substrate-node.sh [ | -c commit | -b branch ] -v 1|2 -n chainname -a auth"
  echo "  If commit or branch not provided, this script will use the head commit"
  echo
  exit 1
fi

lname="$(echo $name | tr '[:upper:]' '[:lower:]')"
dirname="${lname// /-}"

bold=$(tput bold)
normal=$(tput sgr0)

if [ -d "$dirname" ]; then
  echo "  Directory '$name' already exists!"
  echo
  exit 1
fi

# clone substrate if not exist
if [ ! -d "substrate" ]; then
  git clone https://github.com/paritytech/substrate.git
fi

# checkout to branch or commit
if [[ "$branch" == "" || "$branch" == "-"* ]]
then
  if [[ "$commit" == "" || "$commit" == "-"* ]]
  then
    # commit or branch not provided, use the head commit
    pushd ./substrate >/dev/null
    git checkout v1.0
    commit=$(git log -n1 --format='%H')
    popd >/dev/null
  fi

  pushd ./substrate >/dev/null
  git checkout $commit
  popd >/dev/null
else
  pushd ./substrate >/dev/null
  git checkout $branch
  popd >/dev/null
fi

cp -R ./substrate/node-template ./$dirname 

pushd $dirname >/dev/null

echo "${bold}Customizing project...${normal}"
function replace {
  find_this="$1"
  shift
  replace_with="$1"
  shift
  IFS=$'\n'
  TEMP=$(mktemp -d "${TMPDIR:-/tmp}/.XXXXXXXXXXXX")
  rmdir $TEMP
  for item in `find . -type f`
  do
    sed "s/$find_this/$replace_with/g" "$item" > $TEMP
    cat $TEMP > "$item"
  done
  rm -f $TEMP
}
replace "Substrate Node" "${name}"
replace node-template "${lname//[_ ]/-}"
replace node_template "${lname//[- ]/_}"
replace Anonymous "$author"


if [[ "$branch" == "" || "$branch" == "-"* ]]
then

  TEMP=$(mktemp -d "${TMPDIR:-/tmp}/.XXXXXXXXXXXX")
  rmdir $TEMP
  sed "s/path = \"\.\..*\"/git = 'https:\/\/github.com\/paritytech\/substrate.git', rev='$commit'/g" Cargo.toml > $TEMP
  cat $TEMP > Cargo.toml
  sed "s/path = \"\.\..*\"/git = 'https:\/\/github.com\/paritytech\/substrate.git', rev='$commit'/g" runtime/Cargo.toml > $TEMP
  cat $TEMP > runtime/Cargo.toml
  rm -f $TEMP

else

  TEMP=$(mktemp -d "${TMPDIR:-/tmp}/.XXXXXXXXXXXX")
  rmdir $TEMP
  sed "s/path = \"\.\..*\"/git = 'https:\/\/github.com\/paritytech\/substrate.git', branch='$branch'/g" Cargo.toml > $TEMP
  cat $TEMP > Cargo.toml
  sed "s/path = \"\.\..*\"/git = 'https:\/\/github.com\/paritytech\/substrate.git', branch='$branch'/g" runtime/Cargo.toml > $TEMP
  cat $TEMP > runtime/Cargo.toml
  rm -f $TEMP

fi


echo "${bold}Initializing repository...${normal}"
git init 2>/dev/null >/dev/null
cat >.gitignore <<EOL
# Generated by Cargo
# will have compiled files and executables
**/target/
# These are backup files generated by rustfmt
**/*.rs.bk
EOL
git add * .gitignore 2>/dev/null >/dev/null
git commit -a -m "Initial clone from template node" 2>/dev/null >/dev/null


echo "${bold}Initializing WebAssembly build environment...${normal}"
./scripts/init.sh 2>/dev/null >/dev/null

if [[ "$version" == "1" ]]
then
  echo "${bold}Build wasm ...${normal}"
  ./scripts/build.sh
fi

echo "${bold}Building node...${normal}"
cargo build # --release

echo
echo "${bold}Chain client created in ${dirname}${normal}."
echo "To start a dev chain, run:"
echo "$ $dirname/target/release/${lname//[_ ]/-} --dev"
echo "To create a basic Bonds UI for your chain, run:"
echo "$ substrate-ui-new $name"
echo "To push to a newly created GitHub repository, inside ${dirname}, run:"
echo "$ git remote add origin git@github.com:myusername/myprojectname && git push -u origin master"
echo

popd >/dev/null
