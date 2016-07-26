FROM alpine:3.4
RUN apk update &&\
    apk upgrade &&\
    apk add ansible docker git nodejs py-pip &&\
    npm install -g yo generator-hubot &&\
    adduser -h /mmmbot -D hubot hubot &&\
    pip install awscli boto boto3 credstash
USER hubot
WORKDIR /mmmbot
RUN yo hubot --owner="mmmbot <mmmbot42@gmail.com>" --name="mmmbot" --description="like but also unlike, the band" --adapter slack --defaults
RUN npm install --save https://github.com/mGageTechOps/hubot-s3-brain/tarball/master &&\
    npm install hubot-jenkins-enhanced --save &&\
    npm install shelljs --save 
ADD external-scripts.json .
ADD build-pb.coffee ./scripts/build-pb.coffee
ADD run-pb.coffee ./scripts/run-pb.coffee
ADD build-docker.coffee ./scripts/build-docker.coffee
CMD HUBOT_SLACK_TOKEN=$(credstash -r ${CREDSTASH_REGION} get -n ${CREDSTASH_REF_SLACKTOKEN}) bin/hubot --adapter slack
