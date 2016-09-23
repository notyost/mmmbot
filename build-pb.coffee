# Description:
#   build an ansible playbook from github, put it on s3
#
# Configuration:
#   CREDSTASH_REF_GHTOKEN=mmmbot.github_token
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   hubot build-pb [example-tag] <https://github.com/mGageTechOps/example-playbook> <s3://example-path/ansible-playbook.tgz> - build an ansible playbook from github, put it on s3
#
shell = require('shelljs')

build_upload = (robot, tag, url, s3_path, res) ->
  res.reply "attempting to build playbook @ #{url}:#{tag}..."
  clone_url = url.replace('https://', "https://$(credstash -r #{process.env.CREDSTASH_REGION} get -n #{process.env.CREDSTASH_REF_GHTOKEN})@").replace(/\/$/, '')
  s3_path = s3_path.replace(/\.tgz$/, '') + '.tgz'
  dir_path = clone_url.substr(clone_url.lastIndexOf('/') + 1)
  script = [
    #clone the repo and switch to tag
    "git clone --branch #{tag} #{clone_url}"
    "cd #{dir_path}"
    "git checkout #{tag}"
    #install ansible role requirements if required
    "if [ -f requirements.yml ] ; then ansible-galaxy install -r requirements.yml -p ./roles ; fi"
    #create archive
    "tar -cvzf ../#{dir_path}.tgz . && cd .."
    #copy archive to s3
    "aws s3 cp #{dir_path}.tgz #{s3_path}"
    "rm #{dir_path}.tgz && rm -rf #{dir_path}"
  ]
  shell.exec script.join('&& '), {async:true}, (code, output) ->
    if code != 0
      res.reply "Something went wrong -- I handled this situation by not handling it...¯\\_(ツ)_/¯"
    else
      if robot.adapterName == "slack"
        res.send {
          as_user: true
          attachments: [
            color: "good"
            pretext: "playbook built:"
            thumb_url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Ansible_Logo.png/64px-Ansible_Logo.png'
            fields: [
              { title: "s3 path", value: "#{s3_path}", short: false}
              { title: "playbook", value: "#{url}", short: false }
              { title: "tag", value: "#{tag}", short: true }
            ]
          ]
        }
      else
        res.reply "Success, built #{url}:#{tag} and uploaded to #{s3_path}"

module.exports = (robot) ->
  robot.respond /build-pb( .*)? (.*) (.*)/i, (res) ->
    tag = res.match[1]
    unless tag?
      tag = 'master'
    if /https.*/.test(res.match[2].trim())
      url = res.match[2].trim()
    else if /s3.*/.test(res.match[2].trim())
      s3_path = res.match[2].trim()

    if /https.*/.test(res.match[3].trim())
      url = res.match[3].trim()
    else if /s3.*/.test(res.match[3].trim())
      s3_path = res.match[3].trim()

    build_upload(robot, tag, url, s3_path, res) if s3_path and url
