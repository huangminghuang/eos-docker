#!/bin/bash

trap "trap - SIGTERM && kill -- 0; sleep 3" SIGTERM

## 'set -f' is used to disable filename expansion (globbing).
set -f
# the awk script captures the RED and BROWN lines from stdin and output them to stderr;
# otherwise, it ouputs to stdout
(nodeos $* |& mawk -Winteractive '/\033\[0;3(1|3)m/{print > "/dev/stderr"; next}{print}') & wait
