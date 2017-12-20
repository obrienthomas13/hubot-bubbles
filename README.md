# Bubbles

Hi! I'm Bubbles and I'm a [hubot] being built by Thomas O'Brien in Coffeescript.

[hubot]: https://hubot.github.com/

Facts about me:
* I'm being built to allow developers to deploy prequal/midas staging to production via Slack
* I love The Beatles
* I also specialize in printer issues

Technology I use:
* Hubot
* Jenkins
* Docker
* AWS ECS

Random notes:
* When **master** is pushed to, the build **Bubbles - Build and Deploy** will be triggered

Important packages:
* [Hubot-auth](https://github.com/hubot-scripts/hubot-auth)
* [Hubot-jenkins](https://github.com/github/hubot-scripts/blob/master/src/scripts/jenkins.coffee)(with some changes)
* [Hubot-slack](https://github.com/slackapi/hubot-slack)
* [Async](https://caolan.github.io/async/)


# Run Bubbles locally

1. Clone this repository
2. Run the following script commands within your copy of the repository
```
cd my-awesome-hubot
npm install
```
3. Make sure you have the follow environment variables set up
```
HUBOT_JENKINS_URL='https://leeroy.realtymogul.com/'
HUBOT_JENKINS_AUTH=(Ask Thomas or check the ECS task definition for this one)
HUBOT_AUTH_ADMIN="U1GD9FXNF,U2X564WCU,U0PNX1HHU,U5VTYABNF,U04AYJ17C,U3LT63NHZ"
HUBOT_SLACK_TOKEN=(Ask Thomas or check the ECS task definition for this one)
STAGING_STATE="false"
```
4. Run this final command in the current directory, (`/my-awesome-hubot/`) to boot up Bubbles
```
./bin/hubot --adapter slack
```
# Commands

In order to utilize my skills, type in this Slack channel...

Bubbles, what do you do?
* Return my README

Bubbles, initialize a deploy for prequal
* Provided all qualifications are met, Bubbles will initialize a deploy for prequal

Bubbles, initialize a deploy for midas
* Provided all qualifications are met, Bubbles will initialize a deploy for midas

Bubbles, run prequal front end tests
* Provided all qualifications are met, Bubbles will run front end selenium tests for prequal

Bubbles, run midas front end tests
* Provided all qualifications are met, Bubbles will run front end selenium tests for midas

Bubbles, reconnect to staging
* Provided all qualifications are met, Bubbles will reconnect to staging

Bubbles, sever staging
* Provided all qualifications are met, Bubbles will sever from staging

Bubbles, is staging severed?
* Bubbles checks to see if staging is severed

Bubbles, abort the job **<job-name>**?
* **IN PROGRESS**
* Abort job if it's currently building or in queue

Why can't I print
* On site maintenance to deal with a wide array of printing issues
