#!/bin/bash
# Start Hugo dev server for use behind nginx reverse proxy
# Accessible at https://demiurge.suu.edu/blog/
# Requires nginx location block proxying /blog to port 8114

hugo server \
    --baseURL=https://demiurge.suu.edu/blog \
    --appendPort=false \
    --port=8114 \
    --bind=127.0.0.1
