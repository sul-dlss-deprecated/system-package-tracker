class ReportMailer < ApplicationMailer
  default to: 'sul-sysadmin-rpts@lists.stanford.edu'

  def advisory_email(report)
    @report = report
    subject = 'Security Patch Status'
    mail(subject: subject)
  end
end
