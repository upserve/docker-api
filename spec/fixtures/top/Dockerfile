FROM debian:stable
RUN apt-get update
RUN apt-get install -y procps
RUN printf '#! /bin/sh\nwhile true\ndo\ntrue\ndone\n' > /while && chmod +x /while
