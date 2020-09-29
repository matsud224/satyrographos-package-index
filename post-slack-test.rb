#!/usr/bin/env ruby

require 'json'
require 'slack/incoming/webhooks'


WEBHOOK_URL = ARGV[0]

oldinfo = oldjson['data']
newinfo = newjson['data']

def post_message_to_slack(text, attachments)
  slack = Slack::Incoming::Webhooks.new WEBHOOK_URL
  slack.post(text, attachments: [attachments])
end

post_message_to_slack(':exclamation: Test message from GitHub Actions', nil)
