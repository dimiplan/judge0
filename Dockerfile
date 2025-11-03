FROM --platform=linux/amd64 ghcr.io/dimiplan/compilers:latest AS production

ENV JUDGE0_FORK_SOURCE_CODE="https://github.com/dimiplan/judge0"
LABEL source_code=$JUDGE0_FORK_SOURCE_CODE

ENV JUDGE0_FORK_MAINTAINER="dimiplan <admin@dimiplan.com>"
LABEL maintainer=$JUDGE0_FORK_MAINTAINER

ENV PATH="/usr/local/ruby-3.4.7/bin:/usr/local/bun-1.3.1/bin:/opt/.gem/bin:$PATH"
ENV GEM_HOME="/opt/.gem/"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      cron \
      libpq-dev \
      sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo "gem: --no-document" > /root/.gemrc && \
    gem install bundler && \
    bun install -g --unsafe-perm aglio@2.3.0

EXPOSE 2358

WORKDIR /api

COPY Gemfile* ./
RUN RAILS_ENV=production bundle

COPY cron /etc/cron.d
RUN cat /etc/cron.d/* | crontab -

COPY . .

ENTRYPOINT ["/api/docker-entrypoint.sh"]
CMD ["/api/scripts/server"]

RUN useradd -u 1000 -m -r judge0 && \
    echo "judge0 ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers && \
    chown judge0: /api/tmp/

USER judge0

ENV JUDGE0_VERSION="1.13.1"
LABEL version=$JUDGE0_VERSION
LABEL org.opencontainers.image.source="https://github.com/dimiplan/judge0"

FROM production AS development

CMD ["sleep", "infinity"]
