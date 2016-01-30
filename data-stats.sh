#!/usr/bin/env bash

# This script takes a training and test set of a task, and outputs statistics
# of the following form. Note that this script counts each *story* as an
# example, not each *question*.

# Task 4
# Overlap: 112 overlapping unique stories (12.0% of test set)
#
#            # Stories   # Unique stories
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
    sed 's/^1 /\\1 /g' | tr '\n' ' ' | sed 's/\\/\n/g' | sed '/^$/d'; } < "$1"
}

# Collect file statistics
for i in $(seq 0 1)
do
  formatted[$i]=$(format-examples "${args[$i]}")
  questions[$i]=$(mktemp)
  j=1
  while :
  do
    grep -Po "^1 (.*?\t\S*){$j}" >> $questions[$i] <<< "${formatted[$i]}" || break
    ((j++))
  done
  unique_questions[$i]=$(sort $questions[$i] | uniq)
  num_stories[$i]=$(wc -l <<< "${formatted[$i]}")
  num_questions[$i]=$(wc -l < $questions[$i])
  num_unique_questions[$i]=$(wc -l <<< "${unique_questions[$i]}")
done

# Find overlap
num_overlap=$(comm -12 <(echo "${unique_questions[0]}") <(echo "${unique_questions[1]}") | wc -l)

# Print statistics
template="Overlap: %u unique questions from the training set are in the test set (%.1f%% of test set)

           # Stories    # Questions  # Unique questions"

overlap_pct=$(bc -l <<< "$num_overlap/${num_unique_questions[1]}*100")
arguments="$num_overlap $overlap_pct"

names=(Train Test)
for i in $(seq 0 1)
do
  template="$template
  $(printf "%5s" "${names[$i]}"):   %-12u %-12u %u (%.1f%% duplicates)"
  non_unique=$((${num_questions[$i]}-${num_unique_questions[$i]}))
  pct=$(bc -l <<< "$non_unique/${num_questions[$i]}*100")
  arguments="$arguments ${num_stories[$i]} ${num_questions[$i]} ${num_unique_questions[$i]} $pct"
done


printf "$template\n" $arguments
