Griddler.configure do |config|
  config.processor_class = EmailProcessor # CommentViaEmail
  config.email_class = Griddler::Email # MyEmail
  config.processor_method = :process
  config.reply_delimiter = '-- REPLY ABOVE THIS LINE --'
  config.email_service = :postmark
end