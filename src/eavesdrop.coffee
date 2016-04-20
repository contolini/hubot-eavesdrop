# Description:
#   Have Hubot perform actions when it hears user-specified keywords.
#
# Dependencies:
#   quick-gist: 1.2.0
#
# Configuration:
#   None
#
# Commands:
#   hubot when you hear <pattern> do <something hubot does> - Setup a eavesdropping event
#   hubot stop listening - Stop all eavesdropping
#   hubot stop listening for <pattern> - Remove a particular eavesdropping event
#   hubot show listening - Show what hubot is eavesdropping on
#
# Author:
#   garylin
#   contolini
#   inhumantsar

gist = require 'quick-gist'
TextMessage = require('hubot').TextMessage

class EavesDropping
  constructor: (@robot) ->
    eavesdroppings = @robot.brain.get 'eavesdroppings'
    @eavesdroppings = eavesdroppings or []
    @robot.brain.set 'eavesdroppings', @eavesdroppings
  add: (pattern, action, order) ->
    task = {key: pattern, task: action, order: order}
    @eavesdroppings.push task
  all: -> @eavesdroppings
  deleteByPattern: (pattern) ->
    @eavesdroppings = @eavesdroppings.filter (n) -> n.key != pattern
  deleteAll: () ->
    @eavesdroppings = []

module.exports = (robot) ->
  eavesDropper = new EavesDropping robot

  robot.respond /when you hear (.+?) do (.+?)$/i, (msg) ->
    key = msg.match[1]
    for task_raw in msg.match[2].split ";"
      task_split = task_raw.split "|"
      # If it's a single task, don't add an "order" property
      if not task_split[1]
        eavesDropper.add(key, task_split[0])
      else
        eavesDropper.add(key, task_split[1], task_split[0])
    msg.send "I am now listening for #{key}."

  robot.respond /stop listening (for|on) (.+?)$/i, (msg) ->
    pattern = msg.match[2]
    eavesDropper.deleteByPattern(pattern)
    msg.send "Okay, I will ignore #{pattern}"

  robot.respond /show (listening|eavesdropping)s?/i, (msg) ->
    response = "\n"
    for task in eavesDropper.all()
      response += "#{task.key} -> #{task.task}\n"
    if response.length < 1000
      msg.send response
    else
      gist {content: response}, (err, resp, data) ->
        url = data.html_url
        msg.send "I'm listening for the following items: " + url

  robot.hear /(.+)/i, (msg) ->
    robotHeard = msg.match[1]

    tasks = eavesDropper.all()
    tasks.sort (a,b) ->
      return if a.order >= b.order then 1 else -1

    tasksToRun = []
    for task in tasks
      if new RegExp(task.key, "i").test(robotHeard)
        tasksToRun.push task

    tasksToRun.sort (a,b) ->
      return if a.order >= b.order then 1 else -1

    for task in tasksToRun
      if (robot.name != msg.message.user.name && !(new RegExp("^#{robot.name}", "i").test(robotHeard)))
        robot.receive new TextMessage(msg.message.user, "#{robot.name}: #{task.task}")