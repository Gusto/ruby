FROM ubuntu:20.04

ENV RUBY_VERSION 2.7.4
ENV RUBY_VARIANT jemalloc

# RUN with pipe recommendation: https://github.com/hadolint/hadolint/wiki/DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN echo "gem: --no-document" | tee /etc/gemrc \
  && apt-get update -q \
  && apt-get dist-upgrade --yes \
  && apt-get install --yes -q --no-install-recommends \
    curl \
    gnupg \
    apt-transport-https \
    ca-certificates \
  && curl -sSLf https://raw.githubusercontent.com/fullstaq-labs/fullstaq-ruby-server-edition/main/fullstaq-ruby.asc | apt-key add - \
  && echo "deb https://apt.fullstaqruby.org ubuntu-20.04 main" | tee /etc/apt/sources.list.d/fullstaq-ruby.list \
  && apt-get update -q \
  && apt-get install --yes -q --no-install-recommends fullstaq-ruby-${RUBY_VERSION}-${RUBY_VARIANT} \
  && apt-get autoremove --yes \
  && rm -rf /var/lib/apt/lists \
  && rm -fr /var/cache/apt \
  && rm /etc/apt/sources.list.d/fullstaq-ruby.list

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME" \
    LANG=C.UTF-8 LC_ALL=C.UTF-8

# Path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
ENV PATH $GEM_HOME/bin:$BUNDLE_PATH/gems/bin:/usr/lib/fullstaq-ruby/versions/${RUBY_VERSION}-${RUBY_VARIANT}/bin:$PATH

# Adjust permissions of a few directories for running "gem install" as an
# arbitrary user.
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"

CMD [ "irb" ]
