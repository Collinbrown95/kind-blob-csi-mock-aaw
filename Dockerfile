# S3Proxy Dockerfile for debugging
FROM docker.io/andrewgaul/s3proxy:sha-71541ac
LABEL maintainer="Andrew Gaul <andrew@gaul.org>"

# need to give all users rwx permissions on /home/* so that when this container starts
# as non-root user, it has sufficient permission to perform all s3proxy operations
# against /home/jovyan/buckets
RUN chmod og=rwx /home && mkdir -p /home/jovyan/buckets

# Create non-root user and start container as non-root user
ARG USER=jovyan
ARG APP_HOME=/home/jovyan

RUN adduser --system --group $USER \
    && mkdir -p $APP_HOME \
    && chown -R $USER:$USER $APP_HOME

# Start container as non-root user
USER $USER

EXPOSE 80
ENTRYPOINT ["/opt/s3proxy/run-docker-container.sh"]