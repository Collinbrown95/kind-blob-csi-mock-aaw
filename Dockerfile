# S3Proxy Dockerfile for debugging
FROM docker.io/andrewgaul/s3proxy:sha-71541ac
LABEL maintainer="Andrew Gaul <andrew@gaul.org>"

# need to give all users rwx permissions on /home/* so that when this container starts
# as non-root user, it has sufficient permission to perform all s3proxy operations
# against /home/jovyan/buckets

# Create non-root user and start container as non-root user
ARG USER=jovyan
ARG APP_HOME=/home/jovyan/buckets

# Prepare relevant directories - need to create relevant directories first,
# create a new user called jovyan, change the permissions of the home directory
# of jovyan to read/write/execute, and change the owner of $APP_HOME to jovyan.
# this will let jovyan (non-root user) perform necessary s3proxy operations at the
# mount point /home/jovyan/buckets.
RUN mkdir -p $APP_HOME  && mkdir /home/jovyan/buckets/standard && mkdir /home/jovyan/buckets/premium

RUN adduser --system --group $USER \
    && mkdir -p $APP_HOME \
    && chmod -R 777 $APP_HOME \ 
    && chown -R $USER:$USER $APP_HOME

# Start container as non-root user
USER $USER

EXPOSE 80
ENTRYPOINT ["/opt/s3proxy/run-docker-container.sh"]