#!/bin/sh

set -euo pipefail

home_root="/opt/data"
task_root="/task/ctl"
ordinal_file="${task_root}/ordinal"

while [ ! -e "${ordinal_file}" ]
do
    echo "Waiting for orginal file ${ordinal_file}..."
    sleep 5
done

ordinal=$(cat ${ordinal_file})
data_path="${home_root}/${ordinal}"
exec thanos sidecar --tsdb.path ${data_path} \
                    --prometheus.url "http://localhost:9090"
