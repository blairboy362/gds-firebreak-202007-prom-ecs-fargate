#!/bin/sh

set -euo pipefail

home_root="/opt/data"
control_root="${home_root}/promctl"
control_lockfile="${control_root}/lock"
task_root="/task/ctl"

mkdir -p "${control_root}"
mkdir -p "${task_root}"

# Prometheus locks its data directory.
# As we have multiple instances sharing an ECS volume
# (no alternative with EFS makes sense)
# we need to allocate a directory to each instance
# that will be restored when future tasks are launched
# (so using things like the task ID are not suitable).
# Here we use a distributed flock (the EFS driver takes care
# of the distributed lock) to allocate an "ordinal" to each
# instance. When tasks roll, as long as they roll one at a
# time, most of them should re-grab old ordinals, restoring the
# history.
find_ordinal()
{
    (
        flock 200
        ordinal=0
        for i in $(seq 1 10)
        do
            lockfile="${control_root}/${i}.lock"
            if [ ! -e "${lockfile}" ]
            then
                ordinal="${i}"
                echo "${ordinal}" > "${task_root}/ordinal"
                touch "${lockfile}"
                break
            fi
        done

        if [ "${ordinal}" == "0" ]
        then
            echo "Failed to find an available ordinal."
            ls -lah ${control_root}
            exit 1
        fi
    ) 200>"${control_lockfile}"

    ordinal=$(cat ${task_root}/ordinal)
}

clean_locks()
{
    echo "cleaning lockfile..."
    (
        flock 200
        lockfile="${control_root}/${ordinal}.lock"
        rm -f "${lockfile}"
    ) 200>"${control_lockfile}"
    echo "end of cleaning lockfile"
}

handle_term()
{
    echo "caught TERM signal; handling..."
    kill -TERM "${pid}"
    echo "end of TERM signal handling"
}

prep_prometheus()
{
    echo ${CONFIG_BASE64} | base64 -d  > /etc/prometheus/prometheus.yml
    sed -i "s/ORDINAL/${ordinal}/g" /etc/prometheus/prometheus.yml
    mkdir -p "${data_path}"
}

find_ordinal
trap 'clean_locks' EXIT
trap 'handle_term' TERM INT
data_path="${home_root}/${ordinal}"
echo "Using data path: ${data_path}"
prep_prometheus
prometheus --config.file=/etc/prometheus/prometheus.yml \
           --storage.tsdb.path=${data_path} \
           --web.console.libraries=/usr/share/prometheus/console_libraries \
           --web.console.templates=/usr/share/prometheus/consoles \
           --web.enable-lifecycle \
           &
pid=$!
wait ${pid}
echo "end of entrypoint.sh"
