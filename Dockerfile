FROM node:8
MAINTAINER Thomas O'Brien <thomas.obrien@realtymogul.com>

# Cloning the repo and then running npm install within `my-awesome-hubot` works
# on a local environment
COPY . /hubot-bubbles
WORKDIR /hubot-bubbles/my-awesome-hubot

RUN npm install

# Not sure about this, do I need to expose a port and if so which port?
EXPOSE 80

CMD ["./bin/hubot", "--adapter", "slack"]
