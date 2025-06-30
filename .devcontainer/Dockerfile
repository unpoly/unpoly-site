# [Choice] Ruby version: 2, 2.7, 2.6, 2.5
ARG VARIANT=2
FROM ruby:${VARIANT}


RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends sudo nodejs

RUN echo 'vscode ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/vscode && \
  chmod 440 /etc/sudoers.d/vscode

RUN useradd -ms /bin/bash vscode

USER vscode

RUN gem install bundler -v "2.6.9"
