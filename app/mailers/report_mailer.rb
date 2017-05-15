# Mailing for our various server and package and advisory reports, passing
# data through in a mail rather than to stdout.
class ReportMailer < ApplicationMailer
  require 'yaml'

  default to: 'sul-sysadmin-rpts@lists.stanford.edu'

  def advisory_email(report)
    @report = report
    subject = 'Security Patch Status'
    mail(subject: subject)
  end

  def stacks_email(stack, report)
    addresses = YAML.load_file('config/stacks.yml')
    shortstack = stack.sub(/-(dev|prod|stage)$/, '')
    email_to = ''
    if addresses.key?(stack)
      email_to = addresses[stack]
    elsif addresses.key?(shortstack)
      email_to = addresses[shortstack]
    end
    abort "no email set for stack #{stack}" if email_to == ''

    subject = "Security Patch Status for #{stack} stack"
    mail(to: email_to, subject: subject, body: report)
  end
end
