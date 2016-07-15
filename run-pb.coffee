# Description:
#   build an ansible playbook from github, put it on s3
#
# Configuration:
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   hubot run-pb [credstash-context] [credstash-key] <s3://example-path/ansible-playbook.tgz> <example-playbook> - run an ansible playbook from s3
#
shell  = require('shelljs')
run_playbook = (robot, credstash_context, credstash_key, s3_path, playbook_name, res) ->
  res.reply "downloading,extracting,running playbook..."
  s3_path = s3_path.replace(/\/$/, "")
  dir_path = s3_path.substr(s3_path.lastIndexOf('/') + 1)
  dir_path = dir_path.replace(".tgz", "")

  script = "mkdir #{dir_path} &&"
  script = "aws s3 cp #{s3_path} #{dir_path}/#{dir_path}.tgz &&"
  script += " cd #{dir_path} && tar -xvzf #{dir_path}.tgz &&"
  if credstash_key != ""
    script += " credstash -r #{process.env.CREDSTASH_REGION} get -n #{credstash_key} #{credstash_context} > #{credstash_key} &&"
    script += " chmod 600 #{credstash_key} &&"
    script += " ansible-playbook --key-file=#{credstash_key} -i inventory #{playbook_name}"
  else
    script += " ansible-playbook -i inventory #{playbook_name}"
  cleanup_script = "cd && rm -rf #{dir_path}"

  shell.exec script, {async:true}, (code, output, stderr) ->
    if (code != 0) or (stderr)
      res.reply "Something went wrong -- I handled this situation by not handling it...¯\\_(ツ)_/¯"
      if robot.adapterName != "slack"
        res.reply "stderr: #{stderr}"
        res.reply "stdout: #{output}"
      else
        robot.emit 'slack-attachment',
          channel: "#{res.message.user.room}"
          content:
            text: "#{stderr}"
            title: "run playbook error: stderr"
        robot.emit 'slack-attachment',
          channel: "#{res.message.user.room}"
          content:
            text: "#{output}"
            title: "run playbook error: stdout"
    else
      if robot.adapterName != "slack"
        res.reply "stdout: #{output}"
      else
        robot.emit 'slack-attachment',
          channel: "#{res.message.user.room}"
          content:
            text: "#{output}"
            title: ":rocket: run playbook output"
    shell.exec cleanup_script, {async:true}, (code, output) ->
      if code != 0
        res.reply "error cleaning up"

module.exports = (robot) ->
  robot.respond /run-pb( .* )?(.*)? (.*) (.*)/i, (res) ->
    credstash_context = res.match[1]
    unless credstash_context?
      credstash_context = ''
    credstash_key = res.match[2]
    unless credstash_key?
      credstash_key = ''
    s3_path = res.match[3].trim()
    playbook_name = res.match[4].trim()
    run_playbook(robot, credstash_context.trim(), credstash_key.trim(), s3_path, playbook_name, res)
