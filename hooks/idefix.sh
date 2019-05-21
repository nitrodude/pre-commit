#!/bin/bash

set -e

# Setting up some colours for a sexy output
red=$'\e[0;31m'
green=$'\e[0;32m'
light_cyan=$'\e[1;36m'
yellow=$'\e[0;33m'
nocolor=$'\e[0m'

# Run helm lint on the chart path.
# A typical helm chart directory structure looks as follows:
#
# └── root
#     ├── README.md
#     ├── Chart.yaml
#     ├── charts
#     │   └── postgres-9.5.6.tar.gz
#     └── templates
#         ├── deployment.yaml
#         ├── service.yaml
#         └── _helpers.tpl
#
# The `Chart.yaml` file is metadata that helm uses to index the chart, and is added to the release info. It includes things
# like `name`, `version`, and `maintainers`.
# The `charts` directory are subcharts / dependencies that are deployed with the chart.
# The `templates` directory is what contains the go templates to render the Kubernetes resource yaml. Also includes
# helper template definitions (suffix `.tpl`).
#
# Any time files in `templates` or `charts` changes, we should run `helm lint`. `helm lint` can only be run on the root
# path of a chart, so this pre-commit hook will take the changed files and resolve it to the helm chart path. The helm
# chart path is determined by a heuristic: it is the directory containing the `Chart.yaml` file.
#
# Note that pre-commit will only feed this the files that changed in the commit, so we can't do the filtering at the
# hook setting level (e.g `files: Chart.yaml` will not work if no changes are made in the Chart.yaml file).

# OSX GUI apps do not pick up environment variables the same way as Terminal apps and there are no easy solutions,
# especially as Apple changes the GUI app behavior every release (see https://stackoverflow.com/q/135688/483528). As a
# workaround to allow GitHub Desktop to work, add this (hopefully harmless) setting here.


for file in "$@"; do
  echo $"basename $file"
  if [[ $"basename $file" == "values.yaml" ]]; then
    # Unset previously parsed variables from the values file of the lms-master-chart
    for image in $(grep -E "repository:" "${file}" | awk '{print $2}'); do
      echo "${light_cyan}Image: ${image}${nocolor}"

      latest_tag=$(gcloud container images list-tags "${image}" | grep -v "TAGS" | awk '{ print $2}' | sort -rV | head -n 1)
      echo "${light_cyan}Latest tag: ${green}${latest_tag}${nocolor}"
      current_tag=$(grep -E "(^|\s)${image}($|\s)" -A 2 "${file}" | grep -v "#" | grep -v "${image}" | awk '{print $2}')
      echo "${light_cyan}Current tag: ${yellow}${current_tag}${nocolor}"

      if [[ "${latest_tag}" != "${current_tag}" ]]; then
        echo "${red}Current tag is not up to date${nocolor}"
        exit 1
      else
        echo "${green}Current tag is up to date${nocolor}"
      fi
      echo "========================="
    done
  fi
done