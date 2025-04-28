#!/bin/bash

./create-external-dns-user.sh
./prepare-aws.sh
./install.sh


if [ "$CLEANUP" = true ]; then
    ./cleanup.sh
fi
