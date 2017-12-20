async = require 'async'
fs = require 'fs'

# Global variables primarily being used as triggers/conditions
severStaging = (process.env.STAGING_STATE == 'true')
url = process.env.HUBOT_JENKINS_URL
timeoutStart = null
currentUserID = null
seleniumTestsResult = null
initializeDeployResult = null
waitingForJenkins = null

prequal = {
  initDeploy: false,
  seleniumTests: false,
  severStaging: null,
}

midas = {
  initDeploy: false,
  seleniumTests: false,
  severStaging: null,
}


# Various helper methods
# ====================================================================================================

# Testing purposes
staticResponseTest = (res, option) ->
  staticResponse = [
    "http://d817ypd61vbww.cloudfront.net/sites/default/files/styles/media_responsive_widest/public/tile/image/AbbeyRoad.jpg?itok=BgfH98zh",
    "Have you checked the reverse proxy?",
  ]
  res.send staticResponse[option]

# Specify the desired build and set pass/fail response
preJenkinsBuild = (res, pass, fail, jobName) ->
  job = {
    passBuild: pass,
    failBuild: fail,
  }
  res.match[1] = jobName
  return job

# Conditions needed to add/remove staging.lock
stagingLockChecks = (desiredStagingLock, robot, res, bubblesReply) ->
  result = true
  if !robot.auth.hasRole(res.envelope.user, 'admin')
    result = false
    res.reply "You do not have administrative access. ABORT"
  else if severStaging == desiredStagingLock
    result = false
    res.reply bubblesReply
  return result

# Helper for isJenkinsBuilding, checks the jenkins queue during the quiet period
quietPeriodChecks = (jenkinsQueue, next, jenkinsChecks) ->
  if !jenkinsQueue.hasOwnProperty('items')
    # console.log("items currently does not exist")
    next()
  if jenkinsQueue.items[0].why.substr(0,28) == "In the quiet period. Expires"
    # console.log("quietPeriod is still true")
    next()
  else if jenkinsQueue.items.length == 0
    # console.log("quietPeriod over, but never hit the why = ???")
    jenkinsChecks.quietPeriod = false
    next()
  else
    # console.log("quietPeriod is now false")
    jenkinsChecks.quietPeriod = false
    next()

# Helper for isJenkinsBuilding, checks state of the current jenkins build
currentBuildChecks = (jenkinsQueue, next, currBuild, lastBuild) ->
  if !jenkinsQueue.hasOwnProperty('items')
    # console.log("items currently does not exist")
    next()
  if currBuild.url == lastBuild.url
    next()
  else if jenkinsQueue.items.length == 0
    if currBuild.result == "SUCCESS"
      waitingForJenkins = true
      next 'Done! Build completed and passed'
    else if currBuild.result == "FAILURE"
      waitingForJenkins = false
      next 'Done! Build completed and failed'
  else if jenkinsQueue.items[0].why == "???"
    # console.log("the why check")
    next()
  else if jenkinsQueue.items[0].why == "Waiting for next available executor"
    # console.log("In queue")
    next()
  else
    # console.log("weird currBuild.result != null else condition")
    next 'Error! Check jenkins build'

# Overall check of the state of the current Jenkins build
isJenkinsBuilding = (robot, bubbles, req, jenkinsChecks, currBuild, lastBuild, next) ->
  if jenkinsChecks.building
    robot.jenkins.last(bubbles, (url) ->
      currBuild = url
      req.get() (err, res, body) ->
        content = JSON.parse(body)
        if jenkinsChecks.quietPeriod
          quietPeriodChecks(content, next, jenkinsChecks)
        else if currBuild.result != null
          currentBuildChecks(content, next, currBuild, lastBuild)
        else
          next()
    )
  else
    next()

# Waiting for a building jenkins job to complete
waitForBuildToComplete = (robot, bubbles, req, jenkinsChecks, currBuild, lastBuild) ->
  async.forever ((next) ->
    isJenkinsBuilding(robot, bubbles, req, jenkinsChecks, currBuild, lastBuild, next)
  ), (err) ->
    if err
      return

# Waiting for an item in the jenkins queue to be in the quiet period
waitForQuietPeriod = (req, jenkinsChecks) ->
  async.forever ((next) ->
    req.get() (err, res, body) ->
      content = JSON.parse(body)
      if !content.hasOwnProperty('items')
        next()
      if content.items.length > 0
        jenkinsChecks.building = true
        if isQuietPeriod(content.items)
          jenkinsChecks.quietPeriod = true
        next "Moving on"
      else
        next()
  ), (err) ->
    if err
      return

# Granting authentication to access leeroy
jenkinsAuth = (bubbles) ->
  req = bubbles.http("#{url}/queue/api/json")

  if process.env.HUBOT_JENKINS_AUTH
    auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
    req.headers Authorization: "Basic #{auth}"
  return req

# Checks to see if queue item is in the quiet period
isQuietPeriod = (content_items) ->
  return content_items[content_items.length - 1].why.substr(0,28) == "In the quiet period. Expires"

# Used to verify if the user is sure that they want Bubbles to intialize a deploy
# If there's no response within 8 seconds, the window to deploy ends
initializeDeployPreCheck = (robot, res, project) ->
  if robot.auth.hasRole(res.envelope.user, 'admin')
    res.reply "You sure? (Type *yes* or *no*)"
    project.initDeploy = true
    currentUserID = res.envelope.user.id
    timeoutStart = setTimeout (->
      if project.initDeploy
        project.initDeploy = false
    )
    , 8000
  else
    res.reply "You do not have administrative access. ABORT"

# Last round of checks for initializing a deploy
initializeDeployFinalCheck = (res) ->
  finalCheck = true
  if currentUserID != res.envelope.user.id
    finalCheck = false
    res.reply "You did not initialize the deploy."
  else if !severStaging
    finalCheck = false
    res.reply "Staging must be severed! (Type: *Bubbles, sever staging*)"
  else if !seleniumTestsResult
    finalCheck = false
    res.reply "Error! Please run front end tests first. (Type: *Bubbles, run midas/prequal front end tests*)"
  return finalCheck

# If conditions are met, initializes a deploy for prequal/midas
initializeDeploy = (res, robot) ->
  if initializeDeployFinalCheck(res)
    currentUserID = null
    waitingForJenkins = null
    job = ""
    # blocked, github repo isn't ready
    if prequal.initDeploy
      job = 'Prequal Frontend - Build and Test Production'
    else if midas.initDeploy
      job = 'Midas Web - Build and Test Production'
    if prequal.initDeploy || midas.initDeploy
      responseType = preJenkinsBuild(
        res,
        "Deployment successful!",
        "Deployment failed!",
        job
      )
      buildingJenkins(robot, res)
      buildResult(res, responseType, (result) ->)
    else
      res.reply "Check Bubbles, something went very wrong (refer to *yes* method)."

# Gives bubbles a response regarding whether a build passed,failed, or went very wrong
buildResultOptions = (responseOptions, next) ->
  if waitingForJenkins == null
    next()
  else if waitingForJenkins
    next responseOptions.passBuild
  else if !waitingForJenkins
    next responseOptions.failBuild
  else
    next "*ERROR!* Issue with job. Check jenkins build"

# Dynamically calls the result of a Jenkins build (works together with buildingJenkins)
buildResult = (res, responseOptions, callback) ->
  async.forever ((next) ->
    buildResultOptions(responseOptions, next)
  ), (err) ->
    if err
      res.reply err
      callback waitingForJenkins

# Dynamically builds a Jenkins job (works together with buildResult)
buildingJenkins = (robot, bubbles) ->
  lastBuild = {
    result: "",
    sure: "",
  }
  currBuild = {
    result: "",
    sure: "",
  }

  jenkinsChecks = {
    building: false,
    inQueue: false,
    quietPeriod: false,
  }
  robot.jenkins.last(bubbles, (buildObject) ->
    lastBuild = buildObject
  )
  robot.jenkins.build(bubbles, false, true)
  req = jenkinsAuth(bubbles)
  waitForQuietPeriod(req, jenkinsChecks)
  waitForBuildToComplete(robot, bubbles, req, jenkinsChecks, currBuild, lastBuild)
# ====================================================================================================

module.exports = (robot) ->

  # Bubbles's help response
  robot.respond /, what do you do\?*/i, (res) ->
    readMe = '../README.md'
    printBubblesReadMe = ->
      fs.readFileSync readMe, 'utf8'
    res.reply printBubblesReadMe()

  # Test for a static response
  robot.respond /, what is the best album by The Beatles\?*/i, (res) ->
    staticResponseTest(res, 0)

  # Safety net
  robot.hear /why can't I print|what is wrong with the printer|i hate printers|whyyyyy/i, (res) ->
    staticResponseTest(res, 1)

  # Provided all qualifications are met, Bubbles will initialize a deploy
  # for prequal for staging to production.
  robot.respond /, initialize a deploy for prequal/i, (res) ->
    initializeDeployPreCheck(robot, res, prequal)

  # Provided all qualifications are met, Bubbles will initialize a deploy
  # for midas for staging to production.
  robot.respond /, initialize a deploy for midas/i, (res) ->
    initializeDeployPreCheck(robot, res, midas)

  # Linked to initialize a deploy, whether prequal or midas
  robot.hear /yes/i, (res) ->
    initializeDeploy(res, robot)

  # Linked to initialize a deploy, whether prequal or midas
  robot.hear /no/i, (res) ->
    if prequal.initDeploy || midas.initDeploy
      if currentUserID is res.envelope.user.id
        currentUserID = null
        midas.initDeploy = false
        prequal.initDeploy = false
        res.reply "ABORT"
      else
        res.reply "You did not initialize the deploy."

  # If staging is severed, bubbles, will run front end selenium tests for prequal
  robot.hear /, run prequal front end tests/i, (res) ->
    if severStaging
      waitingForJenkins = null
      res.reply "Running prequal front end tests..."
      responseType = preJenkinsBuild(
        res,
        "Prequal selenium tests passed!",
        "Prequal selenium tests failed!",
        'Prequal Frontend - Selenium',
      )
      buildingJenkins(robot, res)
      buildResult(res, responseType, (result) ->
        seleniumTestsResult = result
        prequal.seleniumTests = result
      )
    else
      res.reply "Staging is not severed. ABORT"

  # If staging is severed, bubbles, will run front end selenium tests for midas
  robot.hear /, run midas front end tests/i, (res) ->
    if severStaging
      waitingForJenkins = null
      res.reply "Running midas front end tests..."
      responseType = preJenkinsBuild(
        res,
        "Midas selenium tests passed!",
        "Midas selenium tests failed!",
        'Midas Web - Selenium',
      )
      buildingJenkins(robot, res)
      buildResult(res, responseType, (result) ->
        seleniumTestsResult = result
        midas.seleniumTests = result
      )
    else
      res.reply "Staging is not severed. ABORT"

  # Provided all qualifications are met, Bubbles will reconnect to staging
  robot.respond /, reconnect to staging/i, (res) ->
    if stagingLockChecks(false, robot, res, "Already connected to staging. ABORT")
      waitingForJenkins = null
      res.reply "Reconnecting to staging..."
      severStaging = false
      responseType = preJenkinsBuild(
        res,
        "Staging has been reconnected.",
        "Build failed, but staging could already be connected (check Jenkins build).",
        'Prequal Frontend - Reconnect to Staging',
      )
      buildingJenkins(robot, res)
      buildResult(res, responseType, (result) ->)

  # Provided all qualifications are met, Bubbles will sever from staging
  robot.respond /, sever staging/i, (res) ->
    if stagingLockChecks(true, robot, res, "Already severed from staging. ABORT")
      waitingForJenkins = null
      res.reply "Severing staging..."
      severStaging = true
      responseType = preJenkinsBuild(
        res,
        "Staging has been severed",
        "Build failed, but staging could already be severed (check Jenkins build).",
        'Prequal Frontend - Sever Staging',
      )
      buildingJenkins(robot, res)
      buildResult(res, responseType, (result) ->)

  # Bubbles checks to see if staging is severed
  robot.respond /, is staging severed\?*/i, (res) ->
    waitingForJenkins = null
    responseType = preJenkinsBuild(
      res,
      "Staging is currently connected.",
      "Staging is currently severed.",
      'Prequal Frontend - Check for lock',
    )
    buildingJenkins(robot, res)
    buildResult(res, responseType, (result) ->
      severStaging = !result
    )

  # If the called job is building, abort the build
  robot.respond /, abort the job (.*)/i, (res) ->
    job = res.match[1]
    res.reply "Sure, aborting the job #{job}"
    res.reply "I'm really not. Just testing"
