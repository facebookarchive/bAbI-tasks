#!/bin/env bash

# This script takes a training and test set of a task, and outputs statistics
# of the following form. Note that this script counts each *story* as an
# example, not each *question*.

# Task 4
# Overlap: 112 overlapping unique examples (12.0% of test set)
#
#            # Examples   # Unique examples
#   Train:   1000         934 (6.6% duplicates)
#    Test:   1000         933 (6.7% duplicates)


# Check that the user passed 2 files
if [ $# -ne 2 ]
then
  echo "Usage: $0 train test"
  exit 1
fi
args=("$@")

# Outputs a single example per line
format-examples() {
  { cut -f 1,2 |
    sed 's/^1 /\\1 /g' | tr -d '\n' | sed 's/\\/\n/g' | sed '/^$/d'; } < "$1"
}

# Collect file statistics
for i in $(seq 0 1)
do
  formatted[$i]=$(format-examples "${args[$i]}")
  unique[$i]=$({ sort | uniq ; } <<< "${formatted[$i]}")
  num_examples[$i]=$(wc -l <<< "${formatted[$i]}")
  num_unique_examples[$i]=$(wc -l <<< "${unique[$i]}")
done

# Find overlap
num_overlap=$(comm -12 <(echo "${unique[0]}") <(echo "${unique[1]}") | wc -l)

# Print statistics
template="Overlap: %u overlapping unique examples (%.1f%% of test set)

           # Examples   # Unique examples"

overlap_pct=$(bc -l <<< "$num_overlap/${num_unique_examples[1]}*100")
arguments="$num_overlap $overlap_pct"

names=(Train Test)
for i in $(seq 0 1)
do
  template="$template
  $(printf "%5s" "${names[$i]}"):   %-12u %u (%.1f%% duplicates)"
  non_unique=$((${num_examples[$i]}-${num_unique_examples[$i]}))
  pct=$(bc -l <<< "$non_unique/${num_examples[$i]}*100")
  arguments="$arguments ${num_examples[$i]} ${num_unique_examples[$i]} $pct"
done


printf "$template\n" $arguments
