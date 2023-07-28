FROM ruby:3.0.0

RUN apt-get -y update && apt-get -y dist-upgrade && apt-get -y update
RUN apt-get -y install git
RUN gem install bundler:2.3.12
# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN mkdir -p /app
COPY . /app
WORKDIR /app

RUN bundle install

RUN git clone https://github.com/ejp-rd-vp/CDE-semantic-model-implementations.git

ENTRYPOINT ["sh", "entrypoint-cdev2.sh"]
