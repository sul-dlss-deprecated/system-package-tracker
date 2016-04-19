# Mailing for our various server and package and advisory reports, passing
# data through in a mail rather than to stdout.
class ReportMailer < ApplicationMailer
  default to: 'sul-sysadmin-rpts@lists.stanford.edu'

  def advisory_email(report)
    @report = report
    subject = 'Security Patch Status'
    mail(subject: subject)
  end
end
